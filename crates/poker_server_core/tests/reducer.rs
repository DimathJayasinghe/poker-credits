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
use poker_server_core::protocol::{CardMode, ErrorCode, RoomConfig, ServerMessage, WirePhase};
use poker_server_core::room::state::{Broadcast, HostCommand, Op, Outcome, RoomError, RoomState};

fn config() -> RoomConfig {
    RoomConfig {
        card_mode: CardMode::Physical,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
        solo: None,
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
        command: HostCommand::StartHand { deck: None },
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
        .apply(
            host(HostCommand::StartHand { deck: None }, 1000),
            &Timings::default(),
        )
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
    let early = room.apply(Op::Timeout { at_ms: 30_999 }, &t).unwrap_err();
    assert_eq!(early.code, ErrorCode::BadRequest);
    let actor = active_id(&room);
    let out = room.apply(Op::Timeout { at_ms: 31_000 }, &t).unwrap();
    assert!(out.changed);
    assert_ne!(active_id(&room), actor, "turn moved on");
}

#[test]
fn recover_gives_the_player_on_turn_a_fresh_clock() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
    assert_eq!(room.turn_deadline_ms, Some(31_000));
    let actor = active_id(&room);
    // The server was down for an hour: without recovery the turn would time out at once.
    let out = room.apply(Op::Recover { at_ms: 3_600_000 }, &t).unwrap();
    assert!(out.changed);
    assert_eq!(room.turn_deadline_ms, Some(3_630_000));
    let early = room
        .apply(Op::Timeout { at_ms: 3_600_001 }, &t)
        .unwrap_err();
    assert_eq!(early.code, ErrorCode::BadRequest);
    assert_eq!(active_id(&room), actor, "nobody was timed out");
}

#[test]
fn recover_never_shortens_a_clock_and_changes_nothing_without_one() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    let version = room.state_version;
    assert!(
        !room.apply(Op::Recover { at_ms: 500 }, &t).unwrap().changed,
        "lobby: no clock"
    );
    assert_eq!(room.state_version, version);
    room.apply(host(HostCommand::StartHand { deck: None }, 10_000), &t)
        .unwrap();
    // A recovery time earlier than the turn start (clock skew) would give a shorter clock
    // than the one running: the existing deadline (40 s) stays.
    let out = room.apply(Op::Recover { at_ms: 9_000 }, &t).unwrap();
    assert!(!out.changed);
    assert_eq!(room.turn_deadline_ms, Some(40_000));
}

#[test]
fn pause_freezes_the_clock_and_resume_gives_back_the_remaining_time() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    ops.push(host(HostCommand::StartHand { deck: None }, 1000));
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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
    let shown = room.view(&|_| true).pending_rebuys;
    assert_eq!(
        shown.len(),
        1,
        "the host can see the request in the public view"
    );
    assert!(!shown[0].approved);
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
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
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

// ---------------------------------------------------------------------------------------------
// Seat order
// ---------------------------------------------------------------------------------------------

fn seat_of(room: &RoomState, id: &str) -> Option<u8> {
    room.players.get(id).and_then(|p| p.seat)
}

fn choose(id: &str, seat_index: u8, at_ms: u64) -> Op {
    Op::ChooseSeat {
        player_id: id.into(),
        seat_index,
        at_ms,
    }
}

#[test]
fn a_player_can_pick_a_free_seat_before_the_game_starts() {
    let (mut room, _) = table_of_three();
    let version = room.state_version;
    room.apply(choose("p_2", 6, 10), &Timings::default())
        .unwrap();
    assert_eq!(seat_of(&room, "p_2"), Some(6));
    assert!(room.state_version > version, "clients must see the change");
    assert_eq!(room.game.table.seats.len(), 3);
}

#[test]
fn a_player_cannot_take_a_seat_someone_holds() {
    let (mut room, _) = table_of_three();
    let before = seat_of(&room, "p_3");
    let err = room
        .apply(choose("p_2", before.unwrap(), 10), &Timings::default())
        .unwrap_err();
    assert_eq!(err.code, ErrorCode::SeatOccupied);
    assert_eq!(seat_of(&room, "p_3"), before);
}

#[test]
fn choosing_your_own_seat_again_is_harmless() {
    let (mut room, _) = table_of_three();
    let own = seat_of(&room, "p_2").unwrap();
    room.apply(choose("p_2", own, 10), &Timings::default())
        .unwrap();
    assert_eq!(seat_of(&room, "p_2"), Some(own));
}

#[test]
fn a_seat_outside_the_table_is_rejected() {
    let (mut room, _) = table_of_three();
    let err = room
        .apply(choose("p_2", 10, 10), &Timings::default())
        .unwrap_err();
    assert_eq!(err.code, ErrorCode::BadRequest);
    assert_eq!(seat_of(&room, "p_2"), Some(1));
}

#[test]
fn a_spectator_cannot_take_a_seat_this_way() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(join("p_9", "Eve", true, 5), &t).unwrap();
    assert!(room.apply(choose("p_9", 5, 10), &t).is_err());
    assert_eq!(seat_of(&room, "p_9"), None);
}

#[test]
fn the_host_swaps_two_players_and_both_records_follow() {
    let (mut room, _) = table_of_three();
    let (a, b) = (
        seat_of(&room, "p_2").unwrap(),
        seat_of(&room, "p_3").unwrap(),
    );
    room.apply(
        host(
            HostCommand::MoveSeat {
                player_id: "p_2".into(),
                seat_index: b,
            },
            10,
        ),
        &Timings::default(),
    )
    .unwrap();
    assert_eq!(seat_of(&room, "p_2"), Some(b));
    assert_eq!(seat_of(&room, "p_3"), Some(a));
    // The engine table and the room's own records agree.
    for (id, wanted) in [("p_2", b), ("p_3", a)] {
        let engine_seat = room
            .game
            .table
            .seats
            .iter()
            .find(|s| s.player_id.as_str() == id)
            .unwrap();
        assert_eq!(engine_seat.index.get(), wanted);
    }
}

#[test]
fn only_the_host_may_move_somebody_else() {
    let (mut room, _) = table_of_three();
    let err = room
        .apply(
            Op::Host {
                by: "p_2".into(),
                command: HostCommand::MoveSeat {
                    player_id: "p_3".into(),
                    seat_index: 7,
                },
                at_ms: 10,
            },
            &Timings::default(),
        )
        .unwrap_err();
    assert_eq!(err.code, ErrorCode::HostOnlyAction);
}

#[test]
fn nobody_moves_during_a_hand_and_nothing_changes() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
    let seats: Vec<_> = ["p_1", "p_2", "p_3"].map(|id| seat_of(&room, id)).to_vec();
    let version = room.state_version;
    assert!(room.apply(choose("p_2", 8, 1100), &t).is_err());
    assert!(
        room.apply(
            host(
                HostCommand::MoveSeat {
                    player_id: "p_3".into(),
                    seat_index: 9,
                },
                1200,
            ),
            &t,
        )
        .is_err()
    );
    let after: Vec<_> = ["p_1", "p_2", "p_3"].map(|id| seat_of(&room, id)).to_vec();
    assert_eq!(seats, after);
    assert_eq!(
        room.state_version, version,
        "a refused move must not bump the version"
    );
}

#[test]
fn the_new_order_survives_a_snapshot_round_trip() {
    let (mut room, _) = table_of_three();
    room.apply(choose("p_3", 9, 10), &Timings::default())
        .unwrap();
    let json = serde_json::to_string(&room).unwrap();
    let restored: RoomState = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, room);
    assert_eq!(seat_of(&restored, "p_3"), Some(9));
}

#[test]
fn once_the_game_has_run_guests_cannot_hop_seats_but_the_host_can_move_them() {
    let (mut room, _) = table_of_three();
    let t = Timings::default();
    room.apply(host(HostCommand::StartHand { deck: None }, 1000), &t)
        .unwrap();
    // Everybody folds until the hand is over and the table is between hands.
    let mut at = 1100;
    while room.game.legal_actions().is_some() {
        act(&mut room, PlayerAction::Fold, at).unwrap();
        at += 100;
    }
    assert_ne!(room.game.table.phase, poker_engine::Phase::Lobby);
    let before = seat_of(&room, "p_2");

    let err = room.apply(choose("p_2", 8, at), &t).unwrap_err();
    assert_eq!(
        err.code,
        ErrorCode::HandInProgress,
        "blinds cannot be dodged by moving"
    );
    assert_eq!(seat_of(&room, "p_2"), before);

    room.apply(
        host(
            HostCommand::MoveSeat {
                player_id: "p_2".into(),
                seat_index: 8,
            },
            at + 10,
        ),
        &t,
    )
    .unwrap();
    assert_eq!(seat_of(&room, "p_2"), Some(8));
}
