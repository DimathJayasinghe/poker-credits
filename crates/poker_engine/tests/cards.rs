//! Playing cards and the validated deck.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_engine::PokerError;
use poker_engine::card::{Card, Rank, Suit};
use poker_engine::deck::Deck;

#[test]
fn card_round_trips_all_52_strings() {
    let deck = Deck::standard();
    assert_eq!(deck.cards().len(), 52);
    for card in deck.cards() {
        let text = card.to_string();
        assert_eq!(text.len(), 2, "{text}");
        assert_eq!(text.parse::<Card>().unwrap(), *card);
    }
}

#[test]
fn display_uses_rank_then_suit_letter() {
    let ace_spades = Card::new(Rank::Ace, Suit::Spades);
    assert_eq!(ace_spades.to_string(), "As");
    assert_eq!(Card::new(Rank::Ten, Suit::Diamonds).to_string(), "Td");
    assert_eq!(Card::new(Rank::Two, Suit::Clubs).to_string(), "2c");
}

#[test]
fn from_str_rejects_bad_input() {
    for bad in ["1s", "Ax", "a", "Asx", "", "AS", "as ", " As", "10s", "Zh"] {
        assert!(bad.parse::<Card>().is_err(), "{bad:?} should be rejected");
    }
}

#[test]
fn deck_rejects_51_cards() {
    let mut cards = Deck::standard().cards().to_vec();
    cards.pop();
    assert_eq!(Deck::new(cards), Err(PokerError::InvalidDeck));
}

#[test]
fn deck_rejects_duplicate() {
    let mut cards = Deck::standard().cards().to_vec();
    cards[51] = cards[0];
    assert_eq!(Deck::new(cards), Err(PokerError::InvalidDeck));
}

#[test]
fn deck_accepts_a_permutation() {
    let mut cards = Deck::standard().cards().to_vec();
    cards.reverse();
    let deck = Deck::new(cards.clone()).unwrap();
    assert_eq!(deck.cards(), cards.as_slice());
}

#[test]
fn serde_json_of_card_is_a_plain_string() {
    let card = Card::new(Rank::King, Suit::Hearts);
    assert_eq!(serde_json::to_string(&card).unwrap(), "\"Kh\"");
    let back: Card = serde_json::from_str("\"Kh\"").unwrap();
    assert_eq!(back, card);
    assert!(serde_json::from_str::<Card>("\"Kx\"").is_err());
}

#[test]
fn deck_deserialization_validates() {
    let deck = Deck::standard();
    let json = serde_json::to_string(&deck).unwrap();
    assert_eq!(serde_json::from_str::<Deck>(&json).unwrap(), deck);
    assert!(serde_json::from_str::<Deck>("[\"As\",\"As\"]").is_err());
}
