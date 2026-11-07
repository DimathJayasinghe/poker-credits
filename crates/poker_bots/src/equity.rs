//! Monte Carlo equity: how often my hand wins against random opponent hands. Unseen cards are
//! "the 52 minus mine minus the board", never the real deck, so hidden information cannot leak in.

use std::time::{Duration, Instant};

use poker_engine::card::{Card, Rank, Suit};
use poker_engine::hand_rank::best_of;

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
    let mut done = 0_u32;
    let mut mine: Vec<Card> = Vec::with_capacity(7);
    let mut theirs: Vec<Card> = Vec::with_capacity(7);
    while done < samples {
        // Partial Fisher-Yates: the first `needed` cards are a uniform random draw.
        for i in 0..needed {
            let remaining = u32::try_from(deck.len() - i).unwrap_or(1);
            let j = i + usize::try_from(rng.below(remaining)).unwrap_or(0);
            deck.swap(i, j);
        }
        let drawn = deck.get(..needed).unwrap_or(&[]);
        let (runout, hands) = drawn.split_at(missing);
        mine.clear();
        mine.extend_from_slice(&hole);
        mine.extend_from_slice(board);
        mine.extend_from_slice(runout);
        let Ok(my_rank) = best_of(&mine) else {
            return 0.5;
        };
        let mut beaten = true;
        let mut ties = 1_u32;
        for pair in hands.chunks(2) {
            theirs.clear();
            theirs.extend_from_slice(pair);
            theirs.extend_from_slice(board);
            theirs.extend_from_slice(runout);
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
        if beaten {
            score += 1.0 / f64::from(ties);
        }
        done += 1;
        if done >= MIN_SAMPLES
            && done.is_multiple_of(8)
            && budget.is_some_and(|b| started.elapsed() >= b)
        {
            break;
        }
    }
    #[allow(clippy::cast_possible_truncation, reason = "a ratio in 0..=1")]
    {
        (score / f64::from(done)) as f32
    }
}
