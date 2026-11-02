//! Domain newtypes shared by every engine module.

use std::fmt;

use serde::{Deserialize, Serialize};

use crate::MAX_TABLE_CHIPS;
use crate::error::PokerError;

/// Maximum number of seats at a table.
pub const MAX_SEATS: u8 = 10;

/// A non-negative chip amount, never above [`MAX_TABLE_CHIPS`].
///
/// Deserialisation enforces the bound, so a hostile snapshot cannot smuggle in a huge value.
#[derive(
    Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize,
)]
#[serde(try_from = "u64", into = "u64")]
pub struct Chips(u64);

impl Chips {
    /// Zero chips.
    pub const ZERO: Chips = Chips(0);

    /// Wraps a raw amount.
    ///
    /// # Errors
    /// [`PokerError::Overflow`] if `value` exceeds [`MAX_TABLE_CHIPS`].
    pub fn new(value: u64) -> Result<Self, PokerError> {
        if value > MAX_TABLE_CHIPS {
            Err(PokerError::Overflow)
        } else {
            Ok(Chips(value))
        }
    }

    /// Wraps a raw amount, capping it at [`MAX_TABLE_CHIPS`]. For shares of a pot, which can never
    /// exceed the bound because the pot itself does not.
    #[must_use]
    pub fn clamped(value: u64) -> Self {
        Chips(value.min(MAX_TABLE_CHIPS))
    }

    /// Raw amount.
    #[must_use]
    pub const fn get(self) -> u64 {
        self.0
    }

    /// True when the amount is zero.
    #[must_use]
    pub const fn is_zero(self) -> bool {
        self.0 == 0
    }

    /// Checked addition.
    ///
    /// # Errors
    /// [`PokerError::Overflow`] if the sum leaves the valid range.
    pub fn checked_add(self, other: Chips) -> Result<Chips, PokerError> {
        self.0
            .checked_add(other.0)
            .ok_or(PokerError::Overflow)
            .and_then(Chips::new)
    }

    /// Checked subtraction.
    ///
    /// # Errors
    /// [`PokerError::Overflow`] if `other` is larger than `self`.
    pub fn checked_sub(self, other: Chips) -> Result<Chips, PokerError> {
        self.0
            .checked_sub(other.0)
            .map(Chips)
            .ok_or(PokerError::Overflow)
    }

    /// Subtraction that stops at zero. Use only where the order is already guaranteed.
    #[must_use]
    pub fn saturating_sub(self, other: Chips) -> Chips {
        Chips(self.0.saturating_sub(other.0))
    }

    /// Addition that stops at [`MAX_TABLE_CHIPS`]. Use only for display-grade sums.
    #[must_use]
    pub fn saturating_add(self, other: Chips) -> Chips {
        Chips(self.0.saturating_add(other.0).min(MAX_TABLE_CHIPS))
    }
}

impl TryFrom<u64> for Chips {
    type Error = PokerError;

    fn try_from(value: u64) -> Result<Self, Self::Error> {
        Chips::new(value)
    }
}

impl From<Chips> for u64 {
    fn from(value: Chips) -> Self {
        value.0
    }
}

impl fmt::Display for Chips {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

/// Stable identifier of a player (assigned by the server, opaque to the engine).
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct PlayerId(String);

impl PlayerId {
    /// Wraps an identifier.
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        PlayerId(id.into())
    }

    /// Identifier as text.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for PlayerId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Seat position, `0..MAX_SEATS`, clockwise.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(try_from = "u8", into = "u8")]
pub struct SeatIndex(u8);

impl SeatIndex {
    /// Validates a seat number.
    ///
    /// # Errors
    /// [`PokerError::InvalidSeat`] if `value >= MAX_SEATS`.
    pub fn new(value: u8) -> Result<Self, PokerError> {
        if value < MAX_SEATS {
            Ok(SeatIndex(value))
        } else {
            Err(PokerError::InvalidSeat)
        }
    }

    /// Seat number.
    #[must_use]
    pub const fn get(self) -> u8 {
        self.0
    }
}

impl TryFrom<u8> for SeatIndex {
    type Error = PokerError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        SeatIndex::new(value)
    }
}

impl From<SeatIndex> for u8 {
    fn from(value: SeatIndex) -> Self {
        value.0
    }
}

/// Where the table is in the hand lifecycle.
///
/// The wire phases `STARTING_HAND`, `POSTING_BLINDS`, `PAYOUT` and `PAUSED` are transient or
/// derived: the engine passes through the first three inside a single command and exposes pause
/// as `Table::paused`, so resuming restores the exact phase.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Phase {
    /// No hand yet, or the game ended with one player holding the chips.
    Lobby,
    /// First betting round.
    PreFlop,
    /// Second betting round.
    Flop,
    /// Third betting round.
    Turn,
    /// Final betting round.
    River,
    /// Everyone left is all-in; cards run out on the physical table.
    AllInRunout,
    /// Betting over; the host marks winners.
    Showdown,
    /// Hand paid out; ready to deal again.
    NextHandPrep,
}

impl Phase {
    /// True for the four betting streets.
    #[must_use]
    pub const fn is_betting(self) -> bool {
        matches!(
            self,
            Phase::PreFlop | Phase::Flop | Phase::Turn | Phase::River
        )
    }
}
