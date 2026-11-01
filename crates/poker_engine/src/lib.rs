//! Pure, deterministic Texas Hold'em betting and pot engine.
//!
//! No async, no I/O, no clock, no randomness (cards are physical). Given the same state
//! and commands the result is always identical, which makes journal replay exact.
//! Implementation starts in Phase 1; see `docs/AGENT_CODING_GUIDE.md`.

/// Largest chip amount the engine accepts.
///
/// Kept below 2^53 so values are exact in JavaScript clients (ADR-014).
pub const MAX_CHIPS: u64 = 1_000_000_000_000;

// Compile-time guarantee: 2^53 - 1 is the largest integer a JS number represents exactly.
const _: () = assert!(MAX_CHIPS < (1_u64 << 53));
