//! Who a bot is: an archetype plus per-bot jitter, so no two bots play alike (spec section 4.7).

use serde::{Deserialize, Serialize};

use crate::rng::BotRng;

/// The six styles.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Archetype {
    /// Very tight, rarely bluffs, bets big when it has it.
    Rock,
    /// Tight and aggressive: raises or folds.
    Tag,
    /// Loose and aggressive: many pots, many raises and bluffs.
    Lag,
    /// Loose and passive: calls too much, rarely raises.
    CallingStation,
    /// Extreme aggression and wild sizing.
    Maniac,
    /// Tight, slow-plays strong hands.
    NitTrapper,
}

impl Archetype {
    /// All six, in a fixed order.
    pub const ALL: [Archetype; 6] = [
        Archetype::Rock,
        Archetype::Tag,
        Archetype::Lag,
        Archetype::CallingStation,
        Archetype::Maniac,
        Archetype::NitTrapper,
    ];

    /// Base parameters: looseness, aggression, bluff, trap, size habit, think speed.
    const fn base(self) -> [f32; 6] {
        match self {
            Archetype::Rock => [0.15, 0.45, 0.05, 0.20, 0.90, 0.40],
            Archetype::Tag => [0.35, 0.70, 0.20, 0.15, 0.70, 0.50],
            Archetype::Lag => [0.70, 0.85, 0.45, 0.10, 0.75, 0.60],
            Archetype::CallingStation => [0.80, 0.20, 0.05, 0.05, 0.50, 0.50],
            Archetype::Maniac => [0.95, 1.00, 0.70, 0.05, 1.00, 0.80],
            Archetype::NitTrapper => [0.20, 0.40, 0.10, 0.70, 0.60, 0.30],
        }
    }
}

/// One bot's playing style. Every parameter is 0..=1 except `size_habit` (0.3..=1.2).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Personality {
    /// The archetype it was sampled from.
    pub archetype: Archetype,
    /// How wide a range it plays.
    pub looseness: f32,
    /// How often it raises rather than calls.
    pub aggression: f32,
    /// How often it bluffs.
    pub bluff: f32,
    /// How often it slow-plays strong hands.
    pub trap: f32,
    /// Bet size as a fraction of the pot.
    pub size_habit: f32,
    /// How much a big loss loosens it for a few hands.
    pub tilt: f32,
    /// 1.0 acts quickly, 0.0 slowly.
    pub think_speed: f32,
    /// How much it trusts its reads of opponents (capped again by skill).
    pub read_weight: f32,
}

impl Personality {
    /// A new personality: the archetype's base parameters with jitter.
    pub fn sample(archetype: Archetype, rng: &mut BotRng) -> Personality {
        let [looseness, aggression, bluff, trap, size, speed] = archetype.base();
        let unit =
            |rng: &mut BotRng, base: f32, spread: f32| rng.jitter(base, spread).clamp(0.0, 1.0);
        Personality {
            archetype,
            looseness: unit(rng, looseness, 0.10),
            aggression: unit(rng, aggression, 0.10),
            bluff: unit(rng, bluff, 0.08),
            trap: unit(rng, trap, 0.08),
            size_habit: rng.jitter(size, 0.15).clamp(0.3, 1.2),
            tilt: unit(rng, 0.5, 0.35),
            think_speed: unit(rng, speed, 0.25),
            read_weight: unit(rng, 0.6, 0.25),
        }
    }

    /// The same style, but it trusts its reads more: used for the "rival" bots.
    #[must_use]
    pub fn rival(self) -> Personality {
        Personality {
            read_weight: (self.read_weight + 0.3).min(1.0),
            ..self
        }
    }
}

/// `count` archetypes, all different until the six are used up, then repeating in a shuffled order.
pub fn pick_archetypes(count: usize, rng: &mut BotRng) -> Vec<Archetype> {
    let mut picked = Vec::with_capacity(count);
    let mut bag: Vec<Archetype> = Vec::new();
    while picked.len() < count {
        if bag.is_empty() {
            bag.extend_from_slice(&Archetype::ALL);
        }
        let index = usize::try_from(rng.below(u32::try_from(bag.len()).unwrap_or(1))).unwrap_or(0);
        picked.push(bag.swap_remove(index));
    }
    picked
}
