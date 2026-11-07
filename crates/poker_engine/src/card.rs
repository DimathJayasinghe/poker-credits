//! Playing cards. Value objects: a [`Card`] always has a valid rank and suit, and its text form
//! (`"As"`, `"Td"`, `"2c"`) is the wire format (`docs/API_AND_EVENTS.md` section 9).

use std::fmt;
use std::str::FromStr;

use serde::de::{self, Deserializer};
use serde::{Deserialize, Serialize, Serializer};
use thiserror::Error;

/// A card rank, ordered from deuce to ace.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Rank {
    /// 2
    Two = 2,
    /// 3
    Three,
    /// 4
    Four,
    /// 5
    Five,
    /// 6
    Six,
    /// 7
    Seven,
    /// 8
    Eight,
    /// 9
    Nine,
    /// 10 (written `T` on the wire)
    Ten,
    /// Jack
    Jack,
    /// Queen
    Queen,
    /// King
    King,
    /// Ace (high; low only inside the wheel straight)
    Ace,
}

impl Rank {
    /// Every rank, lowest first.
    pub const ALL: [Rank; 13] = [
        Rank::Two,
        Rank::Three,
        Rank::Four,
        Rank::Five,
        Rank::Six,
        Rank::Seven,
        Rank::Eight,
        Rank::Nine,
        Rank::Ten,
        Rank::Jack,
        Rank::Queen,
        Rank::King,
        Rank::Ace,
    ];

    /// 2 for a deuce up to 14 for an ace.
    #[must_use]
    pub const fn value(self) -> u8 {
        self as u8
    }

    /// The rank with this value (2 to 14).
    #[must_use]
    pub fn from_value(value: u8) -> Option<Rank> {
        Rank::ALL.iter().copied().find(|rank| rank.value() == value)
    }

    const fn to_char(self) -> char {
        match self {
            Rank::Two => '2',
            Rank::Three => '3',
            Rank::Four => '4',
            Rank::Five => '5',
            Rank::Six => '6',
            Rank::Seven => '7',
            Rank::Eight => '8',
            Rank::Nine => '9',
            Rank::Ten => 'T',
            Rank::Jack => 'J',
            Rank::Queen => 'Q',
            Rank::King => 'K',
            Rank::Ace => 'A',
        }
    }

    fn from_char(c: char) -> Option<Rank> {
        Rank::ALL.iter().copied().find(|rank| rank.to_char() == c)
    }
}

/// A card suit. Suits never break ties in poker; the order is only for stable sorting.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Suit {
    /// Clubs (`c`)
    Clubs,
    /// Diamonds (`d`)
    Diamonds,
    /// Hearts (`h`)
    Hearts,
    /// Spades (`s`)
    Spades,
}

impl Suit {
    /// Every suit.
    pub const ALL: [Suit; 4] = [Suit::Clubs, Suit::Diamonds, Suit::Hearts, Suit::Spades];

    const fn to_char(self) -> char {
        match self {
            Suit::Clubs => 'c',
            Suit::Diamonds => 'd',
            Suit::Hearts => 'h',
            Suit::Spades => 's',
        }
    }

    fn from_char(c: char) -> Option<Suit> {
        Suit::ALL.iter().copied().find(|suit| suit.to_char() == c)
    }
}

/// A playing card.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Card {
    /// Rank.
    pub rank: Rank,
    /// Suit.
    pub suit: Suit,
}

impl Card {
    /// A card from its parts.
    #[must_use]
    pub const fn new(rank: Rank, suit: Suit) -> Card {
        Card { rank, suit }
    }
}

impl fmt::Display for Card {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}{}", self.rank.to_char(), self.suit.to_char())
    }
}

impl fmt::Debug for Card {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, f)
    }
}

/// A string that is not a card such as `"As"`.
#[derive(Clone, Debug, PartialEq, Eq, Error)]
#[error("not a card: {0:?}")]
pub struct ParseCardError(String);

impl FromStr for Card {
    type Err = ParseCardError;

    fn from_str(text: &str) -> Result<Self, Self::Err> {
        let bad = || ParseCardError(text.chars().take(8).collect());
        let mut chars = text.chars();
        let rank = chars.next().and_then(Rank::from_char).ok_or_else(bad)?;
        let suit = chars.next().and_then(Suit::from_char).ok_or_else(bad)?;
        if chars.next().is_some() {
            return Err(bad());
        }
        Ok(Card { rank, suit })
    }
}

impl Serialize for Card {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.collect_str(self)
    }
}

impl<'de> Deserialize<'de> for Card {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let text = String::deserialize(deserializer)?;
        text.parse().map_err(de::Error::custom)
    }
}
