//! Snapshot and journal: atomic writes, replay equals live state, damaged files.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::fs::{self, OpenOptions};
use std::io::Write as _;

use poker_server_core::config::Timings;
use poker_server_core::protocol::{CardMode, RoomConfig};
use poker_server_core::room::state::{HostCommand, Op, RoomState};
use poker_server_core::store::journal::Journal;
use poker_server_core::store::{self, StoreError, snapshot};

fn room() -> RoomState {
    let config = RoomConfig {
        card_mode: CardMode::Physical,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
        solo: None,
    };
    RoomState::new("ABCD".into(), config, "Host", "h".into(), "hs".into(), 0).unwrap()
}

fn join(id: &str, name: &str) -> Op {
    Op::Join {
        player_id: id.into(),
        name: name.into(),
        spectator: false,
        seat: None,
        token_hash: format!("hash-{id}"),
        at_ms: 1,
    }
}

fn start() -> Op {
    Op::Host {
        by: "p_1".into(),
        command: HostCommand::StartHand { deck: None },
        at_ms: 1000,
    }
}

/// Applies and journals like the room actor will: journal first, then swap the state in.
fn run(state: &mut RoomState, journal: &mut Journal, op: Op) -> u64 {
    let mut next = state.clone();
    let seq = journal.append(&op).unwrap();
    next.apply(op, &Timings::default()).unwrap();
    *state = next;
    seq
}

#[test]
fn snapshot_round_trips() {
    let dir = tempfile::tempdir().unwrap();
    let state = room();
    snapshot::write(dir.path(), &state, 7).unwrap();
    let back = snapshot::read(dir.path()).unwrap();
    assert_eq!(back.journal_seq, 7);
    assert_eq!(back.state, state);
    assert!(!dir.path().join("snapshot.json.tmp").exists());
}

#[test]
fn restore_replays_the_journal_onto_the_snapshot() {
    let dir = tempfile::tempdir().unwrap();
    let mut live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(&mut live, &mut journal, join("p_2", "Bob"));
    run(&mut live, &mut journal, join("p_3", "Cy"));
    let last = run(&mut live, &mut journal, start());

    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.state, live);
    assert_eq!(restored.last_seq, last);
    assert_eq!(restored.failed_replays, 0);
}

#[test]
fn a_new_snapshot_makes_older_entries_redundant() {
    let dir = tempfile::tempdir().unwrap();
    let mut live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(&mut live, &mut journal, join("p_2", "Bob"));
    let seq = run(&mut live, &mut journal, join("p_3", "Cy"));
    // Crash between writing the snapshot and truncating: old entries are still in the file.
    snapshot::write(dir.path(), &live, seq).unwrap();
    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(
        restored.state, live,
        "entries covered by the snapshot are not applied twice"
    );
    // Normal path: truncate, keep numbering, keep working.
    journal.truncate().unwrap();
    run(&mut live, &mut journal, start());
    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.state, live);
    assert_eq!(restored.last_seq, seq + 1);
}

#[test]
fn a_cut_off_last_line_is_ignored() {
    let dir = tempfile::tempdir().unwrap();
    let mut live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(&mut live, &mut journal, join("p_2", "Bob"));
    let mut file = OpenOptions::new()
        .append(true)
        .open(dir.path().join("journal.jsonl"))
        .unwrap();
    file.write_all(br#"{"entry":"OP","seq":2,"op":{"kind":"JOIN","playerId":"p_3","na"#)
        .unwrap();
    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.state, live);
    assert_eq!(restored.last_seq, 1);
}

#[test]
fn a_bad_line_in_the_middle_is_corruption() {
    let dir = tempfile::tempdir().unwrap();
    let live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    journal.append(&join("p_2", "Bob")).unwrap();
    let path = dir.path().join("journal.jsonl");
    let good = fs::read_to_string(&path).unwrap();
    fs::write(&path, format!("not json\n{good}")).unwrap();
    let error = store::restore(dir.path(), &Timings::default()).unwrap_err();
    assert!(matches!(error, StoreError::Corrupt { .. }), "{error}");
}

#[test]
fn poisoned_entries_are_skipped() {
    let dir = tempfile::tempdir().unwrap();
    let mut live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(&mut live, &mut journal, join("p_2", "Bob"));
    let bad = journal.append(&join("p_3", "Cy")).unwrap();
    journal.mark_poisoned(bad).unwrap();
    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.state, live, "the poisoned join never happened");
    assert_eq!(restored.skipped_poisoned, 1);
}

#[test]
fn missing_snapshot_is_an_error() {
    let dir = tempfile::tempdir().unwrap();
    assert!(matches!(
        store::restore(dir.path(), &Timings::default()),
        Err(StoreError::Io(_))
    ));
}

#[test]
fn a_poisoned_sequence_number_is_never_handed_out_again() {
    let dir = tempfile::tempdir().unwrap();
    let mut live = room();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(&mut live, &mut journal, join("p_2", "Bob"));
    // The last entry is the poisoned one: this used to lose its number.
    let bad = journal.append(&join("p_3", "Cy")).unwrap();
    journal.mark_poisoned(bad).unwrap();
    drop(journal);

    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.last_seq, bad, "the poisoned number counts as used");
    let mut journal = Journal::open(dir.path(), restored.last_seq).unwrap();
    let mut state = restored.state;
    let fresh = run(&mut state, &mut journal, join("p_3", "Dee"));
    assert!(fresh > bad);

    let again = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(again.state, state, "the new op survives the next replay");
    assert!(again.state.players.contains_key("p_3"));
    assert_eq!(again.state.players["p_3"].name, "Dee");
}
