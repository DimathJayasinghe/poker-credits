//! Blind structures. A strategy answers "what are the blinds for this hand?"; the engine has no
//! clock, so tournament elapsed time arrives inside the journaled `StartHand` command.

use serde::{Deserialize, Serialize};

use crate::error::PokerError;
use crate::types::Chips;

/// Forced bets for one hand.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Blinds {
    /// Small blind.
    pub small_blind: Chips,
    /// Big blind (also the minimum opening bet).
    pub big_blind: Chips,
    /// Ante posted by every player dealt in (zero for none).
    pub ante: Chips,
}

impl Blinds {
    /// Checks the structure is playable.
    ///
    /// # Errors
    /// [`PokerError::InvalidAmount`] unless `0 < small_blind <= big_blind`.
    pub fn validate(&self) -> Result<(), PokerError> {
        if self.small_blind.is_zero() || self.big_blind < self.small_blind {
            Err(PokerError::InvalidAmount)
        } else {
            Ok(())
        }
    }
}

/// Source of blinds for a hand.
pub trait BlindsStrategy {
    /// Blinds for `hand_number` (1-based) after `elapsed_ms` of tournament time.
    fn blinds(&self, hand_number: u32, elapsed_ms: u64) -> Blinds;

    /// Checks the whole structure is playable.
    ///
    /// # Errors
    /// [`PokerError::InvalidAmount`] for an unplayable structure.
    fn validate(&self) -> Result<(), PokerError>;
}

/// Fixed blinds that change only when the host reconfigures the table.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CashGame {
    /// The blinds for every hand.
    pub blinds: Blinds,
}

impl BlindsStrategy for CashGame {
    fn blinds(&self, _hand_number: u32, _elapsed_ms: u64) -> Blinds {
        self.blinds
    }

    fn validate(&self) -> Result<(), PokerError> {
        self.blinds.validate()
    }
}

/// Escalating blind levels driven by tournament time, or by the number of hands dealt.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Tournament {
    /// Levels in order; the last one repeats once time runs past it.
    pub levels: Vec<Blinds>,
    /// Length of each level in milliseconds (ignored when `hands_per_level` is set).
    pub level_ms: u64,
    /// When set and above zero, the level rises every this many hands and the clock is ignored:
    /// the structure is then deterministic and unaffected by pauses (solo games).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hands_per_level: Option<u32>,
}

impl Tournament {
    fn hands_per_level(&self) -> Option<u32> {
        self.hands_per_level.filter(|hands| *hands > 0)
    }

    /// For a hand-driven ladder: the blinds of the level after the one `hand_number` is played at,
    /// and how many hands are left at the current level, `hand_number` included. `None` without a
    /// hand-driven ladder, and on the last level (it repeats, so nothing rises).
    #[must_use]
    pub fn next_level(&self, hand_number: u32) -> Option<(Blinds, u32)> {
        let hands = self.hands_per_level()?;
        let played = hand_number.saturating_sub(1);
        let level = usize::try_from(played / hands).ok()?;
        let next = self.levels.get(level.checked_add(1)?)?;
        Some((*next, hands - played % hands))
    }
}

impl BlindsStrategy for Tournament {
    fn blinds(&self, hand_number: u32, elapsed_ms: u64) -> Blinds {
        let level = match self.hands_per_level() {
            Some(hands) => u64::from(hand_number.saturating_sub(1) / hands),
            None => elapsed_ms.checked_div(self.level_ms).unwrap_or(0),
        };
        let index = usize::try_from(level).unwrap_or(usize::MAX);
        self.levels
            .get(index)
            .or_else(|| self.levels.last())
            .copied()
            .unwrap_or_default()
    }

    fn validate(&self) -> Result<(), PokerError> {
        if self.levels.is_empty() || (self.level_ms == 0 && self.hands_per_level().is_none()) {
            return Err(PokerError::InvalidAmount);
        }
        self.levels.iter().try_for_each(Blinds::validate)
    }
}

/// The blind structures the table can run (enum dispatch keeps the state serialisable).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BlindsMode {
    /// Fixed blinds.
    Cash(CashGame),
    /// Escalating blinds.
    Tournament(Tournament),
}

impl BlindsStrategy for BlindsMode {
    fn blinds(&self, hand_number: u32, elapsed_ms: u64) -> Blinds {
        match self {
            BlindsMode::Cash(cash) => cash.blinds(hand_number, elapsed_ms),
            BlindsMode::Tournament(tournament) => tournament.blinds(hand_number, elapsed_ms),
        }
    }

    fn validate(&self) -> Result<(), PokerError> {
        match self {
            BlindsMode::Cash(cash) => cash.validate(),
            BlindsMode::Tournament(tournament) => tournament.validate(),
        }
    }
}
