//! Computer players for single-player games (ADR-018, `docs/superpowers/specs/2026-11-07-single-player-bots-design.md`).
//!
//! Pure Rust: no async, no I/O, no clock, no dependency on the server. A bot decides from a
//! [`BotView`] and nothing else: its own two cards, the board, the pots and stacks, and the public
//! betting. It never sees the deck or another player's hole cards (the type has no field for them),
//! and [`observe::view_for_seat`] is the one function that reads a table to build it.

pub mod decide;
pub mod equity;
pub mod names;
pub mod notes;
pub mod observe;
pub mod personality;
pub mod rng;
pub mod skill;
pub mod strength;
pub mod tuning;
pub mod view;

pub use decide::{BotMind, Decision, decide};
pub use observe::view_for_seat;
pub use personality::{Archetype, Personality};
pub use rng::BotRng;
pub use skill::Skill;
pub use tuning::Tuning;
pub use view::{BotView, PublicAction, Reveal, SeatView};
