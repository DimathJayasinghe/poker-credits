//! The cards of one virtual hand: who holds what, how much of the board is shown, who has
//! revealed, and (once the hand is paid) the result. Everything is keyed by [`PlayerId`], never by
//! seat: between hands the host can move seats, guests can take freed seats and players can leave,
//! all while the deal and result are still on screen.

use std::fmt;

use serde::{Deserialize, Serialize};

use crate::card::Card;
use crate::deck::Deck;
use crate::error::PokerError;
use crate::types::{Chips, PlayerId};

/// Board cards in a complete hand.
pub const BOARD_SIZE: usize = 5;

/// [`BOARD_SIZE`] as a count of shown cards.
const BOARD_CARDS: u8 = 5;

/// What one pot paid and to whom.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PotResult {
    /// 0 is the main pot.
    pub pot_index: u32,
    /// Chips in the pot.
    pub amount: Chips,
    /// Everyone who shared the pot.
    pub winners: Vec<PlayerId>,
    /// What each winner received (the odd chip makes shares differ by one).
    pub shares: Vec<(PlayerId, Chips)>,
}

/// How a paid hand ended.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HandResult {
    /// Everyone else folded; no hands were compared or revealed.
    pub uncontested: bool,
    /// One entry per pot, main pot first.
    pub pots: Vec<PotResult>,
}

/// The deal of the current (or just finished) virtual hand.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Deal {
    /// Hand this deal belongs to.
    pub hand_number: u32,
    /// Two hole cards per dealt player.
    pub holes: Vec<(PlayerId, [Card; 2])>,
    /// The whole board, hidden until revealed.
    pub board: [Card; BOARD_SIZE],
    /// How many board cards everyone may see (0, 3, 4 or 5).
    pub board_shown: u8,
    /// Players whose hole cards are public (showdown).
    pub revealed: Vec<PlayerId>,
    /// Set once the hand is paid.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub result: Option<HandResult>,
}

impl Deal {
    /// Deals from the top of `deck`: two cards to each player in the order given (clockwise from
    /// the button), then five board cards.
    ///
    /// # Errors
    /// [`PokerError::InvalidDeck`] if the deck cannot cover the players (never for 10 seats).
    pub fn from_deck(
        deck: &Deck,
        players: &[PlayerId],
        hand_number: u32,
    ) -> Result<Deal, PokerError> {
        let mut cards = deck.cards().iter().copied();
        let mut holes = Vec::with_capacity(players.len());
        for player in players {
            let (Some(first), Some(second)) = (cards.next(), cards.next()) else {
                return Err(PokerError::InvalidDeck);
            };
            holes.push((player.clone(), [first, second]));
        }
        let board: Vec<Card> = cards.take(BOARD_SIZE).collect();
        let board = <[Card; BOARD_SIZE]>::try_from(board).map_err(|_| PokerError::InvalidDeck)?;
        Ok(Deal {
            hand_number,
            holes,
            board,
            board_shown: 0,
            revealed: Vec::new(),
            result: None,
        })
    }

    /// The board cards everyone may see.
    #[must_use]
    pub fn visible_board(&self) -> &[Card] {
        self.board
            .get(..usize::from(self.board_shown))
            .unwrap_or(&[])
    }

    /// A player's hole cards, if they were dealt in.
    #[must_use]
    pub fn hole_of(&self, player: &PlayerId) -> Option<[Card; 2]> {
        self.holes
            .iter()
            .find(|(id, _)| id == player)
            .map(|(_, cards)| *cards)
    }

    /// Shows the board up to `count` cards and returns the newly visible ones.
    pub fn show_board_to(&mut self, count: u8) -> Vec<Card> {
        let count = count.min(BOARD_CARDS);
        if count <= self.board_shown {
            return Vec::new();
        }
        let newly = self
            .board
            .get(usize::from(self.board_shown)..usize::from(count))
            .map(<[Card]>::to_vec)
            .unwrap_or_default();
        self.board_shown = count;
        newly
    }
}

/// Deliberately opaque: hole cards are secret while a hand is in progress.
impl fmt::Debug for Deal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Deal")
            .field("hand_number", &self.hand_number)
            .field("dealt", &self.holes.len())
            .field("board_shown", &self.board_shown)
            .field("revealed", &self.revealed.len())
            .finish_non_exhaustive()
    }
}
