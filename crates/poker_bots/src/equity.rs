//! Monte Carlo equity: how often my hand wins against random opponent hands. Unseen cards are
//! "the 52 minus mine minus the board", never the real deck, so hidden information cannot leak in.

use std::time::{Duration, Instant};

use poker_engine::card::{Card, Rank, Suit};
use poker_engine::hand_rank::best_of;

use crate::range::RangeProfile;
use crate::rng::BotRng;

/// Samples taken before a time budget may stop the loop.
const MIN_SAMPLES: u32 = 20;

fn unseen(hole: [Card; 2], board: &[Card]) -> Vec<Card> {
    let mut cards = Vec::with_capacity(52);
    for rank in Rank::ALL {
        for suit in Suit::ALL {
            let card = Card::new(rank, suit);
            if card != hole[0] && card != hole[1] && !board.contains(&card) {
                cards.push(card);
            }
        }
    }
    cards
}

/// My chance of winning (a tie counts as its share), from 0.0 to 1.0.
///
/// `opponents` hands are dealt at random each sample and the board is completed at random.
/// With `samples == 0` or no opponents the answer is the neutral 0.5 (or 1.0 against nobody).
/// `budget` stops the loop early, after at least [`MIN_SAMPLES`] samples.
#[must_use]
pub fn equity(
    hole: [Card; 2],
    board: &[Card],
    opponents: usize,
    samples: u32,
    rng: &mut BotRng,
    budget: Option<Duration>,
) -> f32 {
    let ranges = vec![RangeProfile::ANY; opponents];
    equity_against(hole, board, &ranges, samples, rng, budget)
}

/// Tries to deal an opponent a hand the profile would plausibly hold before giving up.
const DEAL_TRIES: usize = 8;

/// Deals the two cards at `at` and `at + 1` from the rest of the deck, trying again when the
/// profile finds the hand unlikely. Returns the weight to give the sample: 1.0 when a hand was
/// accepted, the (small) weight of the last hand tried when none was.
fn deal_hand(
    deck: &mut [Card],
    at: usize,
    profile: &RangeProfile,
    board: &[Card],
    rng: &mut BotRng,
) -> f32 {
    if profile.is_any() {
        for i in at..at + 2 {
            let remaining = u32::try_from(deck.len() - i).unwrap_or(1);
            let j = i + usize::try_from(rng.below(remaining)).unwrap_or(0);
            deck.swap(i, j);
        }
        return 1.0;
    }
    let mut weight = 1.0;
    for _ in 0..DEAL_TRIES {
        for i in at..at + 2 {
            let remaining = u32::try_from(deck.len() - i).unwrap_or(1);
            let j = i + usize::try_from(rng.below(remaining)).unwrap_or(0);
            deck.swap(i, j);
        }
        let (Some(a), Some(b)) = (deck.get(at).copied(), deck.get(at + 1).copied()) else {
            return 1.0;
        };
        weight = profile.weight([a, b], board);
        if weight >= 1.0 || rng.unit() < weight {
            return 1.0;
        }
    }
    weight
}

/// My chance of winning against opponents whose hands are drawn from `ranges` (one profile per
/// opponent): the hands they would bet, call or raise with are dealt more often than the rest.
///
/// A sample where no plausible hand turned up counts for less (its weight), so a range nobody
/// holds still gives an answer. With `samples == 0` the answer is the neutral 0.5; no opponents
/// gives 1.0. `budget` stops the loop early, after at least [`MIN_SAMPLES`] samples.
#[must_use]
pub fn equity_against(
    hole: [Card; 2],
    board: &[Card],
    ranges: &[RangeProfile],
    samples: u32,
    rng: &mut BotRng,
    budget: Option<Duration>,
) -> f32 {
    let opponents = ranges.len();
    if opponents == 0 {
        return 1.0;
    }
    if samples == 0 {
        return 0.5;
    }
    let mut deck = unseen(hole, board);
    let missing = 5_usize.saturating_sub(board.len());
    let needed = missing + opponents * 2;
    if deck.len() < needed {
        return 0.5;
    }
    let started = Instant::now();
    let mut score = 0.0_f64;
    let mut total = 0.0_f64;
    let mut done = 0_u32;
    let mut mine: Vec<Card> = Vec::with_capacity(7);
    let mut theirs: Vec<Card> = Vec::with_capacity(7);
    let mut runout: Vec<Card> = Vec::with_capacity(5);
    while done < samples {
        let mut sample_weight = 1.0_f32;
        for (k, profile) in ranges.iter().enumerate() {
            sample_weight *= deal_hand(&mut deck, 2 * k, profile, board, rng);
        }
        // The rest of the board comes from what is left (a partial Fisher-Yates shuffle).
        for i in 2 * opponents..needed {
            let remaining = u32::try_from(deck.len() - i).unwrap_or(1);
            let j = i + usize::try_from(rng.below(remaining)).unwrap_or(0);
            deck.swap(i, j);
        }
        runout.clear();
        runout.extend(deck.get(2 * opponents..needed).unwrap_or(&[]));
        mine.clear();
        mine.extend_from_slice(&hole);
        mine.extend_from_slice(board);
        mine.extend_from_slice(&runout);
        let Ok(my_rank) = best_of(&mine) else {
            return 0.5;
        };
        let mut beaten = true;
        let mut ties = 1_u32;
        for pair in deck.get(..2 * opponents).unwrap_or(&[]).chunks(2) {
            theirs.clear();
            theirs.extend_from_slice(pair);
            theirs.extend_from_slice(board);
            theirs.extend_from_slice(&runout);
            let Ok(their_rank) = best_of(&theirs) else {
                return 0.5;
            };
            match my_rank.cmp(&their_rank) {
                std::cmp::Ordering::Less => {
                    beaten = false;
                    break;
                }
                std::cmp::Ordering::Equal => ties += 1,
                std::cmp::Ordering::Greater => {}
            }
        }
        let w = f64::from(sample_weight);
        if beaten {
            score += w / f64::from(ties);
        }
        total += w;
        done += 1;
        if done >= MIN_SAMPLES
            && done.is_multiple_of(8)
            && budget.is_some_and(|b| started.elapsed() >= b)
        {
            break;
        }
    }
    if total <= 0.0 {
        return 0.5;
    }
    #[allow(clippy::cast_possible_truncation, reason = "a ratio in 0..=1")]
    {
        (score / total) as f32
    }
}
