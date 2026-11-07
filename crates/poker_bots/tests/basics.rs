//! View, RNG, strength and equity.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_bots::equity::equity;
use poker_bots::strength::{preflop_adjust, preflop_strength};
use poker_bots::{BotRng, view_for_seat};
use proptest::prelude::*;
use std::time::Duration;
use support::{cards, dealt, seat};

fn hole(text: &str) -> [poker_engine::card::Card; 2] {
    let c = cards(text);
    [c[0], c[1]]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    /// Every seat's view holds its own two cards and none of the others'.
    #[test]
    fn view_has_no_foreign_cards(players in 2usize..=9, seed in any::<u64>()) {
        let state = dealt(players, 1000, seed);
        let deal = state.table.deal.as_ref().unwrap();
        for s in &state.table.seats {
            let view = view_for_seat(&state.table, s.index, &[]).unwrap();
            prop_assert_eq!(view.hole, deal.hole_of(&s.player_id).unwrap());
            for (other, cards) in &deal.holes {
                if *other == s.player_id { continue; }
                for c in cards {
                    prop_assert!(!view.board.contains(c));
                    prop_assert!(view.hole[0] != *c && view.hole[1] != *c);
                }
            }
            // Nothing beyond the shown board (preflop: empty) is visible.
            prop_assert!(view.board.len() <= usize::from(deal.board_shown));
        }
    }
}

#[test]
fn view_for_seat_none_without_cards_or_seat() {
    let state = support::dealt(3, 1000, 1);
    assert!(view_for_seat(&state.table, seat(9), &[]).is_none());
    let lobby = poker_engine::GameState::new(support::blinds_mode(10, 20)).unwrap();
    assert!(view_for_seat(&lobby.table, seat(0), &[]).is_none());
}

#[test]
fn view_reports_what_the_seat_owes() {
    let state = dealt(3, 1000, 7);
    let acting = state.table.active.unwrap();
    let view = view_for_seat(&state.table, acting, &[]).unwrap();
    assert!(
        view.to_call.get() > 0,
        "first to act preflop owes the big blind"
    );
    assert!(view.legal.can_call);
    assert_eq!(view.pot_total, state.table.total_pot());
}

#[test]
fn rng_same_seed_same_stream() {
    let (mut a, mut b) = (BotRng::from_seed(42), BotRng::from_seed(42));
    for _ in 0..50 {
        assert_eq!(a.next_u64(), b.next_u64());
    }
    assert_ne!(
        BotRng::from_seed(1).next_u64(),
        BotRng::from_seed(2).next_u64()
    );
}

#[test]
fn rng_below_is_uniform() {
    let mut rng = BotRng::from_seed(99);
    let mut counts = [0_u32; 7];
    let draws = 70_000;
    for _ in 0..draws {
        counts[rng.below(7) as usize] += 1;
    }
    let expected = f64::from(draws) / 7.0;
    let chi: f64 = counts
        .iter()
        .map(|c| (f64::from(*c) - expected).powi(2) / expected)
        .sum();
    // 6 degrees of freedom: 22.5 is the 0.1% point.
    assert!(chi < 22.5, "chi-square {chi} for {counts:?}");
    assert_eq!(rng.below(0), 0);
    assert_eq!(rng.below(1), 0);
}

#[test]
fn rng_unit_and_chance_stay_in_range() {
    let mut rng = BotRng::from_seed(5);
    for _ in 0..1000 {
        let u = rng.unit();
        assert!((0.0..1.0).contains(&u));
    }
    assert!(!rng.chance(0.0));
    assert!(rng.chance(1.0));
    assert!(rng.chance(7.0), "probabilities clamp");
}

#[test]
fn preflop_table_orders_hands() {
    let s = |t: &str| preflop_strength(hole(t));
    assert!(s("As Ah") > s("Ks Kh"));
    assert!(s("Ks Kh") > s("As Ks"));
    assert!(s("As Ks") > s("As Kd"), "suited beats offsuit");
    assert!(s("As Kd") > s("7c 2d"));
    assert!(s("7c 2d") < 0.1);
    assert!((s("As Ah") - 1.0).abs() < 0.01);
    assert!(s("Ts Td") > s("9s 8s"));
    assert!(s("9s 8s") > s("9s 3d"));
    assert!(
        (s("Ks Qd") - s("Qd Ks")).abs() < f32::EPSILON,
        "card order does not matter"
    );
}

#[test]
fn preflop_adjust_prefers_late_position_and_few_opponents() {
    let base = 0.5;
    assert!(preflop_adjust(base, 1.0, 2) > preflop_adjust(base, 0.0, 2));
    assert!(preflop_adjust(base, 0.5, 1) > preflop_adjust(base, 0.5, 8));
    assert!(preflop_adjust(1.0, 1.0, 1) <= 1.0 && preflop_adjust(0.0, 0.0, 9) >= 0.0);
}

#[test]
fn equity_known_cases() {
    let mut rng = BotRng::from_seed(11);
    let aces = equity(hole("As Ah"), &[], 1, 4000, &mut rng, None);
    assert!((0.82..=0.88).contains(&aces), "AA vs one hand: {aces}");
    let nuts = equity(
        hole("Ah Kh"),
        &cards("Qh Jh Th 2c 3d"),
        3,
        600,
        &mut rng,
        None,
    );
    assert!(nuts >= 0.97, "royal flush: {nuts}");
    let trash = equity(hole("7c 2d"), &cards("As Ah Kd"), 4, 600, &mut rng, None);
    assert!(trash < 0.25, "air on an ace-high board vs four: {trash}");
    assert!((equity(hole("As Ah"), &[], 0, 10, &mut rng, None) - 1.0).abs() < f32::EPSILON);
    assert!((equity(hole("As Ah"), &[], 2, 0, &mut rng, None) - 0.5).abs() < f32::EPSILON);
}

#[test]
fn equity_depends_only_on_what_the_seat_can_see() {
    // The function takes my cards and the board; it has no parameter through which the real
    // opponents' cards or the deck could enter, so the same seed gives the same answer.
    let a = equity(
        hole("Ks Qs"),
        &cards("2c 9d Jh"),
        3,
        300,
        &mut BotRng::from_seed(3),
        None,
    );
    let b = equity(
        hole("Ks Qs"),
        &cards("2c 9d Jh"),
        3,
        300,
        &mut BotRng::from_seed(3),
        None,
    );
    assert!((a - b).abs() < f32::EPSILON);
}

#[test]
fn equity_respects_budget() {
    let mut rng = BotRng::from_seed(1);
    let started = std::time::Instant::now();
    let _ = equity(
        hole("As Kd"),
        &[],
        8,
        5_000_000,
        &mut rng,
        Some(Duration::from_millis(5)),
    );
    assert!(
        started.elapsed() < Duration::from_millis(500),
        "stopped early: {:?}",
        started.elapsed()
    );
}
