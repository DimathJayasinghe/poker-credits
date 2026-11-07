//! The three levels the player picks. They differ only in how well a bot uses the same
//! information; no level sees anything more (ADR-018, spec section 4.4).

use serde::{Deserialize, Serialize};

/// How well a bot plays.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Skill {
    /// Plays by instinct: no equity estimates, no reads, frequent mistakes.
    Easy,
    /// Reads the table slowly, occasional mistakes.
    Normal,
    /// Reads fast, estimates well, rarely errs.
    Hard,
}

impl Skill {
    /// Equity samples per postflop decision (0 means: judge only the made hand).
    #[must_use]
    pub const fn samples(self) -> u32 {
        match self {
            Skill::Easy => 0,
            Skill::Normal => 120,
            Skill::Hard => 400,
        }
    }

    /// Chance that a decision is replaced by a typical mistake.
    #[must_use]
    pub const fn error_rate(self) -> f32 {
        match self {
            Skill::Easy => 0.16,
            Skill::Normal => 0.06,
            Skill::Hard => 0.02,
        }
    }

    /// How blurry the bot's own hand-strength estimate is (plus or minus).
    #[must_use]
    pub const fn noise(self) -> f32 {
        match self {
            Skill::Easy => 0.12,
            Skill::Normal => 0.05,
            Skill::Hard => 0.02,
        }
    }

    /// Observations of an opponent needed before the bot leans on its read of them.
    #[must_use]
    pub const fn read_threshold(self) -> u32 {
        match self {
            Skill::Easy => u32::MAX,
            Skill::Normal => 25,
            Skill::Hard => 10,
        }
    }

    /// How strongly a read shifts a decision (0 = never).
    #[must_use]
    pub const fn read_gain(self) -> f32 {
        match self {
            Skill::Easy => 0.0,
            Skill::Normal => 0.5,
            Skill::Hard => 1.0,
        }
    }
}
