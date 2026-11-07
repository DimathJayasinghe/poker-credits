//! The injectable entropy source and the unbiased shuffle.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_engine::card::Card;
use poker_engine::deck::Deck;
use poker_server_core::cards::{Entropy, EntropyError, FixedEntropy, OsEntropy, shuffled_deck};

/// Plays a fixed byte script once, then fails.
struct Script(Vec<u8>, usize);

impl Entropy for Script {
    fn fill(&mut self, buf: &mut [u8]) -> Result<(), EntropyError> {
        for byte in buf {
            *byte = *self.0.get(self.1).ok_or(EntropyError::Source)?;
            self.1 += 1;
        }
        Ok(())
    }
}

/// `SplitMix64`: a deterministic stream for the statistics test.
struct Seeded(u64);

impl Entropy for Seeded {
    fn fill(&mut self, buf: &mut [u8]) -> Result<(), EntropyError> {
        for byte in buf {
            self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
            let mut z = self.0;
            z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
            z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
            *byte = u8::try_from((z ^ (z >> 31)) & 0xFF).unwrap();
        }
        Ok(())
    }
}

struct Failing;

impl Entropy for Failing {
    fn fill(&mut self, _buf: &mut [u8]) -> Result<(), EntropyError> {
        Err(EntropyError::Source)
    }
}

#[test]
fn shuffle_is_always_a_valid_deck() {
    let mut os = OsEntropy;
    for _ in 0..200 {
        let deck = shuffled_deck(&mut os).unwrap();
        assert_eq!(deck.cards().len(), 52);
        Deck::new(deck.cards().to_vec()).unwrap();
    }
}

#[test]
fn two_os_shuffles_differ() {
    let mut os = OsEntropy;
    assert_ne!(
        shuffled_deck(&mut os).unwrap(),
        shuffled_deck(&mut os).unwrap()
    );
}

#[test]
fn same_script_gives_same_order() {
    let script: Vec<u8> = (0..=255).collect();
    let a = shuffled_deck(&mut FixedEntropy::new(script.clone())).unwrap();
    let b = shuffled_deck(&mut FixedEntropy::new(script)).unwrap();
    assert_eq!(a, b);
}

#[test]
fn rejection_sampling_skips_biased_values() {
    // For the first swap the range is 52, so bytes 208..=255 would be biased and must be skipped.
    let good: Vec<u8> = (0..200).map(|i| u8::try_from(i % 40).unwrap()).collect();
    let mut with_junk = vec![255, 250, 208];
    with_junk.extend(&good);
    let clean = shuffled_deck(&mut Script(good, 0)).unwrap();
    let skipped = shuffled_deck(&mut Script(with_junk, 0)).unwrap();
    assert_eq!(clean, skipped);
}

#[test]
fn a_source_that_only_gives_rejected_values_is_an_error_not_a_hang() {
    let result = shuffled_deck(&mut FixedEntropy::new(vec![255]));
    assert_eq!(result, Err(EntropyError::Rejected));
}

#[test]
fn entropy_failure_is_an_error_not_a_panic() {
    assert_eq!(shuffled_deck(&mut Failing), Err(EntropyError::Source));
    assert_eq!(
        shuffled_deck(&mut Script(vec![1, 2, 3], 0)),
        Err(EntropyError::Source)
    );
}

#[test]
fn position_distribution_is_flat() {
    let shuffles = 52_000_u32;
    let mut entropy = Seeded(7);
    let mut counts = vec![[0_u32; 52]; 52];
    let standard = Deck::standard();
    for _ in 0..shuffles {
        let deck = shuffled_deck(&mut entropy).unwrap();
        for (position, card) in deck.cards().iter().enumerate() {
            let id = standard
                .cards()
                .iter()
                .position(|c: &Card| c == card)
                .unwrap();
            counts[id][position] += 1;
        }
    }
    // Each cell is Binomial(52000, 1/52): mean 1000, sigma about 31; allow 6 sigma.
    for row in &counts {
        for count in row {
            assert!(
                count.abs_diff(1000) < 190,
                "count {count} is off the uniform mean"
            );
        }
    }
}
