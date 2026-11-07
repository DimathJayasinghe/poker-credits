//! Poker hand ranking: the best five of up to seven cards. Pure and total: two hands compare by
//! category, then by the ordered tie-break ranks. Suits never break ties.

use std::cmp::Ordering;

use serde::{Deserialize, Serialize};

use crate::card::Card;
use crate::error::PokerError;

/// The nine hand categories, lowest first.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum HandCategory {
    /// No combination.
    HighCard,
    /// Two cards of one rank.
    Pair,
    /// Two different pairs.
    TwoPair,
    /// Three of one rank.
    ThreeOfAKind,
    /// Five in sequence (the ace plays high or low).
    Straight,
    /// Five of one suit.
    Flush,
    /// Three of one rank and a pair.
    FullHouse,
    /// Four of one rank.
    FourOfAKind,
    /// Five in sequence of one suit (the royal flush is the ace-high one).
    StraightFlush,
}

/// A ranked five-card hand. Equality and order look at strength only, so two hands with the same
/// ranks in different suits are equal (they split a pot).
#[derive(Clone, Copy, Debug)]
pub struct HandRank {
    score: u32,
    best_five: [Card; 5],
}

impl HandRank {
    /// The category of the hand.
    #[must_use]
    pub fn category(&self) -> HandCategory {
        match self.score >> 20 {
            0 => HandCategory::HighCard,
            1 => HandCategory::Pair,
            2 => HandCategory::TwoPair,
            3 => HandCategory::ThreeOfAKind,
            4 => HandCategory::Straight,
            5 => HandCategory::Flush,
            6 => HandCategory::FullHouse,
            7 => HandCategory::FourOfAKind,
            _ => HandCategory::StraightFlush,
        }
    }

    /// The five cards that make the hand.
    #[must_use]
    pub fn best_five(&self) -> [Card; 5] {
        self.best_five
    }
}

impl PartialEq for HandRank {
    fn eq(&self, other: &Self) -> bool {
        self.score == other.score
    }
}

impl Eq for HandRank {}

impl PartialOrd for HandRank {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for HandRank {
    fn cmp(&self, other: &Self) -> Ordering {
        self.score.cmp(&other.score)
    }
}

/// Ranks exactly five distinct cards. Distinctness is the caller's duty here; [`best_of`] checks it.
#[must_use]
pub fn rank_five(cards: &[Card; 5]) -> HandRank {
    let [first, ..] = cards;
    let flush = cards.iter().all(|card| card.suit == first.suit);
    let mut ranks = cards.map(|card| card.rank.value());
    ranks.sort_unstable_by(|a, b| b.cmp(a));

    // Groups of equal ranks as (count, rank), biggest group and highest rank first.
    let mut groups = [(0_u8, 0_u8); 5];
    let mut used = 0_usize;
    for rank in ranks {
        if let Some(group) = groups.iter_mut().take(used).find(|group| group.1 == rank) {
            group.0 += 1;
        } else if let Some(slot) = groups.get_mut(used) {
            *slot = (1, rank);
            used += 1;
        }
    }
    if let Some(live) = groups.get_mut(..used) {
        live.sort_unstable_by(|a, b| b.cmp(a));
    }
    let [(c0, _), (c1, _), ..] = groups;
    let mut tie = groups.map(|group| group.1);

    let [high, _, _, _, low] = ranks;
    let wheel = ranks == [14, 5, 4, 3, 2];
    let straight = used == 5 && (high - low == 4 || wheel);
    if straight {
        tie = [if wheel { 5 } else { high }, 0, 0, 0, 0];
    }

    let category = if straight && flush {
        HandCategory::StraightFlush
    } else if c0 == 4 {
        HandCategory::FourOfAKind
    } else if c0 == 3 && c1 == 2 {
        HandCategory::FullHouse
    } else if flush {
        HandCategory::Flush
    } else if straight {
        HandCategory::Straight
    } else if c0 == 3 {
        HandCategory::ThreeOfAKind
    } else if c0 == 2 && c1 == 2 {
        HandCategory::TwoPair
    } else if c0 == 2 {
        HandCategory::Pair
    } else {
        HandCategory::HighCard
    };

    let packed = tie
        .iter()
        .fold(0_u32, |acc, rank| (acc << 4) | u32::from(*rank));
    HandRank {
        score: ((category as u32) << 20) | packed,
        best_five: *cards,
    }
}

/// The best five-card hand among 5 to 7 distinct cards.
///
/// # Errors
/// [`PokerError::InvalidHand`] for fewer than 5 or more than 7 cards, or a repeated card.
pub fn best_of(cards: &[Card]) -> Result<HandRank, PokerError> {
    let count = cards.len();
    if !(5..=7).contains(&count) {
        return Err(PokerError::InvalidHand);
    }
    let mut sorted = cards.to_vec();
    sorted.sort_unstable();
    sorted.dedup();
    if sorted.len() != count {
        return Err(PokerError::InvalidHand);
    }

    let mut best: Option<HandRank> = None;
    for mask in 0_u32..(1 << count) {
        if mask.count_ones() != 5 {
            continue;
        }
        let picked: Vec<Card> = cards
            .iter()
            .enumerate()
            .filter(|(index, _)| mask & (1 << index) != 0)
            .map(|(_, card)| *card)
            .collect();
        let five = <[Card; 5]>::try_from(picked.as_slice()).map_err(|_| PokerError::InvalidHand)?;
        let ranked = rank_five(&five);
        best = Some(best.map_or(ranked, |current| current.max(ranked)));
    }
    best.ok_or(PokerError::InvalidHand)
}
