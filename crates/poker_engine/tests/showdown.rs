//! Winners from hand ranks: ties, side pots, short stacks and acceptance by the engine.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::card::Card;
use poker_engine::deck::Deck;
use poker_engine::hand_rank::HandCategory;
use poker_engine::showdown::{allocations, reveals};
use poker_engine::{Command, GameState, PlayerAction, PlayerId, PokerError};
use proptest::prelude::*;
use support::{lobby, pid, step};

fn parse(text: &str) -> Vec<Card> {
    text.split_whitespace()
        .map(|c| c.parse().unwrap())
        .collect()
}

/// A table where `holes[i]` belongs to player `p{i}` and `board` is the five-card board.
fn rigged(stacks: &[u64], holes: &[&str], board: &str) -> GameState {
    let start = lobby(stacks, 1, 2);
    let probe = poker_engine::apply(
        &start,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(Deck::standard()),
        },
    )
    .unwrap()
    .state;
    let order: Vec<PlayerId> = probe
        .table
        .deal
        .as_ref()
        .unwrap()
        .holes
        .iter()
        .map(|(id, _)| id.clone())
        .collect();
    let mut cards = Vec::new();
    for id in &order {
        let index = (0..holes.len()).find(|i| pid(*i) == *id).unwrap();
        cards.extend(parse(holes[index]));
    }
    cards.extend(parse(board));
    for card in Deck::standard().cards() {
        if !cards.contains(card) {
            cards.push(*card);
        }
    }
    let mut state = start;
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(Deck::new(cards).unwrap()),
        },
    );
    state
}

fn run_to_showdown(state: &mut GameState) {
    while state.table.active.is_some() {
        let seat = state.table.active.unwrap();
        let player_id = state.table.seat(seat).unwrap().player_id.clone();
        step(
            state,
            Command::Action {
                player_id,
                action: PlayerAction::AllIn,
            },
        );
    }
    step(state, Command::BeginShowdown);
}

const BOARD: &str = "2c 7d 9h Jc 3s";

#[test]
fn best_hand_wins_the_main_pot() {
    let mut state = rigged(&[100, 100, 100], &["Ah Ad", "Kh Kd", "Qh Qd"], BOARD);
    run_to_showdown(&mut state);
    let result = allocations(&state.table).unwrap();
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].winners, vec![pid(0)]);
    let shown = reveals(&state.table);
    assert_eq!(shown.len(), 3);
    assert!(shown.iter().all(|r| r.category == HandCategory::Pair));
    let top = shown.iter().find(|r| r.player_id == pid(0)).unwrap();
    assert_eq!(top.cards.to_vec(), parse("Ah Ad"));
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: result,
        },
    );
    assert_eq!(support::stack(&state, 0), 300);
}

#[test]
fn tie_splits_and_odd_chip_goes_clockwise_from_the_button() {
    let mut state = rigged(
        &[33, 33, 33],
        &["3c 4c", "Ac Kc", "Ad Kd"],
        "2s 2h 7s 9h Jd",
    );
    run_to_showdown(&mut state);
    let result = allocations(&state.table).unwrap();
    assert_eq!(result[0].winners, vec![pid(1), pid(2)]);
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: result,
        },
    );
    let (a, b) = (support::stack(&state, 1), support::stack(&state, 2));
    assert_eq!(a + b, 99);
    assert_eq!(a.abs_diff(b), 1);
    assert_eq!(support::stack(&state, 0), 0);
}

#[test]
fn side_pot_can_have_a_different_winner_than_the_main_pot() {
    let mut state = rigged(&[50, 100, 100], &["Ah Ad", "Kh Kd", "Qh Qd"], BOARD);
    run_to_showdown(&mut state);
    let result = allocations(&state.table).unwrap();
    assert_eq!(result.len(), 2);
    assert_eq!(result[0].winners, vec![pid(0)], "main pot");
    assert_eq!(result[1].winners, vec![pid(1)], "side pot");
    step(
        &mut state,
        Command::ResolveShowdown {
            allocations: result,
        },
    );
    assert_eq!(support::stack(&state, 0), 150);
    assert_eq!(support::stack(&state, 1), 100);
}

#[test]
fn short_stack_wins_only_the_pot_it_is_eligible_for() {
    let mut state = rigged(&[50, 100, 100], &["Ah Ad", "Kh Kd", "Qh Qd"], BOARD);
    run_to_showdown(&mut state);
    let result = allocations(&state.table).unwrap();
    assert!(!result[1].winners.contains(&pid(0)));
}

#[test]
fn three_way_tie_on_board() {
    let mut state = rigged(
        &[100, 100, 100],
        &["2c 3d", "4c 5d", "6c 8d"],
        "As Ks Qs Js Ts",
    );
    run_to_showdown(&mut state);
    let result = allocations(&state.table).unwrap();
    assert_eq!(result[0].winners, vec![pid(0), pid(1), pid(2)]);
}

#[test]
fn errors_when_there_is_no_deal() {
    let state = support::dealt(&[1000, 1000], 1, 2);
    assert_eq!(
        allocations(&state.table),
        Err(PokerError::HandNotInProgress)
    );
    assert!(reveals(&state.table).is_empty());
}

proptest! {
    #[test]
    fn allocations_are_accepted_by_resolve_showdown_for_random_virtual_hands(
        deck in Just(Deck::standard().cards().to_vec()).prop_shuffle(),
        stacks in prop::collection::vec(10_u64..500, 2..=6),
    ) {
        let mut state = lobby(&stacks, 1, 2);
        let total: u64 = stacks.iter().sum();
        step(&mut state, Command::StartHand { elapsed_ms: 0, deck: Some(Deck::new(deck).unwrap()) });
        run_to_showdown(&mut state);
        let result = allocations(&state.table).unwrap();
        step(&mut state, Command::ResolveShowdown { allocations: result });
        let after: u64 = (0..stacks.len()).map(|i| support::stack(&state, i)).sum();
        prop_assert_eq!(after, total);
    }
}
