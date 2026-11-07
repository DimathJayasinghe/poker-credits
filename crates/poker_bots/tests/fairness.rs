//! Fairness: a bot's decision depends only on what its seat can see.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_bots::{Archetype, BotMind, BotRng, Personality, Skill, decide, view_for_seat};
use poker_engine::card::Card;
use poker_engine::{GameState, PlayerId};
use proptest::prelude::*;
use support::{dealt, pid};

/// Replaces every other player's hole cards and the undealt part of the board with other cards
/// that none of the visible cards use. What seat `me` can see does not change.
fn scramble_hidden(state: &GameState, me: &PlayerId, salt: u64) -> GameState {
    let mut next = state.clone();
    let deal = next.table.deal.as_mut().unwrap();
    let shown = usize::from(deal.board_shown);
    let mut used: Vec<Card> = deal.hole_of(me).unwrap().to_vec();
    used.extend_from_slice(&deal.board[..shown]);
    let mut unseen: Vec<Card> = Vec::new();
    for rank in poker_engine::card::Rank::ALL {
        for suit in poker_engine::card::Suit::ALL {
            let c = Card::new(rank, suit);
            if !used.contains(&c) {
                unseen.push(c);
            }
        }
    }
    let mut rng = BotRng::from_seed(salt);
    for end in (1..unseen.len()).rev() {
        let pick = rng.below(u32::try_from(end + 1).unwrap()) as usize;
        unseen.swap(end, pick);
    }
    let mut next_card = unseen.into_iter();
    for (id, hole) in &mut deal.holes {
        if id != me {
            *hole = [next_card.next().unwrap(), next_card.next().unwrap()];
        }
    }
    for slot in shown..deal.board.len() {
        deal.board[slot] = next_card.next().unwrap();
    }
    next
}

fn walk_to(state: &mut GameState, street: poker_engine::Phase) {
    while state.table.phase != street && state.table.phase.is_betting() {
        let active = state.table.active.unwrap();
        let owes = state.table.seat(active).unwrap().street_bet < state.table.current_bet;
        let action = if owes {
            poker_engine::PlayerAction::Call
        } else {
            poker_engine::PlayerAction::Check
        };
        *state = poker_engine::apply(
            state,
            poker_engine::Command::Action {
                player_id: pid(usize::from(active.get())),
                action,
            },
        )
        .unwrap()
        .state;
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(48))]

    /// The decision is identical when the hidden cards change: other players' hole cards and the
    /// unrevealed board are not inputs to it.
    #[test]
    fn bot_view_invariance(
        players in 2usize..=9,
        seed in any::<u64>(),
        salt in any::<u64>(),
        skill in 0u8..3,
        street in 0u8..3,
    ) {
        let mut state = dealt(players, 2000, seed);
        let target = [poker_engine::Phase::PreFlop, poker_engine::Phase::Flop, poker_engine::Phase::Turn][usize::from(street)];
        walk_to(&mut state, target);
        prop_assume!(state.table.phase == target);
        let active = state.table.active.unwrap();
        let me = state.table.seat(active).unwrap().player_id.clone();
        let other = scramble_hidden(&state, &me, salt);

        let skill = [Skill::Easy, Skill::Normal, Skill::Hard][usize::from(skill)];
        let mut setup = BotRng::from_seed(seed);
        let personality = Personality::sample(Archetype::Tag, &mut setup);

        let view_a = view_for_seat(&state.table, active, &[]).unwrap();
        let view_b = view_for_seat(&other.table, active, &[]).unwrap();
        prop_assert_eq!(&view_a, &view_b, "the view itself must not change");

        let mut mind_a = BotMind::new(personality, skill);
        let mut mind_b = BotMind::new(personality, skill);
        // No time limit, so both runs take exactly the same samples.
        mind_a.equity_budget = None;
        mind_b.equity_budget = None;
        let a = decide(&view_a, &mut mind_a, &mut BotRng::from_seed(seed ^ 0xABCD));
        let b = decide(&view_b, &mut mind_b, &mut BotRng::from_seed(seed ^ 0xABCD));
        prop_assert_eq!(a, b);
    }
}

#[test]
fn identical_bots_decide_identically_from_identical_views() {
    let state = dealt(5, 1000, 31);
    let active = state.table.active.unwrap();
    let view = view_for_seat(&state.table, active, &[]).unwrap();
    let p = Personality::sample(Archetype::Lag, &mut BotRng::from_seed(1));
    let mut mind = BotMind::new(p, Skill::Hard);
    mind.equity_budget = None;
    let a = decide(&view, &mut mind.clone(), &mut BotRng::from_seed(9));
    let b = decide(&view, &mut mind, &mut BotRng::from_seed(9));
    assert_eq!(a, b);
}

#[test]
fn the_scramble_really_changes_the_hidden_cards() {
    // Guards the test above: it must actually alter what it claims to alter.
    let state = dealt(4, 1000, 5);
    let active = state.table.active.unwrap();
    let me = state.table.seat(active).unwrap().player_id.clone();
    let other = scramble_hidden(&state, &me, 99);
    let (a, b) = (
        state.table.deal.as_ref().unwrap(),
        other.table.deal.as_ref().unwrap(),
    );
    assert_eq!(a.hole_of(&me), b.hole_of(&me));
    let changed = a
        .holes
        .iter()
        .zip(&b.holes)
        .filter(|((id, x), (_, y))| *id != me && x != y)
        .count();
    assert!(changed >= 1, "other hands should differ");
    assert_ne!(a.board, b.board);
}
