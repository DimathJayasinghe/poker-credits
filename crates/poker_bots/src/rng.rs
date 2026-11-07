//! A small deterministic generator (splitmix64). Not for shuffling real decks (that is
//! `poker_server_core::cards`, from the OS); it only drives a bot's choices. The server seeds each
//! bot from OS entropy; tests use a fixed seed. No `rand` dependency (approved list, ADR-018).

/// Pseudo-random numbers for one bot.
#[derive(Clone, Debug)]
pub struct BotRng {
    state: u64,
}

impl BotRng {
    /// A generator that always produces the same stream for the same seed.
    #[must_use]
    pub const fn from_seed(seed: u64) -> BotRng {
        BotRng { state: seed }
    }

    /// The next 64 random bits.
    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// A uniform number in `0..bound` (zero when `bound` is zero), without modulo bias.
    pub fn below(&mut self, bound: u32) -> u32 {
        if bound <= 1 {
            return 0;
        }
        let bound = u64::from(bound);
        let limit = u64::MAX - (u64::MAX % bound);
        loop {
            let value = self.next_u64();
            if value < limit {
                return u32::try_from(value % bound).unwrap_or(0);
            }
        }
    }

    /// A uniform number in `0.0..1.0`.
    pub fn unit(&mut self) -> f32 {
        #[allow(
            clippy::cast_precision_loss,
            reason = "24 random bits fill an f32 mantissa exactly"
        )]
        {
            (self.next_u64() >> 40) as f32 / 16_777_216.0
        }
    }

    /// True with probability `p` (clamped to 0..=1).
    pub fn chance(&mut self, p: f32) -> bool {
        self.unit() < p.clamp(0.0, 1.0)
    }

    /// `base` plus a uniform offset in `-spread..=spread`.
    pub fn jitter(&mut self, base: f32, spread: f32) -> f32 {
        base + (self.unit() * 2.0 - 1.0) * spread
    }
}
