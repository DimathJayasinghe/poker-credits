//! Range-weighted equity: what a player's betting says about the hands they hold.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_bots::equity::equity_against;
use poker_bots::range::RangeProfile;
use poker_bots::strength::top_fraction_threshold;
use poker_bots::{BotRng, equity::equity};
use support::cards;

fn hole(text: &str) -> [poker_engine::card::Card; 2] {
    let c = cards(text);
    [c[0], c[1]]
}

fn raised_preflop(top: f32) -> RangeProfile {
    RangeProfile {
        pre_min: top_fraction_threshold(top),
        ..RangeProfile::ANY
    }
}

fn bettor(streets: u8, bluff: f32) -> RangeProfile {
    RangeProfile {
        aggressive_streets: streets,
        bluff,
        ..RangeProfile::ANY
    }
}

fn eq(h: &str, board: &str, ranges: &[RangeProfile]) -> f32 {
    let mut rng = BotRng::from_seed(7);
    equity_against(hole(h), &cards(board), ranges, 3000, &mut rng, None)
}

#[test]
fn no_range_is_the_old_uniform_equity() {
    let mut rng = BotRng::from_seed(7);
    let uniform = equity(hole("Kd Tc"), &cards("Ks 7d 2c"), 1, 3000, &mut rng, None);
    let any = eq("Kd Tc", "Ks 7d 2c", &[RangeProfile::ANY]);
    assert!((uniform - any).abs() < 0.03, "{uniform} vs {any}");
}

#[test]
fn a_preflop_raiser_holds_better_cards_than_a_random_hand() {
    let any = eq("Kd Tc", "Ks 7d 2c", &[RangeProfile::ANY]);
    let tight = eq("Kd Tc", "Ks 7d 2c", &[raised_preflop(0.08)]);
    assert!(tight < any - 0.10, "any {any} vs raiser {tight}");
}

#[test]
fn a_hand_that_keeps_betting_has_fewer_bluffs_in_it() {
    // Second pair: a bluff-catcher that beats air and loses to any better pair.
    let any = eq("7h 6c", "Ks 7d 2c 4h", &[RangeProfile::ANY]);
    let nit = eq("7h 6c", "Ks 7d 2c 4h", &[bettor(2, 0.05)]);
    let maniac = eq("7h 6c", "Ks 7d 2c 4h", &[bettor(2, 0.6)]);
    eprintln!("any {any} nit {nit} maniac {maniac}");
    assert!(nit < any - 0.15, "any {any} vs two-street bettor {nit}");
    assert!(
        maniac > nit + 0.10,
        "a bettor who bluffs ({maniac}) is easier to beat than one who does not ({nit})"
    );
}

#[test]
fn calling_a_bet_means_a_hand_with_some_showdown_value() {
    let any = eq("Ad 4h", "Ks 7d 2c", &[RangeProfile::ANY]);
    let caller = eq(
        "Ad 4h",
        "Ks 7d 2c",
        &[RangeProfile {
            called_bets: 1,
            ..RangeProfile::ANY
        }],
    );
    assert!(caller < any, "any {any} vs caller {caller}");
}

#[test]
fn the_answer_is_repeatable_and_always_a_probability() {
    let ranges = [raised_preflop(0.10), bettor(1, 0.3), RangeProfile::ANY];
    let a = eq("Qh Qd", "Jc 8d 2s", &ranges);
    let b = eq("Qh Qd", "Jc 8d 2s", &ranges);
    assert!((a - b).abs() < f32::EPSILON);
    assert!((0.0..=1.0).contains(&a));
    // A range nobody holds still gives an answer (the sampler gives up gracefully).
    let impossible = RangeProfile {
        pre_min: 2.0,
        aggressive_streets: 3,
        bluff: 0.0,
        ..RangeProfile::ANY
    };
    let c = eq("Qh Qd", "Jc 8d 2s", &[impossible]);
    assert!((0.0..=1.0).contains(&c), "{c}");
}

#[test]
fn the_weights_themselves() {
    let aces = hole("Ah Ad");
    let trash = hole("7c 2d");
    let tight = raised_preflop(0.05);
    assert!((tight.weight(aces, &[]) - 1.0).abs() < f32::EPSILON);
    assert!(tight.weight(trash, &[]) < 0.05);
    assert!((RangeProfile::ANY.weight(trash, &[]) - 1.0).abs() < f32::EPSILON);
}
