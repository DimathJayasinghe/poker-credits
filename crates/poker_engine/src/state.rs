//! Serialisable table state. Everything a snapshot needs, including undo history, lives here, so
//! a room restored from a snapshot behaves exactly like the live one. No `HashMap`/`HashSet`:
//! iteration order must be identical in every process.

use serde::{Deserialize, Serialize};

use crate::blinds::{Blinds, BlindsMode, BlindsStrategy};
use crate::error::PokerError;
use crate::types::{Chips, Phase, PlayerId, SeatIndex};
use crate::validator::{self, LegalActions};

/// Consecutive timeouts after which a player is sat out at the end of the hand.
pub const AWAY_AFTER_MISSED_TURNS: u8 = 2;

/// A seat's role in the current hand.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum HandStatus {
    /// Not dealt into the current hand (or no hand running).
    Out,
    /// In the hand with chips behind.
    Live,
    /// Folded this hand.
    Folded,
    /// In the hand with no chips left to bet.
    AllIn,
}

/// One seat at the table.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Seat {
    /// Seat position.
    pub index: SeatIndex,
    /// Occupant.
    pub player_id: PlayerId,
    /// Chips behind (not yet bet).
    pub chips: Chips,
    /// Chips put in on the current street.
    pub street_bet: Chips,
    /// Chips put in during the whole hand, antes included.
    pub hand_contrib: Chips,
    /// Role in the current hand.
    pub status: HandStatus,
    /// Skipped when dealing the next hand.
    pub sitting_out: bool,
    /// Raise count this seat last acted at; `None` if it has not acted on this street.
    pub acted_at_raise: Option<u32>,
    /// Turns in a row that ran out of time. Any real action resets it; at
    /// [`AWAY_AFTER_MISSED_TURNS`] the seat is sat out when the hand ends.
    #[serde(default)]
    pub missed_turns: u8,
}

impl Seat {
    /// A fresh seat that is not yet in a hand.
    #[must_use]
    pub fn new(index: SeatIndex, player_id: PlayerId, chips: Chips) -> Self {
        Seat {
            index,
            player_id,
            chips,
            street_bet: Chips::ZERO,
            hand_contrib: Chips::ZERO,
            status: HandStatus::Out,
            sitting_out: false,
            acted_at_raise: None,
            missed_turns: 0,
        }
    }

    /// Can be dealt into the next hand.
    #[must_use]
    pub fn is_eligible(&self) -> bool {
        !self.chips.is_zero() && !self.sitting_out
    }

    /// Still contesting the pot (not folded, dealt in).
    #[must_use]
    pub fn is_contesting(&self) -> bool {
        matches!(self.status, HandStatus::Live | HandStatus::AllIn)
    }

    /// Owes an action on the current street.
    #[must_use]
    pub fn needs_action(&self, current_bet: Chips) -> bool {
        self.status == HandStatus::Live
            && (self.acted_at_raise.is_none() || self.street_bet < current_bet)
    }
}

/// One pot (main or side) with the seats allowed to win it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PotTier {
    /// 0 is the main pot, higher indices are side pots.
    pub tier_index: u32,
    /// Chips in the pot.
    pub amount: Chips,
    /// Seats that can win it, ascending.
    pub eligible: Vec<SeatIndex>,
}

/// The full table without undo history.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Table {
    /// Blind structure used for new hands.
    pub blinds: BlindsMode,
    /// Blinds of the hand in progress.
    pub hand_blinds: Blinds,
    /// Seats, ascending by index.
    pub seats: Vec<Seat>,
    /// Hand lifecycle phase.
    pub phase: Phase,
    /// Host pause; kept apart from `phase` so resume restores it exactly.
    pub paused: bool,
    /// Hands dealt so far.
    pub hand_number: u32,
    /// Button seat (may be a dead button with no live player).
    pub dealer: Option<SeatIndex>,
    /// Small blind seat; `None` for a dead small blind.
    pub small_blind_seat: Option<SeatIndex>,
    /// Big blind seat; kept after the hand so the next big blind rotates from it.
    pub big_blind_seat: Option<SeatIndex>,
    /// Seat to act now.
    pub active: Option<SeatIndex>,
    /// Highest street total any seat has put in.
    pub current_bet: Chips,
    /// Size of the last full bet or raise (the minimum raise increment).
    pub last_raise_delta: Chips,
    /// Number of times betting was (re)opened on this street: full raises, plus short all-ins that
    /// together added up to a full raise.
    pub raise_count: u32,
    /// Chips added to the bet by short all-ins since betting was last opened.
    pub short_raise_total: Chips,
    /// Pots fixed when betting ended (empty during betting).
    pub pots: Vec<PotTier>,
}

impl Table {
    /// Seat by position.
    #[must_use]
    pub fn seat(&self, index: SeatIndex) -> Option<&Seat> {
        self.seats.iter().find(|seat| seat.index == index)
    }

    /// Mutable seat by position.
    pub fn seat_mut(&mut self, index: SeatIndex) -> Option<&mut Seat> {
        self.seats.iter_mut().find(|seat| seat.index == index)
    }

    /// Seat by occupant.
    #[must_use]
    pub fn seat_of(&self, player_id: &PlayerId) -> Option<&Seat> {
        self.seats.iter().find(|seat| &seat.player_id == player_id)
    }

    /// Every seat clockwise starting after `from`, with `from` itself last (if it exists).
    pub fn seats_after(&self, from: SeatIndex) -> impl Iterator<Item = &Seat> + '_ {
        self.seats
            .iter()
            .filter(move |seat| seat.index > from)
            .chain(self.seats.iter().filter(move |seat| seat.index <= from))
    }

    /// Chips behind plus chips in the pot: constant for the life of the table (apart from
    /// buy-ins and top-ups).
    #[must_use]
    pub fn total_chips(&self) -> u64 {
        self.seats
            .iter()
            .map(|seat| seat.chips.get().saturating_add(seat.hand_contrib.get()))
            .sum()
    }

    /// Chips committed to the pot this hand.
    #[must_use]
    pub fn total_pot(&self) -> Chips {
        self.seats.iter().fold(Chips::ZERO, |sum, seat| {
            sum.saturating_add(seat.hand_contrib)
        })
    }

    /// Number of seats still contesting the pot.
    #[must_use]
    pub fn contesting_count(&self) -> usize {
        self.seats
            .iter()
            .filter(|seat| seat.is_contesting())
            .count()
    }
}

/// Table plus a bounded stack of previous tables for undo.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameState {
    /// Current table.
    pub table: Table,
    /// Previous tables, oldest first (see [`crate::undo::UNDO_DEPTH`]).
    pub history: Vec<Table>,
}

impl GameState {
    /// An empty lobby with the given blind structure.
    ///
    /// # Errors
    /// [`PokerError::InvalidAmount`] if the blinds are unplayable.
    pub fn new(blinds: BlindsMode) -> Result<Self, PokerError> {
        blinds.validate()?;
        let hand_blinds = blinds.blinds(1, 0);
        Ok(GameState {
            table: Table {
                blinds,
                hand_blinds,
                seats: Vec::new(),
                phase: Phase::Lobby,
                paused: false,
                hand_number: 0,
                dealer: None,
                small_blind_seat: None,
                big_blind_seat: None,
                active: None,
                current_bet: Chips::ZERO,
                last_raise_delta: Chips::ZERO,
                raise_count: 0,
                short_raise_total: Chips::ZERO,
                pots: Vec::new(),
            },
            history: Vec::new(),
        })
    }

    /// The acting seat and what it may do, for `TURN_PROMPT`.
    #[must_use]
    pub fn legal_actions(&self) -> Option<(SeatIndex, LegalActions)> {
        if self.table.paused || !self.table.phase.is_betting() {
            return None;
        }
        let index = self.table.active?;
        let seat = self.table.seat(index)?;
        Some((index, validator::legal_actions(&self.table, seat)))
    }
}
