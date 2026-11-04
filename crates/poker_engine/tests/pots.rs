//! Pot construction, uncalled-bet refunds and the odd-chip rule.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::pots::{Contribution, calculate, clockwise_from_button, split, uncalled_refund};
use support::{chips, seat};

fn paid(seat_index: u8, amount: u64, folded: bool) -> Contribution {
    Contribution {
        seat: seat(seat_index),
        amount: chips(amount),
        folded,
    }
}

fn pots_of(contributions: &[Contribution]) -> Vec<poker_engine::PotTier> {
    calculate(contributions).unwrap()
}

fn amounts(pots: &[poker_engine::PotTier]) -> Vec<u64> {
    pots.iter().map(|pot| pot.amount.get()).collect()
}

#[test]
fn rules_doc_example_four_players() {
    // GAME_LOGIC_AND_RULES.md section 6: Alice 100 all-in, Bob 250 all-in, Charlie 500, Dave folded at 40.
    let contributions = [
        paid(0, 100, false),
        paid(1, 250, false),
        paid(2, 500, false),
        paid(3, 40, true),
    ];
    assert_eq!(uncalled_refund(&contributions), Some((seat(2), chips(250))));

    let after_refund = [
        paid(0, 100, false),
        paid(1, 250, false),
        paid(2, 250, false),
        paid(3, 40, true),
    ];
    let pots = pots_of(&after_refund);
    assert_eq!(amounts(&pots), vec![340, 300]);
    assert_eq!(pots[0].eligible, vec![seat(0), seat(1), seat(2)]);
    assert_eq!(pots[1].eligible, vec![seat(1), seat(2)]);
}

#[test]
fn architecture_doc_example() {
    // ARCHITECTURE.md section 5: A all-in 50, B all-in 120, C calls 120, D folded at 20.
    let pots = pots_of(&[
        paid(0, 50, false),
        paid(1, 120, false),
        paid(2, 120, false),
        paid(3, 20, true),
    ]);
    assert_eq!(amounts(&pots), vec![170, 140]);
    assert_eq!(pots[0].eligible, vec![seat(0), seat(1), seat(2)]);
    assert_eq!(pots[1].eligible, vec![seat(1), seat(2)]);
    assert_eq!(pots[0].tier_index, 0);
    assert_eq!(pots[1].tier_index, 1);
}

#[test]
fn single_pot_when_everyone_matched() {
    let pots = pots_of(&[paid(0, 60, false), paid(1, 60, false), paid(2, 60, false)]);
    assert_eq!(amounts(&pots), vec![180]);
    assert_eq!(pots[0].eligible.len(), 3);
}

#[test]
fn folded_chips_never_create_a_pot_of_their_own() {
    // The folder put in more than the all-in player but less than the caller.
    let pots = pots_of(&[paid(0, 50, false), paid(1, 80, true), paid(2, 100, false)]);
    assert_eq!(amounts(&pots), vec![150, 80]);
    assert_eq!(pots[0].eligible, vec![seat(0), seat(2)]);
    assert_eq!(pots[1].eligible, vec![seat(2)]);
}

#[test]
fn folded_overbet_is_added_to_the_last_pot() {
    let pots = pots_of(&[paid(0, 40, false), paid(1, 300, true), paid(2, 300, true)]);
    assert_eq!(amounts(&pots), vec![640]);
    assert_eq!(pots[0].eligible, vec![seat(0)]);
}

#[test]
fn no_contributions_no_pots() {
    assert!(pots_of(&[]).is_empty());
    assert_eq!(uncalled_refund(&[]), None);
}

#[test]
fn refund_counts_a_folded_matcher_as_a_call() {
    // The bettor put in 100; a folder matched 60 and another 30: only 40 is uncalled.
    let contributions = [paid(0, 100, false), paid(1, 60, true), paid(2, 30, true)];
    assert_eq!(uncalled_refund(&contributions), Some((seat(0), chips(40))));
}

#[test]
fn no_refund_when_top_is_tied() {
    assert_eq!(
        uncalled_refund(&[paid(0, 100, false), paid(1, 100, false)]),
        None
    );
}

#[test]
fn pots_plus_refund_always_equal_contributions() {
    let cases: [&[Contribution]; 4] = [
        &[paid(0, 1, false), paid(1, 7, false), paid(2, 3, true)],
        &[
            paid(0, 500, false),
            paid(1, 500, false),
            paid(2, 20, true),
            paid(3, 500, false),
        ],
        &[paid(0, 9, true), paid(1, 4, false)],
        &[paid(5, 33, false), paid(1, 33, false), paid(9, 12, false)],
    ];
    for contributions in cases {
        let refund = uncalled_refund(contributions).map_or(0, |(_, amount)| amount.get());
        let mut after = contributions.to_vec();
        if let Some((refund_seat, amount)) = uncalled_refund(contributions) {
            for contribution in &mut after {
                if contribution.seat == refund_seat {
                    contribution.amount = contribution.amount.saturating_sub(amount);
                }
            }
        }
        let pot_total: u64 = pots_of(&after).iter().map(|pot| pot.amount.get()).sum();
        let paid_total: u64 = contributions.iter().map(|c| c.amount.get()).sum();
        assert_eq!(pot_total + refund, paid_total);
    }
}

#[test]
fn odd_chip_goes_to_first_winner_clockwise_from_the_button() {
    // 101 between two winners: 51 to the earlier seat after the button, 50 to the other.
    let ordered = clockwise_from_button(&[seat(1), seat(4)], Some(seat(2)));
    assert_eq!(ordered, vec![seat(4), seat(1)]);
    let shares = split(chips(101), &ordered);
    assert_eq!(shares, vec![(seat(4), chips(51)), (seat(1), chips(50))]);
}

#[test]
fn remainder_larger_than_one_is_spread_one_chip_each() {
    let shares = split(chips(11), &[seat(3), seat(5), seat(7)]);
    assert_eq!(
        shares,
        vec![
            (seat(3), chips(4)),
            (seat(5), chips(4)),
            (seat(7), chips(3))
        ]
    );
    assert_eq!(shares.iter().map(|(_, c)| c.get()).sum::<u64>(), 11);
}

#[test]
fn button_winner_is_last_in_clockwise_order() {
    let ordered = clockwise_from_button(&[seat(2), seat(0), seat(5)], Some(seat(2)));
    assert_eq!(ordered, vec![seat(5), seat(0), seat(2)]);
}

#[test]
fn split_with_no_winners_pays_nobody() {
    assert!(split(chips(50), &[]).is_empty());
}

#[test]
fn folded_chips_form_a_pot_when_no_live_seat_has_paid() {
    // Seat 3 is still in the hand but has put nothing in; both blinds folded.
    let pots = pots_of(&[paid(1, 1, true), paid(2, 1, true), paid(3, 0, false)]);
    assert_eq!(pots.len(), 1);
    assert_eq!(pots[0].amount.get(), 2);
    assert_eq!(pots[0].eligible, vec![seat(3)]);
}
