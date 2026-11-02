//! Button and blind positions: rotation, dead button, dead small blind, heads-up.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::button::next_positions;
use poker_engine::{Command, PokerError, SeatIndex};
use support::{chips, lobby, pid, seat, step};

fn positions(state: &poker_engine::GameState) -> (u8, Option<u8>, u8) {
    let p = next_positions(&state.table).unwrap();
    (
        p.dealer.get(),
        p.small_blind.map(SeatIndex::get),
        p.big_blind.get(),
    )
}

#[test]
fn first_hand_three_players() {
    let state = lobby(&[1000, 1000, 1000], 10, 20);
    assert_eq!(positions(&state), (0, Some(1), 2));
}

#[test]
fn first_hand_uses_occupied_seats_only() {
    let mut state = poker_engine::GameState::new(support::cash(10, 20, 0)).unwrap();
    for (index, at) in [(0, 0_u8), (1, 4), (2, 7)] {
        step(
            &mut state,
            Command::AddPlayer {
                player_id: pid(index),
                seat: seat(at),
                chips: chips(1000),
            },
        );
    }
    assert_eq!(positions(&state), (0, Some(4), 7));
}

#[test]
fn the_button_and_blinds_move_one_seat_each_hand() {
    let mut state = lobby(&[1000, 1000, 1000], 10, 20);
    let mut seen = Vec::new();
    for _ in 0..4 {
        step(&mut state, Command::StartHand { elapsed_ms: 0 });
        seen.push((
            state.table.dealer.unwrap().get(),
            state.table.small_blind_seat.map(SeatIndex::get),
            state.table.big_blind_seat.unwrap().get(),
        ));
        // everyone folds to end the hand
        while state.table.phase.is_betting() {
            let (active, _) = state.legal_actions().unwrap();
            let id = state.table.seat(active).unwrap().player_id.clone();
            step(
                &mut state,
                Command::Action {
                    player_id: id,
                    action: poker_engine::PlayerAction::Fold,
                },
            );
        }
    }
    assert_eq!(
        seen,
        vec![
            (0, Some(1), 2),
            (1, Some(2), 0),
            (2, Some(0), 1),
            (0, Some(1), 2)
        ]
    );
}

#[test]
fn busted_small_blind_seat_leaves_the_small_blind_dead() {
    let mut state = lobby(&[1000, 1000, 1000, 1000], 10, 20);
    state.table.big_blind_seat = Some(seat(1));
    state.table.seat_mut(seat(1)).unwrap().chips = chips(0);
    // Big blind moves to seat 2; the seat before it (1) is busted, so nobody posts the small blind.
    assert_eq!(positions(&state), (0, None, 2));
}

#[test]
fn busted_button_seat_leaves_a_dead_button() {
    let mut state = lobby(&[1000, 1000, 1000, 1000], 10, 20);
    state.table.big_blind_seat = Some(seat(2));
    state.table.seat_mut(seat(1)).unwrap().chips = chips(0);
    // Big blind seat 3, small blind seat 2, button on the empty-handed seat 1.
    assert_eq!(positions(&state), (1, Some(2), 3));
}

#[test]
fn three_players_down_to_two_goes_heads_up_with_the_button_on_the_small_blind() {
    let mut state = lobby(&[1000, 1000, 1000], 10, 20);
    state.table.big_blind_seat = Some(seat(1));
    state.table.seat_mut(seat(2)).unwrap().chips = chips(0);
    // Big blind rotates to seat 0; the other player (seat 1) is small blind and button.
    assert_eq!(positions(&state), (1, Some(1), 0));
}

#[test]
fn heads_up_blinds_alternate() {
    let mut state = lobby(&[1000, 1000], 10, 20);
    assert_eq!(positions(&state), (0, Some(0), 1));
    state.table.big_blind_seat = Some(seat(1));
    assert_eq!(positions(&state), (1, Some(1), 0));
    state.table.big_blind_seat = Some(seat(0));
    assert_eq!(positions(&state), (0, Some(0), 1));
}

#[test]
fn sitting_out_players_are_skipped() {
    let mut state = lobby(&[1000, 1000, 1000, 1000], 10, 20);
    state.table.seat_mut(seat(1)).unwrap().sitting_out = true;
    assert_eq!(positions(&state), (0, Some(2), 3));
}

#[test]
fn fewer_than_two_eligible_players_is_an_error() {
    let mut state = lobby(&[1000, 1000], 10, 20);
    state.table.seat_mut(seat(1)).unwrap().chips = chips(0);
    assert_eq!(
        next_positions(&state.table),
        Err(PokerError::NotEnoughPlayers)
    );
    assert_eq!(
        next_positions(&lobby(&[], 10, 20).table),
        Err(PokerError::NotEnoughPlayers)
    );
}

#[test]
fn big_blind_never_skips_a_player_across_many_hands() {
    let mut state = lobby(&[1000, 1000, 1000, 1000, 1000], 10, 20);
    let mut big_blinds = Vec::new();
    for _ in 0..10 {
        step(&mut state, Command::StartHand { elapsed_ms: 0 });
        big_blinds.push(state.table.big_blind_seat.unwrap().get());
        while state.table.phase.is_betting() {
            let (active, _) = state.legal_actions().unwrap();
            let id = state.table.seat(active).unwrap().player_id.clone();
            step(
                &mut state,
                Command::Action {
                    player_id: id,
                    action: poker_engine::PlayerAction::Fold,
                },
            );
        }
    }
    assert_eq!(big_blinds, vec![2, 3, 4, 0, 1, 2, 3, 4, 0, 1]);
}
