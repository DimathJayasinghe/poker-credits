//! What a virtual room keeps secret: nothing about the deck in `Debug` output, owner-only files,
//! and rooms written before the feature existed still loading.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::fs;
use std::path::Path;

use poker_engine::PlayerAction;
use poker_engine::deck::Deck;
use poker_server_core::cards::{FixedEntropy, shuffled_deck};
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{CardMode, ClientMessage, RoomConfig, ServerMessage, WirePhase};
use poker_server_core::room::actor::{self, Clock, Deps, NewRoom};
use poker_server_core::room::state::{HostCommand, Op, RoomState};
use poker_server_core::store::journal::Journal;
use poker_server_core::store::{self, snapshot};
use poker_server_core::util::token;
use tokio::sync::mpsc;

fn config(mode: CardMode) -> RoomConfig {
    RoomConfig {
        card_mode: mode,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
    }
}

/// The first card-looking token (`As`, `Td`, ...) in `text`, if any. A token counts when it is
/// a rank letter or digit plus a suit letter with nothing alphanumeric on either side.
fn card_token(text: &str) -> Option<String> {
    let chars: Vec<char> = text.chars().collect();
    chars.windows(2).enumerate().find_map(|(at, pair)| {
        let rank = "23456789TJQKA".contains(pair[0]);
        let suit = "cdhs".contains(pair[1]);
        let before = at.checked_sub(1).and_then(|i| chars.get(i));
        let after = chars.get(at + 2);
        let clear = !before.is_some_and(|c| c.is_alphanumeric())
            && !after.is_some_and(|c| c.is_alphanumeric());
        (rank && suit && clear).then(|| pair.iter().collect())
    })
}

fn virtual_state_mid_hand() -> (RoomState, Op) {
    let timings = Timings::default();
    let mut state = RoomState::new(
        "ABCD".into(),
        config(CardMode::Virtual),
        "Host",
        token::hash("h"),
        token::hash("hs"),
        0,
    )
    .unwrap();
    state
        .apply(
            Op::Join {
                player_id: "p_2".into(),
                name: "Bob".into(),
                spectator: false,
                seat: None,
                token_hash: token::hash("b"),
                at_ms: 1,
            },
            &timings,
        )
        .unwrap();
    let deck = shuffled_deck(&mut FixedEntropy::new(vec![3, 1, 4, 1, 5, 9, 2, 6])).unwrap();
    let start = Op::Host {
        by: "p_1".into(),
        command: HostCommand::StartHand { deck: Some(deck) },
        at_ms: 2,
    };
    state.apply(start.clone(), &timings).unwrap();
    (state, start)
}

#[test]
fn card_token_finder_finds_cards_and_ignores_words() {
    assert_eq!(card_token("x As y").as_deref(), Some("As"));
    assert_eq!(card_token("[Td, 3c]").as_deref(), Some("Td"));
    assert_eq!(card_token("Host Bob PreFlop ABCD p_1 chips"), None);
    assert_eq!(card_token("Ass"), None);
}

#[test]
fn debug_of_room_state_and_ops_contains_no_card() {
    let (state, start) = virtual_state_mid_hand();
    assert!(state.game.table.deal.is_some(), "the hand is dealt");
    let deck = Deck::standard();
    for (what, text) in [
        ("room state", format!("{state:?}")),
        ("pretty room state", format!("{state:#?}")),
        ("start op", format!("{start:?}")),
        ("game", format!("{:?}", state.game)),
        ("table", format!("{:?}", state.game.table)),
        ("deal", format!("{:?}", state.game.table.deal)),
        ("deck", format!("{deck:?}")),
    ] {
        assert_eq!(card_token(&text), None, "{what} leaks a card: {text}");
    }
}

#[cfg(unix)]
#[test]
fn snapshot_and_journal_files_are_0600_and_folder_0700() {
    use std::os::unix::fs::PermissionsExt as _;
    let mode = |path: &Path| fs::metadata(path).unwrap().permissions().mode() & 0o777;
    let root = tempfile::tempdir().unwrap();
    let dir = root.path().join("ROOM");
    let (state, start) = virtual_state_mid_hand();
    snapshot::write(&dir, &state, 0).unwrap();
    let mut journal = Journal::open(&dir, 0).unwrap();
    journal.append(&start).unwrap();
    assert_eq!(mode(&dir), 0o700);
    assert_eq!(mode(&dir.join("snapshot.json")), 0o600);
    assert_eq!(mode(&dir.join("journal.jsonl")), 0o600);

    // A second write replaces the snapshot without loosening it, and a file left by an older
    // version with wider permissions is tightened when the journal is opened again.
    snapshot::write(&dir, &state, 1).unwrap();
    assert_eq!(mode(&dir.join("snapshot.json")), 0o600);
    fs::set_permissions(dir.join("journal.jsonl"), fs::Permissions::from_mode(0o644)).unwrap();
    fs::set_permissions(&dir, fs::Permissions::from_mode(0o755)).unwrap();
    let _again = Journal::open(&dir, 1).unwrap();
    assert_eq!(mode(&dir.join("journal.jsonl")), 0o600);
    assert_eq!(mode(&dir), 0o700);
}

// -------------------------------------------------------------------------------------------
// Rooms written before virtual cards existed
// -------------------------------------------------------------------------------------------

const FIXTURE: &str = "tests/fixtures/pre_cards_room";

fn copy_fixture(into: &Path) {
    fs::create_dir_all(into).unwrap();
    for name in ["snapshot.json", "journal.jsonl"] {
        fs::copy(Path::new(FIXTURE).join(name), into.join(name)).unwrap();
    }
}

#[test]
fn the_fixture_really_predates_the_feature() {
    for name in ["snapshot.json", "journal.jsonl"] {
        let text = fs::read_to_string(Path::new(FIXTURE).join(name)).unwrap();
        for new_key in ["cardMode", "\"deal\"", "handNames", "\"deck\"", "hasCards"] {
            assert!(!text.contains(new_key), "{name} already has {new_key}");
        }
    }
}

#[test]
fn old_snapshot_and_journal_from_before_cards_restore_as_physical() {
    let dir = tempfile::tempdir().unwrap();
    copy_fixture(dir.path());
    let restored = store::restore(dir.path(), &Timings::default()).unwrap();
    assert_eq!(restored.failed_replays, 0);
    let state = restored.state;
    assert_eq!(state.config.card_mode, CardMode::Physical);
    assert!(state.game.table.deal.is_none());
    assert!(state.hand_names.is_empty());
    assert!(!state.needs_auto_showdown());
    assert_eq!(state.players.len(), 2);
    assert_eq!(
        format!("{:?}", state.game.table.phase),
        "PreFlop",
        "the hand in the journal was replayed"
    );
}

#[tokio::test(start_paused = true)]
async fn an_old_room_plays_on_after_the_upgrade() {
    let dir = tempfile::tempdir().unwrap();
    copy_fixture(dir.path());
    let deps = Deps {
        clock: Clock::new(),
        entropy: Box::new(FixedEntropy::new(vec![1, 2, 3])),
    };
    let (handle, _task) = actor::restore_with(
        dir.path().to_path_buf(),
        &Limits::default(),
        &Timings::default(),
        deps,
    )
    .unwrap();
    let (tx, mut rx) = mpsc::channel(64);
    handle
        .resume(
            1,
            tx,
            None,
            "fixture-host-session".into(),
            Some("fixture-host-token".into()),
        )
        .await
        .unwrap();
    tokio::time::sleep(std::time::Duration::from_millis(1)).await;
    let mut got = Vec::new();
    while let Ok(item) = rx.try_recv() {
        got.push(item.message);
    }
    let view = got
        .iter()
        .find_map(|m| match m {
            ServerMessage::Snapshot { view, .. } => Some(view),
            _ => None,
        })
        .expect("a snapshot");
    assert_eq!(view.phase, WirePhase::PreFlop);
    assert!(view.board.is_empty() && view.reveals.is_empty() && view.result.is_none());
    assert!(
        !got.iter()
            .any(|m| matches!(m, ServerMessage::HoleCards { .. }))
    );
    // And a physical hand still ends the old way.
    handle
        .send(
            1,
            None,
            ClientMessage::GameAction {
                action_seq: 0,
                action: PlayerAction::Fold,
            },
        )
        .await
        .unwrap();
}

#[tokio::test(start_paused = true)]
async fn a_new_room_writes_owner_only_files() {
    let root = tempfile::tempdir().unwrap();
    let new = NewRoom {
        code: "ZZZZ".into(),
        config: config(CardMode::Virtual),
        host_name: "Host".into(),
        data_dir: Some(root.path().to_path_buf()),
    };
    let _room = actor::create(new, &Limits::default(), &Timings::default(), Clock::new()).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        let mode = |path: &Path| fs::metadata(path).unwrap().permissions().mode() & 0o777;
        let dir = root.path().join("ZZZZ");
        assert_eq!(mode(&dir), 0o700);
        assert_eq!(mode(&dir.join("snapshot.json")), 0o600);
        assert_eq!(mode(&dir.join("journal.jsonl")), 0o600);
    }
}
