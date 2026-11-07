//! Pure, deterministic Texas Hold'em betting and pot engine.
//!
//! No async, no I/O, no clock, no randomness (a virtual-card deck is an input, see ADR-016). Given the same state
//! and commands the result is always identical, which makes journal replay exact.
//!
//! The single entry point is [`apply`]: `apply(&GameState, Command) -> Result<Transition, PokerError>`.
//! The old state is never mutated; the [`Transition`] carries the new state and the [`Event`]s
//! the server maps to the wire. Rules are documented in `docs/GAME_LOGIC_AND_RULES.md`.

pub mod blinds;
pub mod button;
pub mod card;
pub mod command;
pub mod deal;
pub mod deck;
pub mod error;
pub mod event;
pub mod hand_rank;
pub mod machine;
pub mod pots;
pub mod showdown;
pub mod state;
pub mod types;
pub mod undo;
pub mod validator;

pub use command::{Allocation, Command, PlayerAction};
pub use error::{AllocationError, PokerError};
pub use event::{ActionKind, BlindKind, Event};
pub use machine::{Transition, apply};
pub use state::{GameState, HandStatus, PotTier, Seat, Table};
pub use types::{Chips, MAX_SEATS, Phase, PlayerId, SeatIndex};
pub use validator::LegalActions;

/// Largest stack the engine accepts for one player (buy-in or top-up).
///
/// Kept below 2^53 so values are exact in JavaScript clients (ADR-014).
pub const MAX_CHIPS: u64 = 1_000_000_000_000;

/// Largest chip amount any value in the engine can hold: every seat at [`MAX_CHIPS`].
///
/// Pots and winning stacks can exceed [`MAX_CHIPS`] but never this bound.
pub const MAX_TABLE_CHIPS: u64 = MAX_CHIPS * 10;

// Compile-time guarantee: 2^53 - 1 is the largest integer a JS number represents exactly.
const _: () = assert!(MAX_TABLE_CHIPS < (1_u64 << 53));
