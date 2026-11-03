//! Tests for the pure room reducer: no sockets, no clock, no randomness.

#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::cast_possible_truncation
)]

use poker_engine::{Chips, PlayerAction};
use poker_server_core::config::Timings;
use poker_server_core::protocol::{ErrorCode, RoomConfig, ServerMessage, WirePhase};
use poker_server_core::room::state::{Broadcast, HostCommand, Op, Outcome, RoomError, RoomState};

fn config() -> RoomConfig {
    RoomConfig {
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
    }
}

fn new_room() -> RoomState {
    RoomState::new(
        "ABCD".into(),
        config(),
        "Host",
        "host-token-hash".into(),
        "host-session-hash".into(),
        0,
    )
    .unwrap()
}

fn join(id: &str, name: &str, spectator: bool, at_ms: u64) -> Op {
    Op::Join {
        player_id: id.into(),
        name: name.into(),
        spectator,
        seat: None,
        token_hash: format!("hash-{id}"),
        at_ms,
    }
}

fn host(command: HostCommand, at_ms: u64) -> Op {
    Op::Host {
        by: "p_1".into(),
        command,
        at_ms,
    }
}

/// Host plus two players (`p_1`, `p_2`, `p_3`), ready to deal.
fn table_of_three() -> (RoomState, Vec<Op>) {
    let mut room = new_room();
    let timings = Timings::default();
    let ops = vec![join("p_2", "Bob", false, 1), join("p_3", "Cy", false, 2)];
    for op in &ops {
        room.apply(op.clone(), &timings).unwrap();
    }
    (room, ops)
}

fn act(room: &mut RoomState, action: PlayerAction, at_ms: u64) -> Result<Outcome, RoomError> {
    let (seat, _) = room.game.legal_actions().expect("someone must be on turn");
    let id = room
        .players
        .values()
        .find(|p| p.seat == Some(seat.get()))
        .map(|p| (p.id.clone(), p.next_action_seq))
        .unwrap();
    room.apply(
        Op::Act {
            player_id: id.0,
            action_seq: id.1,
            action,
            at_ms,
        },
        &Timings::default(),
    )
}

fn active_id(room: &RoomState) -> String {
    let (seat, _) = room.game.legal_actions().unwrap();
    room.players
        .values()
        .find(|p| p.seat == Some(seat.get()))
        .unwrap()
        .id
        .clone()
}

fn total_chips(room: &RoomState) -> u64 {
    room.game.table.total_chips()
}

#[test]
fn new_room_seats_the_host_at_seat_zero() {
    let room = new_room();
    assert_eq!(room.host_id, "p_1");
    assert_eq!(room.players["p_1"].seat, Some(0));
    assert_eq!(room.game.table.seats.len(), 1);
}

#[test]
fn join_rejects_duplicate_and_invalid_names() {
    let mut room = new_room();
    let t = Timings::default();
    let dup = room.apply(join("p_2", "host", false, 1), &t).unwrap_err();
    assert_eq!(dup.code, ErrorCode::NameInvalid);
    let bad = room
        .apply(join("p_2", "bad<name>", false, 1), &t)
        .unwrap_err();
    assert_eq!(bad.code, ErrorCode::NameInvalid);
    let ok = room.apply(join("p_2", "Bob", false, 1), &t).unwrap();
    assert!(ok.changed);
}

#[test]
fn spectators_have_no_seat_and_count_in_the_view() {
    let mut room = new_room();
    room.apply(join("s_2", "Watcher", true, 1), &Timings::default())
        .unwrap();
    assert_eq!(room.players["s_2"].seat, None);
    assert_eq!(room.view(&|_| true).spectator_count, 1);
    assert_eq!(room.view(&|_| true).seats.len(), 1);
}

#[test]
fn only_the_host_can_start_a_hand() {
    let (mut room, _) = table_of_three();
    let op = Op::Host {
        by: "p_2".into(),
        command: HostCommand::StartHand,
        at_ms: 10,
    };
    assert_eq!(
        room.apply(op, &Timings::default()).unwrap_err().code,
        ErrorCode::HostOnlyAction
    );
}

#[test]
fn start_hand_sets_the_turn_clock_and_prompts_the_actor() {
    let (mut room, _) = table_of_three();
    let out = room
        .apply(host(HostCommand::StartHand, 1000), &Timings::default())
        .unwrap();
    assert_eq!(room.turn_deadline_ms, Some(31_000));
    let actor = active_id(&room);
    let prompted = out
        .broadcasts
        .iter()
        .any(|b| matches!(b, Broadcast::To(to, ServerMessage::TurnPrompt { .. }) if *to == actor));
    assert!(prompted, "the player on turn gets a TURN_PROMPT");
    assert_eq!(room.view(&|_| true).phase, WirePhase::PreFlop);
}

#[test]
fn action_seq_counts_duplicates_and_gaps() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    let actor = active_id(&room);
    let first = Op::Act {
        player_id: actor.clone(),
        action_seq: 0,
        action: PlayerAction::Call,
        at_ms: 1100,
    };
    assert!(room.apply(first.clone(), &t).unwrap().changed);
    // Same seq again: acknowledged, nothing applied.
    let before = room.clone();
    let again = room.apply(first, &t).unwrap();
    assert!(again.duplicate && !again.changed);
    assert_eq!(room, before);
    // A gap is out of sync.
    let ahead = Op::Act {
        player_id: actor,
        action_seq: 5,
        action: PlayerAction::Fold,
        at_ms: 1200,
    };
    assert_eq!(
        room.apply(ahead, &t).unwrap_err().code,
        ErrorCode::OutOfSync
    );
}

#[test]
fn acting_out_of_turn_is_refused() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    let actor = active_id(&room);
    let other = ["p_1", "p_2", "p_3"]
        .into_iter()
        .find(|id| *id != actor)
        .unwrap();
    let op = Op::Act {
        player_id: other.into(),
        action_seq: 0,
        action: PlayerAction::Fold,
        at_ms: 1100,
    };
    assert_eq!(room.apply(op, &t).unwrap_err().code, ErrorCode::NotYourTurn);
}

#[test]
fn timeout_waits_for_the_deadline_then_acts() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    let early = room.apply(Op::Timeout { at_ms: 30_999 }, &t).unwrap_err();
    assert_eq!(early.code, ErrorCode::BadRequest);
    let actor = active_id(&room);
    let out = room.apply(Op::Timeout { at_ms: 31_000 }, &t).unwrap();
    assert!(out.changed);
    assert_ne!(active_id(&room), actor, "turn moved on");
}

#[test]
fn pause_freezes_the_clock_and_resume_gives_back_the_remaining_time() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    room.apply(host(HostCommand::Pause { reason: None }, 11_000), &t)
        .unwrap();
    assert_eq!(room.turn_deadline_ms, None);
    assert_eq!(room.paused_remaining_ms, Some(20_000));
    assert_eq!(room.view(&|_| true).phase, WirePhase::Paused);
    // No timeouts and no actions while paused.
    assert_eq!(
        room.apply(Op::Timeout { at_ms: 99_000 }, &t)
            .unwrap_err()
            .code,
        ErrorCode::GamePaused
    );
    room.apply(host(HostCommand::ResumeGame, 50_000), &t)
        .unwrap();
    assert_eq!(room.turn_deadline_ms, Some(70_000));
    assert_eq!(room.paused_remaining_ms, None);
}

#[test]
fn chips_are_conserved_through_a_hand() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    assert_eq!(total_chips(&room), 3000);
    act(
        &mut room,
        PlayerAction::Raise {
            to_amount: Chips::new(40).unwrap(),
        },
        1100,
    )
    .unwrap();
    act(&mut room, PlayerAction::Call, 1200).unwrap();
    assert_eq!(total_chips(&room), 3000);
    act(&mut room, PlayerAction::AllIn, 1300).unwrap();
    assert_eq!(total_chips(&room), 3000);
}

#[test]
fn state_version_rises_only_when_state_changes() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    let v0 = room.state_version;
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    assert_eq!(room.state_version, v0 + 1);
    let v1 = room.state_version;
    let _ = room.apply(Op::Timeout { at_ms: 1001 }, &t);
    assert_eq!(room.state_version, v1, "a refused op changes nothing");
}

#[test]
fn replaying_the_ops_rebuilds_an_identical_state() {
    let (mut live, joins) = table_of_three();
    let t = Timings::default();
    let mut ops = joins;
    ops.push(host(HostCommand::StartHand, 1000));
    live.apply(ops[2].clone(), &t).unwrap();
    for (n, action) in [PlayerAction::Call, PlayerAction::Call, PlayerAction::Check]
        .into_iter()
        .enumerate()
    {
        let (seat, _) = live.game.legal_actions().unwrap();
        let p = live
            .players
            .values()
            .find(|p| p.seat == Some(seat.get()))
            .unwrap()
            .clone();
        let op = Op::Act {
            player_id: p.id,
            action_seq: p.next_action_seq,
            action,
            at_ms: 1100 + n as u64,
        };
        live.apply(op.clone(), &t).unwrap();
        ops.push(op);
    }
    ops.push(Op::Timeout { at_ms: 100_000 });
    let _ = live.apply(Op::Timeout { at_ms: 100_000 }, &t);

    let mut replay = new_room();
    for op in ops {
        let _ = replay.apply(op, &t);
    }
    assert_eq!(replay, live);

    // And it survives a JSON snapshot round trip.
    let json = serde_json::to_string(&live).unwrap();
    let restored: RoomState = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, live);
}

#[test]
fn kicking_a_seated_player_removes_them_and_logs_their_chips() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(
        host(
            HostCommand::Kick {
                player_id: "p_3".into(),
            },
            10,
        ),
        &t,
    )
    .unwrap();
    assert!(!room.players.contains_key("p_3"));
    assert_eq!(room.ledger.get("p_3"), Some(&1000));
    assert_eq!(room.game.table.seats.len(), 2);
}

#[test]
fn the_host_cannot_be_kicked() {
    let (mut room, _) = table_of_three();
    let err = room.apply(
        host(
            HostCommand::Kick {
                player_id: "p_1".into(),
            },
            10,
        ),
        &Timings::default(),
    );
    assert_eq!(err.unwrap_err().code, ErrorCode::BadRequest);
}

#[test]
fn a_kick_during_a_hand_folds_first_and_removes_after_the_hand() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    let victim = ["p_2", "p_3"]
        .into_iter()
        .find(|id| *id != active_id(&room))
        .unwrap();
    room.apply(
        host(
            HostCommand::Kick {
                player_id: victim.into(),
            },
            1100,
        ),
        &t,
    )
    .unwrap();
    // Folded now, still seated until the hand is over.
    assert!(room.players.contains_key(victim));
    assert_eq!(room.pending_removals, vec![victim.to_owned()]);
    let seat = room
        .game
        .table
        .seat_of(&poker_engine::PlayerId::new(victim))
        .unwrap();
    assert_eq!(seat.status, poker_engine::HandStatus::Folded);
    assert_eq!(total_chips(&room) + room.ledger.values().sum::<u64>(), 3000);
}

#[test]
fn rebuy_request_waits_for_host_approval() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(
        Op::RequestRebuy {
            player_id: "p_2".into(),
            amount: 500,
            at_ms: 5,
        },
        &t,
    )
    .unwrap();
    assert!(!room.pending_rebuys[0].approved);
    room.apply(
        host(
            HostCommand::ApproveRebuy {
                player_id: "p_2".into(),
                amount: 500,
            },
            6,
        ),
        &t,
    )
    .unwrap();
    assert!(room.pending_rebuys.is_empty() || room.pending_rebuys.iter().all(|r| r.approved));
    // The table is between hands (lobby), so the approved top-up applies at once.
    assert!(room.pending_rebuys.is_empty());
    assert_eq!(total_chips(&room), 3500);
}

#[test]
fn presence_check_starts_after_a_long_absence_and_the_host_vote_is_final() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(
        Op::SetSittingOut {
            player_id: "p_3".into(),
            sitting_out: true,
            at_ms: 100,
        },
        &t,
    )
    .unwrap();
    // Too early.
    room.apply(
        Op::Tick {
            at_ms: 100 + t.away_after_ms - 1,
        },
        &t,
    )
    .unwrap();
    assert!(room.presence.is_none());
    let out = room
        .apply(
            Op::Tick {
                at_ms: 100 + t.away_after_ms,
            },
            &t,
        )
        .unwrap();
    assert!(out.changed);
    assert_eq!(room.presence.as_ref().unwrap().subject, "p_3");
    // Host says "gone": removed right away.
    let vote = Op::PresenceVote {
        voter: "p_1".into(),
        subject: "p_3".into(),
        still_playing: false,
        at_ms: 100 + t.away_after_ms + 1,
    };
    room.apply(vote, &t).unwrap();
    assert!(room.presence.is_none());
    assert!(!room.players.contains_key("p_3"));
}

#[test]
fn presence_ack_by_the_subject_cancels_the_check() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(
        Op::SetSittingOut {
            player_id: "p_3".into(),
            sitting_out: true,
            at_ms: 100,
        },
        &t,
    )
    .unwrap();
    room.apply(
        Op::Tick {
            at_ms: 100 + t.away_after_ms,
        },
        &t,
    )
    .unwrap();
    assert!(room.presence.is_some());
    let out = room
        .apply(
            Op::PresenceAck {
                player_id: "p_3".into(),
                at_ms: 100 + t.away_after_ms + 5,
            },
            &t,
        )
        .unwrap();
    assert!(out.changed);
    assert!(room.presence.is_none());
    assert!(room.players.contains_key("p_3"));
}

#[test]
fn presence_check_with_no_replies_keeps_the_player() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(
        Op::SetSittingOut {
            player_id: "p_3".into(),
            sitting_out: true,
            at_ms: 100,
        },
        &t,
    )
    .unwrap();
    room.apply(
        Op::Tick {
            at_ms: 100 + t.away_after_ms,
        },
        &t,
    )
    .unwrap();
    room.apply(
        Op::Tick {
            at_ms: 100 + t.away_after_ms + t.presence_check_ms,
        },
        &t,
    )
    .unwrap();
    assert!(room.presence.is_none());
    assert!(room.players.contains_key("p_3"), "silence is an abstention");
}

#[test]
fn end_game_closes_the_room_to_new_joins() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::EndGame, 10), &t).unwrap();
    assert!(room.ended);
    assert_eq!(
        room.apply(join("p_9", "Late", false, 11), &t)
            .unwrap_err()
            .code,
        ErrorCode::RoomNotFound
    );
}

#[test]
fn rc005_a_top_up_during_a_hand_applies_to_the_following_hand() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand, 1000), &t).unwrap();
    room.apply(
        Op::RequestRebuy {
            player_id: "p_2".into(),
            amount: 500,
            at_ms: 1001,
        },
        &t,
    )
    .unwrap();
    room.apply(
        host(
            HostCommand::ApproveRebuy {
                player_id: "p_2".into(),
                amount: 500,
            },
            1002,
        ),
        &t,
    )
    .unwrap();
    // Mid-hand: approved but not applied, and the table total is untouched.
    assert_eq!(total_chips(&room), 3000);
    assert_eq!(room.pending_rebuys.len(), 1);
    assert!(room.pending_rebuys[0].approved);

    // Everyone folds to the last player: the hand ends and the top-up lands before the next one.
    let mut at = 1100;
    while room.game.legal_actions().is_some() {
        act(&mut room, PlayerAction::Fold, at).unwrap();
        at += 10;
    }
    assert!(
        room.pending_rebuys.is_empty(),
        "applied once the hand was over"
    );
    assert_eq!(total_chips(&room), 3500);
    let stack = room
        .game
        .table
        .seat_of(&poker_engine::PlayerId::new("p_2"))
        .unwrap();
    assert!(
        stack.chips.get() >= 500,
        "p_2 got the 500 on top of what the hand left them"
    );
}
