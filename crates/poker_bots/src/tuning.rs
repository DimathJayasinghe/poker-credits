//! The numbers behind a bot's judgement, gathered in one vector so they can be learned.
//!
//! [`Tuning::BASE`] is what was set by hand. [`Tuning::LEARNED`] (Easy and Normal) and
//! [`Tuning::LEARNED_HARD`] are what the self-play trainer (`examples/train.rs`) found: an
//! evolution strategy plays candidate vectors, as a Tag-style bot of the level being trained,
//! against a fixed field of the other five styles, and keeps the ones that win more chips without
//! leaving the style envelope (how often the bot plays, how often it folds to bets). The learned
//! vectors are copied here by hand, so the shipped bots are deterministic and need no training at
//! run time. The simulations feed every bot the whole table's betting, as the live room does, so
//! the trainer sees the same reads and ranges the game has.

/// How many numbers a tuning has.
pub const PARAMS: usize = 19;

/// One tunable number: its name, hand-set value, and the range the trainer may move it in.
#[derive(Clone, Copy, Debug)]
pub struct Param {
    /// Name, for reports.
    pub name: &'static str,
    /// The hand-set value.
    pub base: f32,
    /// Lowest value the trainer may try.
    pub min: f32,
    /// Highest value the trainer may try.
    pub max: f32,
}

const fn p(name: &'static str, base: f32, min: f32, max: f32) -> Param {
    Param {
        name,
        base,
        min,
        max,
    }
}

/// The parameters, in the order of [`Tuning::v`].
pub const SPEC: [Param; PARAMS] = [
    p("pre_play", 0.3187, 0.30, 0.52),
    p("pre_slope", 0.1319, 0.05, 0.35),
    p("pre_raise", 0.4578, 0.05, 0.50),
    p("pre_premium", 0.0240, 0.00, 0.20),
    p("pre_heat", 0.4462, 0.10, 0.60),
    p("pre_committed", 0.1928, 0.00, 0.30),
    p("pre_raise_floor", 0.7219, 0.60, 0.85),
    p("post_value", 0.50, 0.38, 0.70),
    p("post_many", 0.045, 0.02, 0.07),
    p("post_margin", 0.00, -0.12, 0.12),
    p("post_commit", 0.08, 0.00, 0.15),
    p("post_raise_edge", 0.14, 0.05, 0.25),
    p("cbet", 0.25, 0.00, 0.50),
    p("cbet_aggr", 0.40, 0.00, 0.60),
    p("bet_size", 1.00, 0.60, 1.40),
    p("bluff_scale", 1.00, 0.40, 2.00),
    p("pos_margin", 0.03, 0.00, 0.08),
    p("thin_ip", 0.30, 0.00, 0.60),
    p("semi_bluff", 0.35, 0.00, 0.80),
];

/// The judgement numbers of a bot.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Tuning {
    /// The numbers, in the order of [`SPEC`].
    pub v: [f32; PARAMS],
}

impl Tuning {
    /// The hand-set values.
    pub const BASE: Tuning = Tuning {
        v: [
            0.3187, 0.1319, 0.4578, 0.0240, 0.4462, 0.1928, 0.7219, 0.50, 0.045, 0.00, 0.08, 0.14,
            0.25, 0.40, 1.00, 1.00, 0.03, 0.30, 0.35,
        ],
    };

    /// What the trainer learned for Easy and Normal (`TRAIN_SKILL=normal train 30 3000 21`). The
    /// preflop numbers (the first seven) stay as set: they keep the six styles at a human scale
    /// and are the ones the owner has already played against. The trainer learns the play after
    /// the flop.
    pub const LEARNED: Tuning = Tuning {
        v: [
            0.3187, 0.1319, 0.4578, 0.0240, 0.4462, 0.1928, 0.7219, 0.5258, 0.0616, -0.0241,
            0.0795, 0.1815, 0.3348, 0.2798, 1.0397, 0.8415, 0.0166, 0.4243, 0.4519,
        ],
    };

    /// What the trainer learned for Hard (`TRAIN_SKILL=hard train 30 3000 22`, same frozen
    /// preflop numbers).
    pub const LEARNED_HARD: Tuning = Tuning {
        v: [
            0.3187, 0.1319, 0.4578, 0.0240, 0.4462, 0.1928, 0.7219, 0.4740, 0.0684, -0.0350,
            0.0547, 0.1347, 0.2947, 0.5595, 1.1041, 0.8795, 0.0563, 0.3955, 0.2033,
        ],
    };

    /// The same numbers moved to stay inside their ranges.
    #[must_use]
    pub fn clamped(mut self) -> Tuning {
        for (value, spec) in self.v.iter_mut().zip(SPEC.iter()) {
            *value = value.clamp(spec.min, spec.max);
        }
        self
    }

    /// One number by index (see [`idx`]); a missing index reads as zero, which cannot happen
    /// because [`SPEC`] and [`Tuning::v`] have the same length.
    #[must_use]
    pub fn at(&self, index: usize) -> f32 {
        self.v.get(index).copied().unwrap_or(0.0)
    }

    /// Looks up one named number (tests and reports).
    #[must_use]
    pub fn get(&self, name: &str) -> Option<f32> {
        SPEC.iter()
            .position(|s| s.name == name)
            .and_then(|i| self.v.get(i).copied())
    }
}

impl Tuning {
    /// The numbers a bot of this level plays with.
    #[must_use]
    pub fn for_skill(skill: crate::skill::Skill) -> Tuning {
        match skill {
            crate::skill::Skill::Hard => Tuning::LEARNED_HARD,
            crate::skill::Skill::Easy | crate::skill::Skill::Normal => Tuning::LEARNED,
        }
    }
}

impl Default for Tuning {
    fn default() -> Self {
        Tuning::LEARNED
    }
}

/// Index of each parameter (kept next to [`SPEC`] so the two cannot drift: a test checks it).
pub mod idx {
    /// `pre_play`
    pub const PRE_PLAY: usize = 0;
    /// `pre_slope`
    pub const PRE_SLOPE: usize = 1;
    /// `pre_raise`
    pub const PRE_RAISE: usize = 2;
    /// `pre_premium`
    pub const PRE_PREMIUM: usize = 3;
    /// `pre_heat`
    pub const PRE_HEAT: usize = 4;
    /// `pre_committed`
    pub const PRE_COMMITTED: usize = 5;
    /// `pre_raise_floor`
    pub const PRE_RAISE_FLOOR: usize = 6;
    /// `post_value`
    pub const POST_VALUE: usize = 7;
    /// `post_many`
    pub const POST_MANY: usize = 8;
    /// `post_margin`
    pub const POST_MARGIN: usize = 9;
    /// `post_commit`
    pub const POST_COMMIT: usize = 10;
    /// `post_raise_edge`
    pub const POST_RAISE_EDGE: usize = 11;
    /// `cbet`
    pub const CBET: usize = 12;
    /// `cbet_aggr`
    pub const CBET_AGGR: usize = 13;
    /// `bet_size`
    pub const BET_SIZE: usize = 14;
    /// `bluff_scale`
    pub const BLUFF_SCALE: usize = 15;
    /// `pos_margin`
    pub const POS_MARGIN: usize = 16;
    /// `thin_ip`
    pub const THIN_IP: usize = 17;
    /// `semi_bluff`
    pub const SEMI_BLUFF: usize = 18;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base_matches_the_spec_and_indices_are_in_order() {
        for (i, spec) in SPEC.iter().enumerate() {
            assert!(
                (Tuning::BASE.v[i] - spec.base).abs() < 1e-6,
                "{}",
                spec.name
            );
            assert!(
                spec.min <= spec.base && spec.base <= spec.max,
                "{}",
                spec.name
            );
        }
        assert_eq!(SPEC[idx::PRE_PLAY].name, "pre_play");
        assert_eq!(SPEC[idx::BLUFF_SCALE].name, "bluff_scale");
        assert_eq!(SPEC[idx::CBET].name, "cbet");
        assert_eq!(SPEC[idx::POST_COMMIT].name, "post_commit");
        assert_eq!(Tuning::BASE.clamped(), Tuning::BASE);
    }
}
