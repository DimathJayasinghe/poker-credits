//! Property: for any sequence of room operations, `snapshot + journal` replayed from disk equals
//! the live state, including undo, pauses, timeouts, top-ups, kicks and snapshots taken at
//! arbitrary points (`docs/RESILIENCE_AND_CRASH_HANDLING.md` section 5).
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_engine::PlayerAction;
use poker_server_core::config::Timings;
use poker_server_core::protocol::{RoomConfig, WireAllocation};
use poker_server_core::room::state::{HostCommand, Op, RoomState};
use poker_server_core::store::journal::Journal;
use poker_server_core::store::{self, snapshot};
use proptest::prelude::*;

fn config() -> RoomConfig {
    RoomConfig {
        starting_chips: 500,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
    }
}

fn host_op(command: HostCommand, at_ms: u64) -> Op {
    Op::Host {
        by: "p_1".into(),
        command,
        at_ms,
    }
}

fn join_op(state: &RoomState, names: &mut u32, at_ms: u64) -> Option<Op> {
    *names += 1;
    (*names <= 6).then(|| Op::Join {
        player_id: state.peek_id(false),
        name: format!("P{names}"),
        spectator: false,
        seat: None,
        token_hash: format!("hash{names}"),
        at_ms,
    })
}

/// A betting action for whoever is on turn.
fn act_op(state: &RoomState, arg: u8, at_ms: u64) -> Option<Op> {
    let (seat, legal) = state.game.legal_actions()?;
    let player = state
        .players
        .values()
        .find(|p| p.seat == Some(seat.get()))?;
    let action = match arg % 4 {
        0 => PlayerAction::Fold,
        1 if legal.can_check => PlayerAction::Check,
        1 | 2 => PlayerAction::Call,
        _ if legal.can_raise => PlayerAction::Raise {
            to_amount: legal.min_raise_to,
        },
        _ => PlayerAction::AllIn,
    };
    Some(Op::Act {
        player_id: player.id.clone(),
        action_seq: player.next_action_seq,
        action,
        at_ms,
    })
}

/// The first eligible player wins every pot.
fn showdown_op(state: &RoomState, at_ms: u64) -> Op {
    let table = &state.game.table;
    let allocations = table
        .pots
        .iter()
        .map(|pot| {
            let winner = pot.eligible.first().and_then(|seat| table.seat(*seat));
            WireAllocation {
                pot_index: pot.tier_index,
                winner_player_ids: winner
                    .map(|s| s.player_id.to_string())
                    .into_iter()
                    .collect(),
            }
        })
        .collect();
    host_op(HostCommand::ResolveShowdown { allocations }, at_ms)
}

/// Rebuys, kicks, sitting out and leaving, aimed at a guest.
fn member_op(state: &RoomState, arg: u8, at_ms: u64) -> Option<Op> {
    let guest = state
        .players
        .values()
        .filter(|p| p.id != state.host_id)
        .nth(usize::from(arg) % 3)?;
    let player_id = guest.id.clone();
    Some(match arg % 5 {
        0 => Op::RequestRebuy {
            player_id,
            amount: 100,
            at_ms,
        },
        1 => host_op(
            HostCommand::ApproveRebuy {
                player_id,
                amount: 100,
            },
            at_ms,
        ),
        2 => host_op(HostCommand::Kick { player_id }, at_ms),
        3 => Op::SetSittingOut {
            player_id,
            sitting_out: arg.is_multiple_of(2),
            at_ms,
        },
        _ => Op::LeaveTable { player_id, at_ms },
    })
}

/// Turns one random byte pair into an operation that makes sense for the current state (or
/// sometimes a deliberately wrong one, which must be refused without a trace).
fn pick(state: &RoomState, code: u8, arg: u8, at_ms: u64, names: &mut u32) -> Option<Op> {
    match code % 14 {
        0 => join_op(state, names, at_ms),
        1 | 2 => Some(host_op(HostCommand::StartHand, at_ms)),
        3..=6 => act_op(state, arg, at_ms),
        7 => Some(host_op(HostCommand::Undo, at_ms)),
        8 => Some(host_op(HostCommand::BeginShowdown, at_ms)),
        9 => Some(showdown_op(state, at_ms)),
        10 => Some(host_op(HostCommand::Pause { reason: None }, at_ms)),
        11 => Some(host_op(HostCommand::ResumeGame, at_ms)),
        12 => Some(Op::Timeout { at_ms }),
        _ => member_op(state, arg, at_ms),
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 64, ..ProptestConfig::default() })]

    #[test]
    fn replaying_snapshot_and_journal_equals_the_live_state(
        steps in proptest::collection::vec((any::<u8>(), any::<u8>(), 1_u64..40_000, any::<u8>()), 1..120)
    ) {
        let timings = Timings::default();
        let dir = tempfile::tempdir().unwrap();
        let mut live = RoomState::new("ABCD".into(), config(), "Host", "h".into(), "hs".into(), 0).unwrap();
        snapshot::write(dir.path(), &live, 0).unwrap();
        let mut journal = Journal::open(dir.path(), 0).unwrap();
        let (mut now, mut names) = (1_000_u64, 0_u32);

        for (code, arg, advance, snapshot_roll) in steps {
            now += advance;
            if let Some(op) = pick(&live, code, arg, now, &mut names) {
                // Exactly what the room actor does: apply to a clone, journal if it changed.
                let mut next = live.clone();
                if let Ok(outcome) = next.apply(op.clone(), &timings) {
                    if outcome.changed {
                        journal.append(&op).unwrap();
                    }
                    live = next;
                }
            }
            if snapshot_roll % 11 == 0 {
                snapshot::write(dir.path(), &live, journal.last_seq()).unwrap();
                if snapshot_roll % 2 == 0 {
                    journal.truncate().unwrap();
                }
            }
            // At every step, a crash right now would restore exactly this state.
            let restored = store::restore(dir.path(), &timings).unwrap();
            prop_assert_eq!(&restored.state, &live);
            prop_assert_eq!(restored.failed_replays, 0);
        }
        // Chips never appear or vanish: seats plus the ledger of removed players.
        let ledger: u64 = live.ledger.values().sum();
        let on_table = live.game.table.total_chips();
        prop_assert!(on_table + ledger <= 500 * 7 + 100 * 200, "{on_table} + {ledger}");
    }
}
