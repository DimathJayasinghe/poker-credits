//! Legal actions, minimum raise and the short all-in rule.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::validator::resolve;
use poker_engine::{ActionKind, PlayerAction, PokerError};
use support::{act, chips, dealt, pid, raise_to, try_act};

#[test]
fn utg_faces_the_big_blind() {
    let state = dealt(&[1000, 1000, 1000], 10, 20);
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 0);
    assert!(legal.can_fold && !legal.can_check && legal.can_call);
    assert_eq!(legal.call_amount, chips(20));
    assert!(legal.can_raise);
    assert_eq!(legal.min_raise_to, chips(40));
    assert_eq!(legal.max_raise_to, chips(1000));
}

#[test]
fn big_blind_may_check_its_option() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 2);
    assert!(legal.can_check && !legal.can_call);
    assert!(legal.can_raise);
    assert_eq!(legal.min_raise_to, chips(40));
}

#[test]
fn check_while_facing_a_bet_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_act(&mut state, 0, PlayerAction::Check),
        Err(PokerError::CannotCheck)
    );
}

#[test]
fn call_with_nothing_to_call_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    assert_eq!(
        try_act(&mut state, 2, PlayerAction::Call),
        Err(PokerError::NothingToCall)
    );
}

#[test]
fn min_raise_example_from_the_rules_doc() {
    // Big blind 20, raise to 60 (delta 40): the re-raise must be to at least 100.
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, raise_to(60));
    assert_eq!(
        try_act(&mut state, 1, raise_to(99)),
        Err(PokerError::BelowMinRaise {
            min_raise_to: chips(100)
        })
    );
    act(&mut state, 1, raise_to(100));
}

#[test]
fn raise_below_the_big_blind_increment_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_act(&mut state, 0, raise_to(30)),
        Err(PokerError::BelowMinRaise {
            min_raise_to: chips(40)
        })
    );
}

#[test]
fn raise_above_the_stack_is_rejected() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    assert_eq!(
        try_act(&mut state, 0, raise_to(1001)),
        Err(PokerError::InsufficientFunds {
            max_to: chips(1000)
        })
    );
}

#[test]
fn short_stack_can_only_call_all_in() {
    let state = dealt(&[15, 1000, 1000], 10, 20);
    let (_, legal) = state.legal_actions().unwrap();
    assert_eq!(legal.call_amount, chips(15));
    assert!(!legal.can_raise);
    assert_eq!(legal.min_raise_to, chips(0));
}

#[test]
fn all_in_below_the_min_raise_is_legal_but_not_a_full_raise() {
    let state = dealt(&[30, 1000, 1000], 10, 20);
    let table = &state.table;
    let seat = table.seat_of(&pid(0)).unwrap();
    let resolved = resolve(table, seat, PlayerAction::AllIn).unwrap();
    assert_eq!(resolved.kind, ActionKind::Raise);
    assert_eq!(resolved.new_street_bet, chips(30));
    assert!(resolved.all_in);
    assert!(
        !resolved.full_raise,
        "30 is less than the minimum raise to 40"
    );
}

#[test]
fn all_in_at_or_above_the_min_raise_is_a_full_raise() {
    let state = dealt(&[40, 1000, 1000], 10, 20);
    let table = &state.table;
    let seat = table.seat_of(&pid(0)).unwrap();
    assert!(
        resolve(table, seat, PlayerAction::AllIn)
            .unwrap()
            .full_raise
    );
}

#[test]
fn short_all_in_does_not_reopen_betting_for_players_who_acted() {
    let mut state = dealt(&[1000, 1000, 130], 10, 20);
    act(&mut state, 0, raise_to(100));
    act(&mut state, 1, PlayerAction::Call);
    act(&mut state, 2, PlayerAction::AllIn); // 130 total: only 30 over the bet, less than the 80 increment.

    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 0);
    assert!(
        !legal.can_raise,
        "p0 already acted and the all-in was not a full raise"
    );
    assert_eq!(legal.call_amount, chips(30));
    assert_eq!(
        try_act(&mut state, 0, raise_to(400)),
        Err(PokerError::BettingNotReopened)
    );
    assert_eq!(
        try_act(&mut state, 0, PlayerAction::AllIn),
        Err(PokerError::BettingNotReopened)
    );
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    assert_eq!(state.table.phase, poker_engine::Phase::Flop);
}

#[test]
fn full_raise_reopens_betting() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, raise_to(60));
    act(&mut state, 1, raise_to(100));
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 2);
    assert!(legal.can_raise);
    act(&mut state, 2, PlayerAction::Fold);
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 0);
    assert!(legal.can_raise, "p0 faces a full raise and may re-raise");
    assert_eq!(legal.min_raise_to, chips(140));
}

#[test]
fn a_player_who_has_not_acted_may_raise_over_a_short_all_in() {
    // p0 (UTG) has not acted when p1 and p2 are forced in short.
    let mut state = dealt(&[1000, 30, 25], 10, 20);
    // SB p1 posted 10, BB p2 posted 20; p0 is first to act and may raise freely.
    let (_, legal) = state.legal_actions().unwrap();
    assert!(legal.can_raise);
    act(&mut state, 0, raise_to(200));
}

#[test]
fn opening_bet_after_the_flop_must_reach_the_big_blind() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    act(&mut state, 2, PlayerAction::Check);
    assert_eq!(
        try_act(&mut state, 1, raise_to(10)),
        Err(PokerError::BelowMinRaise {
            min_raise_to: chips(20)
        })
    );
    act(&mut state, 1, raise_to(20));
}

#[test]
fn bet_and_raise_are_labelled_differently() {
    let mut state = dealt(&[1000, 1000, 1000], 10, 20);
    act(&mut state, 0, PlayerAction::Call);
    act(&mut state, 1, PlayerAction::Call);
    act(&mut state, 2, PlayerAction::Check);
    let events = act(&mut state, 1, raise_to(50));
    assert!(events.iter().any(|e| matches!(
        e,
        poker_engine::Event::ActionPerformed {
            action: ActionKind::Bet,
            ..
        }
    )));
    let events = act(&mut state, 2, raise_to(150));
    assert!(events.iter().any(|e| matches!(
        e,
        poker_engine::Event::ActionPerformed {
            action: ActionKind::Raise,
            ..
        }
    )));
}

/// Table with five players: p3 (UTG) opens, then two short all-ins; p1/p2 fold behind.
fn after_two_short_all_ins(short_stacks: (u64, u64)) -> poker_engine::GameState {
    let mut state = dealt(&[short_stacks.1, 1000, 1000, 1000, short_stacks.0], 10, 20);
    act(&mut state, 3, raise_to(100)); // full raise, increment 80
    act(&mut state, 4, PlayerAction::AllIn);
    act(&mut state, 0, PlayerAction::AllIn);
    act(&mut state, 1, PlayerAction::Fold);
    act(&mut state, 2, PlayerAction::Fold);
    state
}

#[test]
fn short_all_ins_that_add_up_to_a_full_raise_reopen_betting() {
    // +50 then +40 over the bet of 100 is 90, more than the 80 increment (TDA rule 47).
    let state = after_two_short_all_ins((150, 190));
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 3);
    assert!(
        legal.can_raise,
        "the opener faces a cumulative full raise and may re-raise"
    );
    assert_eq!(legal.call_amount, chips(90));
    assert_eq!(
        legal.min_raise_to,
        chips(270),
        "the increment stays 80, not 90"
    );
}

#[test]
fn short_all_ins_that_fall_short_together_do_not_reopen() {
    // +50 then +20 is 70, less than 80.
    let state = after_two_short_all_ins((150, 170));
    let (seat_index, legal) = state.legal_actions().unwrap();
    assert_eq!(seat_index.get(), 3);
    assert!(!legal.can_raise);
    assert_eq!(legal.call_amount, chips(70));
}

#[test]
fn a_full_raise_clears_the_short_all_in_tally() {
    let mut state = dealt(&[1000, 1000, 1000, 1000, 130], 10, 20);
    act(&mut state, 3, raise_to(100));
    act(&mut state, 4, PlayerAction::AllIn); // +30 short
    act(&mut state, 0, raise_to(210)); // full raise (+80), tally restarts
    assert_eq!(state.table.short_raise_total, chips(0));
    assert_eq!(state.table.last_raise_delta, chips(80));
}
