//! Typed engine failures. Every anticipated failure is a value; the engine never panics.

use thiserror::Error;

use crate::types::{Chips, Phase, PlayerId};

/// Why a showdown allocation was rejected.
#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum AllocationError {
    /// The allocation names a pot that does not exist.
    #[error("pot {pot_index} does not exist")]
    UnknownPot {
        /// Offending pot index.
        pot_index: u32,
    },
    /// The same pot is allocated twice.
    #[error("pot {pot_index} is allocated more than once")]
    DuplicatePot {
        /// Offending pot index.
        pot_index: u32,
    },
    /// A pot has no allocation.
    #[error("pot {pot_index} has no allocation")]
    MissingPot {
        /// Offending pot index.
        pot_index: u32,
    },
    /// A pot has an empty winner list.
    #[error("pot {pot_index} has no winners")]
    NoWinners {
        /// Offending pot index.
        pot_index: u32,
    },
    /// A winner is not eligible for the pot.
    #[error("player {player_id} is not eligible for pot {pot_index}")]
    IneligibleWinner {
        /// Offending pot index.
        pot_index: u32,
        /// Player that is not eligible.
        player_id: PlayerId,
    },
}

/// Every way a command can be refused.
///
/// The server maps this exhaustively to wire error codes (`docs/API_AND_EVENTS.md` section 6).
#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum PokerError {
    /// Action from a player who is not the active seat.
    #[error("it is not this player's turn")]
    NotYourTurn,
    /// Check while facing a bet.
    #[error("cannot check while facing a bet")]
    CannotCheck,
    /// Call with nothing to call.
    #[error("there is nothing to call")]
    NothingToCall,
    /// Raise below the minimum raise.
    #[error("minimum raise is to {min_raise_to}")]
    BelowMinRaise {
        /// Smallest legal raise-to total for this player.
        min_raise_to: Chips,
    },
    /// Raise while the betting is closed to this player (short all-in did not reopen it).
    #[error("betting has not been reopened for this player")]
    BettingNotReopened,
    /// Raise larger than the player's stack.
    #[error("cannot bet more than the stack (maximum total {max_to})")]
    InsufficientFunds {
        /// Largest total the player can put in on this street.
        max_to: Chips,
    },
    /// Command needs a hand in progress.
    #[error("no hand is in progress")]
    HandNotInProgress,
    /// Command is not allowed while a hand is in progress.
    #[error("a hand is already in progress")]
    HandInProgress,
    /// Player action while the host has paused the game.
    #[error("the game is paused")]
    GamePaused,
    /// Resume while not paused.
    #[error("the game is not paused")]
    NotPaused,
    /// Fewer than two players can be dealt in.
    #[error("at least two players with chips are required")]
    NotEnoughPlayers,
    /// No such player at the table.
    #[error("unknown player")]
    UnknownPlayer,
    /// Player id already seated.
    #[error("player is already seated")]
    PlayerExists,
    /// Seat already taken.
    #[error("seat is occupied")]
    SeatOccupied,
    /// Seat index outside `0..MAX_SEATS`.
    #[error("seat index is out of range")]
    InvalidSeat,
    /// Zero, too large, or otherwise unacceptable amount or configuration.
    #[error("invalid amount or configuration")]
    InvalidAmount,
    /// Chip arithmetic left the valid range (indicates a bug or hostile input).
    #[error("chip arithmetic overflow")]
    Overflow,
    /// The phase change is not in the transition table.
    #[error("illegal transition from {from:?} to {to:?}")]
    IllegalTransition {
        /// Phase the table was in.
        from: Phase,
        /// Phase the command tried to reach.
        to: Phase,
    },
    /// Undo with an empty history.
    #[error("nothing to undo")]
    NothingToUndo,
    /// A deck that is not 52 distinct cards.
    #[error("a deck must hold 52 distinct cards")]
    InvalidDeck,
    /// A hand to rank must be 5 to 7 distinct cards.
    #[error("a hand must be 5 to 7 distinct cards")]
    InvalidHand,
    /// Showdown allocation rejected.
    #[error("invalid showdown allocation: {0}")]
    InvalidAllocation(AllocationError),
}
