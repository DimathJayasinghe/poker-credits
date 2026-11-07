//! What a bot has noticed about the other players. Filled in by the adaptation work; until then
//! a bot has no reads and plays its personality.

use crate::personality::Personality;
use crate::skill::Skill;
use crate::view::BotView;

/// How the notes bend one decision.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Reads {
    /// Added to the bot's strength estimate (positive: bet and call more).
    pub strength_shift: f32,
    /// Multiplies the bot's bluff frequency (1.0 = unchanged).
    pub bluff_boost: f32,
    /// Added to the equity a call needs (positive: fold more).
    pub caution: f32,
}

/// One bot's private notes on every other player.
#[derive(Clone, Debug, Default)]
pub struct Notes {}

impl Notes {
    /// The adjustments for this decision. No reads yet: everything neutral.
    #[must_use]
    pub fn reads(&self, _view: &BotView, _skill: Skill, _personality: &Personality) -> Reads {
        Reads {
            strength_shift: 0.0,
            bluff_boost: 1.0,
            caution: 0.0,
        }
    }
}
