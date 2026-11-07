//! Randomness for virtual-card rooms. The engine never shuffles; the room actor draws a deck here
//! and the journal records it, so replay and restore never need randomness (ADR-016).

use poker_engine::card::Card;
use poker_engine::deck::{DECK_SIZE, Deck};
use thiserror::Error;

/// Consecutive rejected bytes after which a source is declared broken instead of looping.
const MAX_REJECTIONS: u32 = 256;

/// Why a deck could not be drawn.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Error)]
pub enum EntropyError {
    /// The random source failed.
    #[error("the random source failed")]
    Source,
    /// The source gave only values that the unbiased shuffle must reject.
    #[error("the random source gave only unusable values")]
    Rejected,
}

/// A source of random bytes (Strategy). Production uses the OS; tests inject a script.
pub trait Entropy: Send {
    /// Fills `buf` with random bytes.
    ///
    /// # Errors
    /// [`EntropyError::Source`] if no randomness could be produced.
    fn fill(&mut self, buf: &mut [u8]) -> Result<(), EntropyError>;
}

/// Operating-system entropy via `getrandom`.
#[derive(Clone, Copy, Debug, Default)]
pub struct OsEntropy;

impl Entropy for OsEntropy {
    fn fill(&mut self, buf: &mut [u8]) -> Result<(), EntropyError> {
        getrandom::fill(buf).map_err(|_| EntropyError::Source)
    }
}

/// Replays a byte script forever. For tests that need a known deck: never use it for a real room.
#[derive(Clone, Debug)]
pub struct FixedEntropy {
    script: Vec<u8>,
    position: usize,
}

impl FixedEntropy {
    /// A source that repeats `script`.
    #[must_use]
    pub fn new(script: Vec<u8>) -> FixedEntropy {
        FixedEntropy {
            script,
            position: 0,
        }
    }
}

impl Entropy for FixedEntropy {
    fn fill(&mut self, buf: &mut [u8]) -> Result<(), EntropyError> {
        for byte in buf {
            let value = self
                .script
                .get(self.position % self.script.len().max(1))
                .ok_or(EntropyError::Source)?;
            *byte = *value;
            self.position = self.position.wrapping_add(1);
        }
        Ok(())
    }
}

/// A uniform number in `0..bound` (1 to 255) by rejection sampling, so no value is more likely.
fn below(entropy: &mut dyn Entropy, bound: usize) -> Result<usize, EntropyError> {
    let bound = u16::try_from(bound).map_err(|_| EntropyError::Source)?;
    let limit = 256 - (256 % bound);
    for _ in 0..MAX_REJECTIONS {
        let mut byte = [0_u8; 1];
        entropy.fill(&mut byte)?;
        let value = u16::from(byte[0]);
        if value < limit {
            return Ok(usize::from(value % bound));
        }
    }
    Err(EntropyError::Rejected)
}

/// A fresh 52-card deck in uniformly random order (Fisher-Yates).
///
/// # Errors
/// [`EntropyError`] if the source fails or is unusable.
pub fn shuffled_deck(entropy: &mut dyn Entropy) -> Result<Deck, EntropyError> {
    let mut cards: Vec<Card> = Deck::standard().cards().to_vec();
    for end in (1..DECK_SIZE).rev() {
        let pick = below(entropy, end + 1)?;
        cards.swap(end, pick);
    }
    Deck::new(cards).map_err(|_| EntropyError::Source)
}
