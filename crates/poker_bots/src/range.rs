//! What a player's actions say about the cards they hold: a soft description of their range that
//! the equity sampler uses to deal them hands. Built from public information only.

use poker_engine::card::Card;

use crate::hand::{draws, made_strength};
use crate::strength::preflop_strength;

/// How likely a player is to hold a given hand, given how they have played this one.
///
/// A weight of 1.0 means "they could well hold it", near 0.0 "they almost never would".
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RangeProfile {
    /// Weakest starting-hand strength they usually continue with (0 means any hand).
    pub pre_min: f32,
    /// How fast the weight falls for hands below `pre_min` (a player sometimes plays worse).
    pub pre_soft: f32,
    /// Postflop streets on which they bet or raised.
    pub aggressive_streets: u8,
    /// Postflop bets they called.
    pub called_bets: u8,
    /// Weight of a hand with nothing when they bet (0 never bluffs, 1 bets anything).
    pub bluff: f32,
}

impl RangeProfile {
    /// No information: every hand is as likely as any other.
    pub const ANY: RangeProfile = RangeProfile {
        pre_min: 0.0,
        pre_soft: 0.06,
        aggressive_streets: 0,
        called_bets: 0,
        bluff: 0.3,
    };

    /// True when the profile cannot narrow anything.
    #[must_use]
    pub fn is_any(&self) -> bool {
        self.pre_min <= 0.0 && self.aggressive_streets == 0 && self.called_bets == 0
    }

    /// The weight of holding `cards` on `board`, from 0.0 to 1.0.
    #[must_use]
    pub fn weight(&self, cards: [Card; 2], board: &[Card]) -> f32 {
        let mut weight = 1.0_f32;
        if self.pre_min > 0.0 {
            let strength = preflop_strength(cards);
            if strength < self.pre_min {
                weight *= (-(self.pre_min - strength) / self.pre_soft.max(0.01)).exp();
            }
        }
        if board.len() >= 3 && (self.aggressive_streets > 0 || self.called_bets > 0) {
            let tier = made_strength(cards, board);
            let draw = draws(cards, board).any();
            if self.aggressive_streets > 0 {
                let value = ((tier - 0.35) / 0.35).clamp(0.0, 1.0);
                let mut once = self.bluff + (1.0 - self.bluff) * value;
                if draw {
                    once = once.max(0.55);
                }
                weight *= once.powi(i32::from(self.aggressive_streets.min(3)));
            }
            if self.called_bets > 0 {
                let value = ((tier - 0.28) / 0.30).clamp(0.0, 1.0);
                let mut once = 0.2 + 0.8 * value;
                if draw {
                    once = once.max(0.85);
                }
                weight *= once.powi(i32::from(self.called_bets.min(2)));
            }
        }
        weight
    }
}
