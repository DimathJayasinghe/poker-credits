//! A validated 52-card deck order. The engine never shuffles: the server draws the order from
//! its entropy source and passes it in, and the journal records it (ADR-016).

use serde::{Deserialize, Serialize};

use crate::card::{Card, Rank, Suit};
use crate::error::PokerError;

/// Number of cards in a deck.
pub const DECK_SIZE: usize = 52;

/// Exactly 52 distinct cards in dealing order.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "Vec<Card>", into = "Vec<Card>")]
pub struct Deck(Vec<Card>);

impl Deck {
    /// Checks that `order` holds each of the 52 cards exactly once.
    ///
    /// # Errors
    /// [`PokerError::InvalidDeck`] otherwise.
    pub fn new(order: Vec<Card>) -> Result<Deck, PokerError> {
        if order.len() != DECK_SIZE {
            return Err(PokerError::InvalidDeck);
        }
        let mut sorted = order.clone();
        sorted.sort_unstable();
        sorted.dedup();
        if sorted.len() != DECK_SIZE {
            return Err(PokerError::InvalidDeck);
        }
        Ok(Deck(order))
    }

    /// The cards in sorted order (for tests and as a shuffle's starting point).
    #[must_use]
    pub fn standard() -> Deck {
        let cards = Suit::ALL
            .iter()
            .flat_map(|suit| Rank::ALL.iter().map(move |rank| Card::new(*rank, *suit)))
            .collect();
        Deck(cards)
    }

    /// The cards in dealing order.
    #[must_use]
    pub fn cards(&self) -> &[Card] {
        &self.0
    }
}

impl TryFrom<Vec<Card>> for Deck {
    type Error = PokerError;

    fn try_from(order: Vec<Card>) -> Result<Self, Self::Error> {
        Deck::new(order)
    }
}

impl From<Deck> for Vec<Card> {
    fn from(deck: Deck) -> Self {
        deck.0
    }
}

/// Deliberately opaque: a deck is secret while a hand is in progress.
impl std::fmt::Debug for Deck {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Deck(<redacted>)")
    }
}
