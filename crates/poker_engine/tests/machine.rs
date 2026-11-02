//! Hand lifecycle: blinds, streets, run-outs, showdown, undo, pause, timeouts.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::command::Allocation;
use poker_engine::{AllocationError, Command, Event, Phase, PlayerAction, PokerError};
use support::{act, chips, dealt, lobby, pid, raise_to, seat, stack, step, try_act, try_step};

fn call_around(state: &mut poker_engine::GameState, players: &[usize]) {
    for player in players {
        act(state, *player, PlayerAction::Call);
    }
}

#[test]
fn blinds_are_posted_and_utg_acts_first() {
    let state = dealt(&[1000, 1000, 1000], 10, 20);
    let table = &state.table;
    assert_eq!(table.phase, Phase::PreFlop);
    assert_eq!(table.hand_number, 1);
    assert_eq!(table.dealer, Some(seat(0)));
    assert_eq!(table.small_blind_seat, Some(seat(1)));
    assert_eq!(table.big_blind_seat, Some(seat(2)));
    assert_eq!(table.active, Some(seat(0)));
    assert_eq!(stack(&state, 1), 990);
    assert_eq!(stack(&state, 2), 980);
    assert_eq!(table.total_pot(), chips(30));
}

#[test]
fn start_hand_reports_what_happened() {
    let mut state = lobby(&[1000, 1000, 1000], 10, 20);
    let events = step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::HandStarted { hand_number: 1, .. }))
    );
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::TurnStarted { seat, .. } if *seat == support::seat(0)))
    );
    assert_eq!(
        events
            .iter()
            .filter(|e| matches!(e, Event::BlindPosted { .. }))
            .count(),
        2
    );
}

#[test]
fn starting_a_hand_twice_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_step(&mut state, Command::StartHand { elapsed_ms: 0 }),
        Err(PokerError::HandInProgress)
    );
}

#[test]
fn start_needs_two_players_with_chips() {
    let mut state = lobby(&[1000], 10, 20);
    assert_eq!(
        try_step(&mut state, Command::StartHand { elapsed_ms: 0 }),
        Err(PokerError::NotEnoughPlayers)
    );
}

#[test]
fn out_of_turn_action_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_act(&mut state, 1, PlayerAction::Call),
        Err(PokerError::NotYourTurn)
    );
    assert_eq!(
        try_act(&mut state, 9, PlayerAction::Call),
        Err(PokerError::UnknownPlayer)
    );
}

#[test]
fn rejected_commands_leave_the_state_untouched() {
    let state = dealt(&[1000, 1000, 1000], 10, 20);
    let before = state.clone();
    let mut copy = state.clone();
    assert!(try_act(&mut copy, 0, PlayerAction::Check).is_err());
    assert_eq!(copy, before);
}

#[test]
fn big_blind_gets_its_option_before_the_flop() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    call_around(&mut state, &[0, 1]);
    assert_eq!(
        state.table.phase,
        Phase::PreFlop,
        "the big blind has not acted yet"
    );
    assert_eq!(state.table.active, Some(seat(2)));
    act(&mut state, 2, PlayerAction::Check);
    assert_eq!(state.table.phase, Phase::Flop);
    assert_eq!(
        state.table.active,
        Some(seat(1)),
        "post-flop action starts left of the button"
    );
    assert_eq!(state.table.current_bet, chips(0));
}

#[test]
fn hand_plays_through_all_streets_to_showdown_and_payout() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    call_around(&mut state, &[0, 1]);
    act(&mut state, 2, PlayerAction::Check);
    for street in [Phase::Turn, Phase::River] {
        for player in [1, 2, 0] {
            act(&mut state, player, PlayerAction::Check);
        }
        assert_eq!(state.table.phase, street);
    }
    for player in [1, 2, 0] {
        act(&mut state, player, PlayerAction::Check);
    }
    assert_eq!(state.table.phase, Phase::Showdown);
    assert_eq!(state.table.pots.len(), 1);
    assert_eq!(state.table.pots[0].amount, chips(60));

    let allocation = Allocation {
        pot_index: 0,
        winners: vec![pid(2)],
    };
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: vec![allocation],
        },
    );
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    assert_eq!(stack(&state, 2), 1040);
    assert_eq!(state.table.total_chips(), 3000);
}

#[test]
fn everyone_folding_to_the_big_blind_wins_uncontested() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Fold);
    let events = act(&mut state, 1, PlayerAction::Fold);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::UncalledReturned { amount, .. } if *amount == chips(10)))
    );
    assert_eq!(stack(&state, 0), 1000);
    assert_eq!(stack(&state, 1), 990);
    assert_eq!(stack(&state, 2), 1010);
}

#[test]
fn uncalled_raise_is_returned_when_everyone_folds() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, raise_to(100));
    act(&mut state, 1, PlayerAction::Fold);
    act(&mut state, 2, PlayerAction::Fold);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    assert_eq!(stack(&state, 0), 1030);
    assert_eq!(stack(&state, 1), 990);
    assert_eq!(stack(&state, 2), 980);
}

#[test]
fn blinds_that_put_everyone_all_in_go_straight_to_the_runout() {
    // Heads-up: the button posts a 10 small blind with its last chips, the big blind has 20.
    let mut state = dealt(&[10, 20], 10, 20);
    let table = &state.table;
    assert_eq!(table.phase, Phase::AllInRunout);
    assert_eq!(table.active, None);
    assert_eq!(table.pots.len(), 1);
    assert_eq!(table.pots[0].amount, chips(20));
    assert_eq!(
        stack(&state, 1),
        10,
        "the unmatched 10 of the big blind went back"
    );

    assert_eq!(
        try_act(&mut state, 0, PlayerAction::Check),
        Err(PokerError::HandNotInProgress),
        "no betting during a run-out"
    );
    step(&mut state, Command::BeginShowdown);
    assert_eq!(state.table.phase, Phase::Showdown);
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: vec![Allocation {
                pot_index: 0,
                winners: vec![pid(0)],
            }],
        },
    );
    assert_eq!(stack(&state, 0), 20);
    assert_eq!(stack(&state, 1), 10);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
}

#[test]
fn three_way_all_in_builds_main_and_side_pot() {
    let mut state = dealt(&[100, 250, 600], 10, 20);
    act(&mut state, 0, PlayerAction::AllIn);
    act(&mut state, 1, PlayerAction::AllIn);
    act(&mut state, 2, PlayerAction::Call);
    assert_eq!(
        state.table.phase,
        Phase::AllInRunout,
        "only one player still has chips"
    );
    let pots = &state.table.pots;
    assert_eq!(
        pots.iter().map(|p| p.amount.get()).collect::<Vec<_>>(),
        vec![300, 300]
    );
    assert_eq!(pots[1].eligible, vec![seat(1), seat(2)]);

    step(&mut state, Command::BeginShowdown);
    let allocations = vec![
        Allocation {
            pot_index: 0,
            winners: vec![pid(1)],
        },
        Allocation {
            pot_index: 1,
            winners: vec![pid(2)],
        },
    ];
    step(&mut state, Command::ResolveShowdown { allocations });
    assert_eq!(stack(&state, 0), 0);
    assert_eq!(stack(&state, 1), 300);
    assert_eq!(stack(&state, 2), 650);
    assert_eq!(state.table.total_chips(), 950);
}

#[test]
fn a_player_with_chips_alone_against_an_all_in_is_not_asked_to_bet() {
    let mut state = dealt(&[1000, 1000, 40], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    act(&mut state, 2, PlayerAction::AllIn); // BB shoves 40 total
    act(&mut state, 0, PlayerAction::Fold);
    act(&mut state, 1, PlayerAction::Call);
    // p1 is the only player with chips; p2 is all-in: straight to the run-out.
    assert_eq!(state.table.phase, Phase::AllInRunout);
}

#[test]
fn tie_splits_the_pot_with_the_odd_chip_clockwise_from_the_button() {
    let mut state = dealt(&[1000, 1000, 1000], 1, 1);
    // blinds 1/1: pot after everyone calls and checks down is 3 chips... build a 101 pot instead.
    act(&mut state, 0, raise_to(51));
    act(&mut state, 1, PlayerAction::Fold);
    act(&mut state, 2, PlayerAction::Call);
    for _ in 0..3 {
        act(&mut state, 2, PlayerAction::Check);
        act(&mut state, 0, PlayerAction::Check);
    }
    assert_eq!(state.table.phase, Phase::Showdown);
    let pot = state.table.pots[0].amount.get();
    assert_eq!(pot, 103);
    let winners = vec![pid(0), pid(2)];
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: vec![Allocation {
                pot_index: 0,
                winners,
            }],
        },
    );
    // Button is seat 0, so seat 2 is first clockwise and takes the extra chip.
    assert_eq!(stack(&state, 2), 949 + 52);
    assert_eq!(stack(&state, 0), 949 + 51);
}

#[test]
fn showdown_allocation_is_validated() {
    let mut state = dealt(&[1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Check);
    for _ in 0..3 {
        act(&mut state, 1, PlayerAction::Check);
        act(&mut state, 0, PlayerAction::Check);
    }
    assert_eq!(state.table.phase, Phase::Showdown);
    let resolve = |allocations: Vec<Allocation>| Command::ResolveShowdown { allocations };
    let wrong = |error| Err(PokerError::InvalidAllocation(error));

    assert_eq!(
        try_step(&mut state, resolve(vec![])),
        wrong(AllocationError::MissingPot { pot_index: 0 })
    );
    assert_eq!(
        try_step(
            &mut state,
            resolve(vec![Allocation {
                pot_index: 3,
                winners: vec![pid(0)]
            }])
        ),
        wrong(AllocationError::UnknownPot { pot_index: 3 })
    );
    assert_eq!(
        try_step(
            &mut state,
            resolve(vec![Allocation {
                pot_index: 0,
                winners: vec![]
            }])
        ),
        wrong(AllocationError::NoWinners { pot_index: 0 })
    );
    assert_eq!(
        try_step(
            &mut state,
            resolve(vec![Allocation {
                pot_index: 0,
                winners: vec![pid(7)]
            }])
        ),
        Err(PokerError::UnknownPlayer)
    );
    let twice = vec![
        Allocation {
            pot_index: 0,
            winners: vec![pid(0)],
        },
        Allocation {
            pot_index: 0,
            winners: vec![pid(1)],
        },
    ];
    assert_eq!(
        try_step(&mut state, resolve(twice)),
        wrong(AllocationError::DuplicatePot { pot_index: 0 })
    );
}

#[test]
fn folded_player_cannot_win_a_pot() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, raise_to(60));
    act(&mut state, 1, PlayerAction::Fold);
    act(&mut state, 2, PlayerAction::Call);
    for _ in 0..3 {
        act(&mut state, 2, PlayerAction::Check);
        act(&mut state, 0, PlayerAction::Check);
    }
    let allocation = Allocation {
        pot_index: 0,
        winners: vec![pid(1)],
    };
    assert_eq!(
        try_step(
            &mut state,
            Command::ResolveShowdown {
                allocations: vec![allocation]
            }
        ),
        Err(PokerError::InvalidAllocation(
            AllocationError::IneligibleWinner {
                pot_index: 0,
                player_id: pid(1)
            }
        ))
    );
}

#[test]
fn resolve_outside_showdown_is_an_illegal_transition() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_step(
            &mut state,
            Command::ResolveShowdown {
                allocations: vec![]
            }
        ),
        Err(PokerError::IllegalTransition {
            from: Phase::PreFlop,
            to: Phase::NextHandPrep
        })
    );
    assert_eq!(
        try_step(&mut state, Command::BeginShowdown),
        Err(PokerError::IllegalTransition {
            from: Phase::PreFlop,
            to: Phase::Showdown
        })
    );
}

#[test]
fn timeout_folds_when_facing_a_bet_and_checks_when_free() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    let events = step(&mut state, Command::Timeout { player_id: pid(0) });
    assert!(events.iter().any(|e| matches!(
        e,
        Event::ActionPerformed {
            auto: true,
            action: poker_engine::ActionKind::Fold,
            ..
        }
    )));
    act(&mut state, 1, PlayerAction::Call);
    let events = step(&mut state, Command::Timeout { player_id: pid(2) });
    assert!(events.iter().any(|e| matches!(
        e,
        Event::ActionPerformed {
            auto: true,
            action: poker_engine::ActionKind::Check,
            ..
        }
    )));
    assert_eq!(
        try_step(&mut state, Command::Timeout { player_id: pid(0) }),
        Err(PokerError::NotYourTurn)
    );
}

#[test]
fn pause_blocks_play_and_resume_restores_the_exact_turn() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    let before = state.table.clone();
    step(&mut state, Command::Pause);
    assert_eq!(
        try_act(&mut state, 0, PlayerAction::Call),
        Err(PokerError::GamePaused)
    );
    assert_eq!(
        try_step(&mut state, Command::Timeout { player_id: pid(0) }),
        Err(PokerError::GamePaused)
    );
    assert_eq!(
        try_step(&mut state, Command::Pause),
        Err(PokerError::GamePaused)
    );
    assert!(state.legal_actions().is_none());
    step(&mut state, Command::Resume);
    assert_eq!(state.table, before);
    assert_eq!(
        try_step(&mut state, Command::Resume),
        Err(PokerError::NotPaused)
    );
}

#[test]
fn pause_needs_a_hand_in_progress() {
    let mut state = lobby(&[1000, 1000], 10, 20);
    assert_eq!(
        try_step(&mut state, Command::Pause),
        Err(PokerError::HandNotInProgress)
    );
}

#[test]
fn undo_steps_back_and_keeps_the_pause_flag() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    let after_deal = state.table.clone();
    act(&mut state, 0, raise_to(60));
    step(&mut state, Command::Pause);
    step(&mut state, Command::Undo);
    let table = &state.table;
    assert!(table.paused, "undo must not silently unpause");
    assert_eq!(table.current_bet, after_deal.current_bet);
    assert_eq!(table.active, after_deal.active);
    assert_eq!(table.seats, after_deal.seats);
    step(&mut state, Command::Resume);
    act(&mut state, 0, PlayerAction::Call);
}

#[test]
fn undo_keeps_a_sit_out_request_made_after_the_action() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Fold);
    step(
        &mut state,
        Command::SetSittingOut {
            player_id: pid(0),
            sitting_out: true,
        },
    );
    step(&mut state, Command::Undo);
    assert!(
        state.table.seat_of(&pid(0)).unwrap().sitting_out,
        "the request must survive the undo"
    );
    assert_eq!(
        state.table.active,
        Some(seat(0)),
        "the fold itself was taken back"
    );
}

#[test]
fn commands_declare_who_may_send_them() {
    use poker_engine::command::Origin;
    let action = Command::Action {
        player_id: pid(0),
        action: PlayerAction::Fold,
    };
    assert_eq!(action.origin(), Origin::Player);
    assert_eq!(
        Command::SetSittingOut {
            player_id: pid(0),
            sitting_out: true
        }
        .origin(),
        Origin::Player
    );
    assert_eq!(
        Command::Timeout { player_id: pid(0) }.origin(),
        Origin::Server,
        "only the server's turn timer may time a player out"
    );
    for host_only in [
        Command::StartHand { elapsed_ms: 0 },
        Command::Undo,
        Command::Pause,
        Command::Resume,
        Command::BeginShowdown,
    ] {
        assert_eq!(host_only.origin(), Origin::Host);
    }
}

#[test]
fn undo_goes_back_at_most_five_steps() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    call_around(&mut state, &[0, 1]);
    act(&mut state, 2, PlayerAction::Check);
    for player in [1, 2, 0] {
        act(&mut state, player, PlayerAction::Check);
    }
    // Deal + 3 calls/checks + 3 more checks = 7 recorded commands; only the last 5 remain.
    assert_eq!(state.history.len(), 5);
    for _ in 0..5 {
        step(&mut state, Command::Undo);
    }
    assert_eq!(
        try_step(&mut state, Command::Undo),
        Err(PokerError::NothingToUndo)
    );
}

#[test]
fn undo_after_a_fresh_snapshot_round_trip_is_identical() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, raise_to(60));
    let json = serde_json::to_string(&state).unwrap();
    let mut restored: poker_engine::GameState = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, state);
    step(&mut state, Command::Undo);
    step(&mut restored, Command::Undo);
    assert_eq!(restored, state);
}

#[test]
fn seating_changes_are_validated() {
    let mut state = lobby(&[1000, 1000], 10, 20);
    let add = |index: usize, at: u8, amount: u64| Command::AddPlayer {
        player_id: pid(index),
        seat: seat(at),
        chips: chips(amount),
    };
    assert_eq!(
        try_step(&mut state, add(0, 5, 100)),
        Err(PokerError::PlayerExists)
    );
    assert_eq!(
        try_step(&mut state, add(7, 0, 100)),
        Err(PokerError::SeatOccupied)
    );
    assert_eq!(
        try_step(&mut state, add(7, 5, 0)),
        Err(PokerError::InvalidAmount)
    );
    assert_eq!(
        try_step(&mut state, add(7, 5, poker_engine::MAX_CHIPS + 1)),
        Err(PokerError::InvalidAmount)
    );
    assert!(poker_engine::SeatIndex::new(10).is_err());
}

#[test]
fn rebuy_and_removal_wait_for_the_end_of_the_hand() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    let rebuy = Command::Rebuy {
        player_id: pid(0),
        amount: chips(500),
    };
    assert_eq!(
        try_step(&mut state, rebuy.clone()),
        Err(PokerError::HandInProgress)
    );
    assert_eq!(
        try_step(&mut state, Command::RemovePlayer { player_id: pid(0) }),
        Err(PokerError::HandInProgress)
    );
    act(&mut state, 0, PlayerAction::Fold);
    act(&mut state, 1, PlayerAction::Fold);
    step(&mut state, rebuy);
    assert_eq!(stack(&state, 0), 1500);
    step(&mut state, Command::RemovePlayer { player_id: pid(0) });
    assert!(state.table.seat_of(&pid(0)).is_none());
}

#[test]
fn rebuy_over_the_stack_limit_is_rejected() {
    let mut state = lobby(&[1000, 1000], 10, 20);
    let too_much = Command::Rebuy {
        player_id: pid(0),
        amount: chips(poker_engine::MAX_CHIPS),
    };
    assert_eq!(
        try_step(&mut state, too_much),
        Err(PokerError::InvalidAmount)
    );
}

#[test]
fn busting_down_to_one_player_returns_to_the_lobby() {
    let mut state = dealt(&[100, 100], 10, 20);
    act(&mut state, 0, PlayerAction::AllIn);
    act(&mut state, 1, PlayerAction::Call);
    step(&mut state, Command::BeginShowdown);
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: vec![Allocation {
                pot_index: 0,
                winners: vec![pid(1)],
            }],
        },
    );
    assert_eq!(state.table.phase, Phase::Lobby);
    assert_eq!(stack(&state, 1), 200);
    assert_eq!(
        try_step(&mut state, Command::StartHand { elapsed_ms: 0 }),
        Err(PokerError::NotEnoughPlayers)
    );
}

#[test]
fn heads_up_button_acts_first_before_the_flop_and_last_after() {
    let mut state = dealt(&[1000, 1000], 10, 20);
    assert_eq!(state.table.dealer, Some(seat(0)));
    assert_eq!(
        state.table.active,
        Some(seat(0)),
        "the button is the small blind and acts first"
    );
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Check);
    assert_eq!(state.table.phase, Phase::Flop);
    assert_eq!(
        state.table.active,
        Some(seat(1)),
        "the big blind acts first after the flop"
    );
}

#[test]
fn ante_goes_to_the_pot_but_not_to_the_street_bet() {
    let mut state = poker_engine::GameState::new(support::cash(10, 20, 5)).unwrap();
    for index in 0..3_u8 {
        step(
            &mut state,
            Command::AddPlayer {
                player_id: pid(usize::from(index)),
                seat: seat(index),
                chips: chips(1000),
            },
        );
    }
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(state.table.total_pot(), chips(45));
    assert_eq!(state.table.current_bet, chips(20));
    let utg = state.table.seat_of(&pid(0)).unwrap();
    assert_eq!(utg.street_bet, chips(0));
    assert_eq!(utg.chips, chips(995));
    assert_eq!(state.legal_actions().unwrap().1.call_amount, chips(20));
}

#[test]
fn sitting_out_players_are_not_dealt_in() {
    let mut state = lobby(&[1000, 1000, 1000], 10, 20);
    step(
        &mut state,
        Command::SetSittingOut {
            player_id: pid(0),
            sitting_out: true,
        },
    );
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().status,
        poker_engine::HandStatus::Out
    );
    assert_eq!(state.table.contesting_count(), 2);
    assert_eq!(stack(&state, 0), 1000);
}

#[test]
fn leaving_on_your_turn_folds_and_sits_out_until_the_next_hand() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    let events = step(&mut state, Command::LeaveHand { player_id: pid(0) });
    assert!(events.iter().any(|e| matches!(
        e,
        Event::ActionPerformed {
            action: poker_engine::ActionKind::Fold,
            auto: true,
            ..
        }
    )));
    assert_eq!(state.table.active, Some(seat(1)), "play moves on at once");
    let leaver = state.table.seat_of(&pid(0)).unwrap();
    assert_eq!(leaver.status, poker_engine::HandStatus::Folded);
    assert!(leaver.sitting_out);

    act(&mut state, 1, PlayerAction::Fold);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().status,
        poker_engine::HandStatus::Out,
        "not dealt in"
    );
}

#[test]
fn leaving_out_of_turn_folds_without_moving_the_turn() {
    let mut state = dealt(&[1000, 1000, 1000, 1000], 10, 20);
    let active = state.table.active;
    step(&mut state, Command::LeaveHand { player_id: pid(2) });
    assert_eq!(state.table.active, active);
    assert_eq!(
        state.table.seat_of(&pid(2)).unwrap().status,
        poker_engine::HandStatus::Folded
    );
}

#[test]
fn leaving_can_end_the_hand_for_the_last_opponent() {
    let mut state = dealt(&[1000, 1000], 10, 20);
    step(&mut state, Command::LeaveHand { player_id: pid(1) });
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    assert!(stack(&state, 0) > 1000, "the stayer wins the blinds");
    assert_eq!(
        try_step(&mut state, Command::StartHand { elapsed_ms: 0 }),
        Err(PokerError::NotEnoughPlayers),
        "nobody to play until the leaver sits back in"
    );
}

#[test]
fn an_all_in_player_who_leaves_stays_in_the_hand() {
    let mut state = dealt(&[100, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::AllIn);
    step(&mut state, Command::LeaveHand { player_id: pid(0) });
    let seat = state.table.seat_of(&pid(0)).unwrap();
    assert_eq!(seat.status, poker_engine::HandStatus::AllIn);
    assert!(seat.sitting_out);
}

#[test]
fn leaving_between_hands_only_sets_the_sit_out_flag() {
    let mut state = lobby(&[1000, 1000, 1000], 10, 20);
    step(&mut state, Command::LeaveHand { player_id: pid(0) });
    assert!(state.table.seat_of(&pid(0)).unwrap().sitting_out);
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(state.table.contesting_count(), 2);
}

#[test]
fn rejoining_mid_hand_waits_for_the_next_hand() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    step(&mut state, Command::LeaveHand { player_id: pid(0) });
    step(
        &mut state,
        Command::SetSittingOut {
            player_id: pid(0),
            sitting_out: false,
        },
    );
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().status,
        poker_engine::HandStatus::Folded
    );
    act(&mut state, 1, PlayerAction::Fold);
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().status,
        poker_engine::HandStatus::Live
    );
}

#[test]
fn leaving_while_paused_is_refused_and_removal_reports_the_chips() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    step(&mut state, Command::Pause);
    assert_eq!(
        try_step(&mut state, Command::LeaveHand { player_id: pid(0) }),
        Err(PokerError::GamePaused)
    );
    step(&mut state, Command::Resume);
    act(&mut state, 0, PlayerAction::Fold);
    act(&mut state, 1, PlayerAction::Fold);
    let events = step(&mut state, Command::RemovePlayer { player_id: pid(1) });
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::PlayerRemoved { chips, .. } if *chips == chips_990()))
    );
}

fn chips_990() -> poker_engine::Chips {
    chips(990)
}

#[test]
fn two_missed_turns_in_a_row_sit_the_player_out_when_the_hand_ends() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    step(&mut state, Command::Timeout { player_id: pid(0) });
    act(&mut state, 1, PlayerAction::Fold);
    assert_eq!(state.table.seat_of(&pid(0)).unwrap().missed_turns, 1);
    assert!(
        !state.table.seat_of(&pid(0)).unwrap().sitting_out,
        "one miss is forgiven"
    );

    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(state.table.active, Some(seat(1)));
    act(&mut state, 1, raise_to(60));
    act(&mut state, 2, PlayerAction::Call);
    step(&mut state, Command::Timeout { player_id: pid(0) });
    assert!(
        !state.table.seat_of(&pid(0)).unwrap().sitting_out,
        "away only once the hand is over"
    );
    let events = act(&mut state, 2, PlayerAction::Fold);
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::PlayerAway { player_id } if *player_id == pid(0)))
    );
    assert!(state.table.seat_of(&pid(0)).unwrap().sitting_out);

    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().status,
        poker_engine::HandStatus::Out
    );

    step(
        &mut state,
        Command::SetSittingOut {
            player_id: pid(0),
            sitting_out: false,
        },
    );
    assert_eq!(
        state.table.seat_of(&pid(0)).unwrap().missed_turns,
        0,
        "coming back clears the count"
    );
}

#[test]
fn a_real_action_clears_the_missed_turn_count() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    step(&mut state, Command::Timeout { player_id: pid(0) });
    act(&mut state, 1, PlayerAction::Fold);
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    act(&mut state, 1, PlayerAction::Call);
    act(&mut state, 2, PlayerAction::Call);
    act(&mut state, 0, PlayerAction::Check);
    assert_eq!(state.table.seat_of(&pid(0)).unwrap().missed_turns, 0);
}

#[test]
fn table_total_is_capped_so_payouts_can_never_overflow() {
    use poker_engine::{MAX_CHIPS, MAX_TABLE_CHIPS};
    let mut state = lobby(&[1000, 1000], 10, 20);
    // One player has concentrated nearly the whole cap (as if they had won it).
    state.table.seats[0].chips = chips(9 * MAX_CHIPS);
    state.table.seats[1].chips = chips(MAX_CHIPS);
    let add = |index: usize, at: u8, amount: u64| Command::AddPlayer {
        player_id: pid(index),
        seat: seat(at),
        chips: chips(amount),
    };
    assert_eq!(state.table.total_chips(), MAX_TABLE_CHIPS);
    assert_eq!(
        try_step(&mut state, add(5, 5, 1)),
        Err(PokerError::InvalidAmount)
    );

    // Busting one player and letting them rebuy cannot push the table over the cap either.
    state.table.seats[1].chips = chips(0);
    let rebuy = Command::Rebuy {
        player_id: pid(1),
        amount: chips(MAX_CHIPS),
    };
    step(&mut state, rebuy.clone());
    assert_eq!(state.table.total_chips(), MAX_TABLE_CHIPS);
    state.table.seats[1].chips = chips(0);
    state.table.seats[0].chips = chips(9 * MAX_CHIPS + 5);
    assert_eq!(try_step(&mut state, rebuy), Err(PokerError::InvalidAmount));
}
