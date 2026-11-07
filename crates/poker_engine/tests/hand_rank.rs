//! Hand ranking: category counts, kickers, wheel, ties and the best five of seven.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_engine::PokerError;
use poker_engine::card::{Card, Suit};
use poker_engine::deck::Deck;
use poker_engine::hand_rank::{HandCategory, HandRank, best_of, rank_five};
use proptest::prelude::*;

fn cards(text: &str) -> Vec<Card> {
    text.split_whitespace()
        .map(|c| c.parse().unwrap())
        .collect()
}

fn rank(text: &str) -> HandRank {
    best_of(&cards(text)).unwrap()
}

#[test]
fn five_card_category_counts_match_the_known_table() {
    let deck = Deck::standard();
    let all = deck.cards();
    let mut counts = [0_u64; 9];
    for a in 0..48 {
        for b in (a + 1)..49 {
            for c in (b + 1)..50 {
                for d in (c + 1)..51 {
                    for e in (d + 1)..52 {
                        let five = [all[a], all[b], all[c], all[d], all[e]];
                        counts[rank_five(&five).category() as usize] += 1;
                    }
                }
            }
        }
    }
    // high card, pair, two pair, trips, straight, flush, full house, quads, straight flush
    assert_eq!(
        counts,
        [
            1_302_540, 1_098_240, 123_552, 54_912, 10_200, 5_108, 3_744, 624, 40
        ]
    );
}

#[test]
fn wheel_is_the_lowest_straight_and_loses_to_six_high() {
    let wheel = rank("As 2d 3c 4h 5s");
    let six_high = rank("2d 3c 4h 5s 6d");
    assert_eq!(wheel.category(), HandCategory::Straight);
    assert!(wheel < six_high);
    assert!(wheel > rank("As Ad Kc Kh 2s"), "a straight beats two pair");
}

#[test]
fn steel_wheel_is_a_straight_flush() {
    let steel = rank("As 2s 3s 4s 5s");
    assert_eq!(steel.category(), HandCategory::StraightFlush);
    assert!(steel < rank("2s 3s 4s 5s 6s"));
}

#[test]
fn royal_flush_beats_king_high_straight_flush() {
    assert!(rank("As Ks Qs Js Ts") > rank("Ks Qs Js Ts 9s"));
}

#[test]
fn kicker_decides_pair_vs_pair() {
    assert!(rank("Ks Kd As 7c 3d") > rank("Kh Kc Qs 7d 3c"));
    assert_eq!(rank("Ks Kd As 7c 3d"), rank("Kh Kc Ad 7d 3c"));
}

#[test]
fn category_ordering_is_the_poker_order() {
    let ladder = [
        "As Kd 9c 7h 3s",
        "As Ad 9c 7h 3s",
        "As Ad 9c 9h 3s",
        "As Ad Ac 7h 3s",
        "5s 6d 7c 8h 9s",
        "As Ks 9s 7s 3s",
        "As Ad Ac 7h 7s",
        "As Ad Ac Ah 3s",
        "5s 6s 7s 8s 9s",
    ];
    let ranks: Vec<_> = ladder.iter().map(|h| rank(h)).collect();
    for pair in ranks.windows(2) {
        assert!(pair[0] < pair[1]);
    }
}

#[test]
fn board_plays_gives_equal_ranks() {
    let board = "As Ks Qs Js Ts";
    assert_eq!(
        rank(&format!("{board} 2d 3c")),
        rank(&format!("{board} 4d 5c"))
    );
}

#[test]
fn suits_never_break_ties() {
    assert_eq!(rank("Ks Kd Ac 7c 3d"), rank("Kh Kc Ad 7d 3s"));
}

#[test]
fn two_pair_compares_high_pair_then_low_pair_then_kicker() {
    assert!(rank("As Ad 3c 3h 2s") > rank("Ks Kd Qc Qh As"));
    assert!(rank("As Ad Kc Kh 2s") > rank("As Ad Qc Qh Ks"));
    assert!(rank("As Ad Kc Kh Qs") > rank("As Ad Kc Kh 2s"));
}

#[test]
fn full_house_compares_trips_first() {
    assert!(rank("3s 3d 3c 2h 2s") > rank("2s 2d 2c Ah As"));
}

#[test]
fn seven_cards_pick_the_best_five() {
    let best = rank("As Ad Ac Kd Kh 2c 3s");
    assert_eq!(best.category(), HandCategory::FullHouse);
    assert_eq!(best.best_five().len(), 5);
    let low_straight_in_seven = rank("As 2d 3c 4h 5s Kd Kh");
    assert_eq!(low_straight_in_seven.category(), HandCategory::Straight);
}

#[test]
fn rejects_fewer_than_five_more_than_seven_and_duplicates() {
    assert_eq!(best_of(&cards("As Kd Qc Jh")), Err(PokerError::InvalidHand));
    assert_eq!(
        best_of(&cards("As Kd Qc Jh Ts 9s 8s 7s")),
        Err(PokerError::InvalidHand)
    );
    assert_eq!(
        best_of(&cards("As As Qc Jh Ts")),
        Err(PokerError::InvalidHand)
    );
}

fn seven_cards() -> impl Strategy<Value = Vec<Card>> {
    Just(Deck::standard().cards().to_vec())
        .prop_shuffle()
        .prop_map(|deck| deck.into_iter().take(7).collect())
}

proptest! {
    #[test]
    fn best_five_is_a_subset_of_the_input(hand in seven_cards()) {
        let best = best_of(&hand).unwrap();
        for card in best.best_five() {
            prop_assert!(hand.contains(&card));
        }
        let mut five = best.best_five().to_vec();
        five.sort_unstable();
        five.dedup();
        prop_assert_eq!(five.len(), 5);
        prop_assert_eq!(rank_five(&best.best_five()), best);
    }

    #[test]
    fn seven_card_best_equals_max_over_all_21_subsets(hand in seven_cards()) {
        let mut max = None;
        for skip_a in 0..7 {
            for skip_b in (skip_a + 1)..7 {
                let five: Vec<Card> = hand
                    .iter()
                    .enumerate()
                    .filter(|(i, _)| *i != skip_a && *i != skip_b)
                    .map(|(_, c)| *c)
                    .collect();
                let ranked = rank_five(&[five[0], five[1], five[2], five[3], five[4]]);
                max = Some(max.map_or(ranked, |m: HandRank| m.max(ranked)));
            }
        }
        prop_assert_eq!(best_of(&hand).unwrap(), max.unwrap());
    }

    #[test]
    fn suit_permutation_does_not_change_rank(hand in seven_cards(), shift in 1_usize..4) {
        let permuted: Vec<Card> = hand
            .iter()
            .map(|c| Card::new(c.rank, Suit::ALL[(Suit::ALL.iter().position(|s| *s == c.suit).unwrap() + shift) % 4]))
            .collect();
        prop_assert_eq!(best_of(&hand).unwrap(), best_of(&permuted).unwrap());
    }
}
