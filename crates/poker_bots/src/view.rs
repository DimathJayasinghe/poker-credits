//! What one seat may know. This is the only input a bot's strategy receives.

use poker_engine::card::Card;
use poker_engine::validator::LegalActions;
use poker_engine::{ActionKind, HandStatus, Phase, PlayerId, SeatIndex};
use poker_engine::{blinds::Blinds, types::Chips};

/// One seat as everybody at the table can see it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SeatView {
    /// Seat number.
    pub index: SeatIndex,
    /// Who sits there.
    pub player_id: PlayerId,
    /// Chips behind.
    pub chips: Chips,
    /// Chips bet on this street.
    pub street_bet: Chips,
    /// Chips put in this hand.
    pub hand_contrib: Chips,
    /// In, folded or all-in.
    pub status: HandStatus,
    /// Sitting out of the next hands.
    pub sitting_out: bool,
}

/// One action everybody saw.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PublicAction {
    /// Who acted.
    pub seat: SeatIndex,
    /// The street it happened on.
    pub street: Phase,
    /// What they did.
    pub kind: ActionKind,
    /// Chips moved by the action.
    pub amount: Chips,
}

/// Two cards turned face up at showdown.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Reveal {
    /// Whose cards.
    pub seat: SeatIndex,
    /// The cards.
    pub hole: [Card; 2],
}

/// Everything the seat `me` knows at this moment. There is deliberately no field for the deck,
/// the undealt cards or another seat's hole cards.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BotView {
    /// The seat this view belongs to.
    pub me: SeatIndex,
    /// My two cards.
    pub hole: [Card; 2],
    /// Community cards shown so far.
    pub board: Vec<Card>,
    /// Current street.
    pub phase: Phase,
    /// Chips in the middle (all pots and the street's bets).
    pub pot_total: Chips,
    /// Every seat, in seat order.
    pub seats: Vec<SeatView>,
    /// The button.
    pub button: Option<SeatIndex>,
    /// What it costs me to call.
    pub to_call: Chips,
    /// What I may do now.
    pub legal: LegalActions,
    /// Blinds of this hand.
    pub blinds: Blinds,
    /// 1-based hand counter.
    pub hand_number: u32,
    /// The public betting of this hand so far.
    pub history: Vec<PublicAction>,
}

impl BotView {
    /// How many other players are still in the hand.
    #[must_use]
    pub fn opponents_in_hand(&self) -> usize {
        self.seats
            .iter()
            .filter(|s| {
                s.index != self.me && matches!(s.status, HandStatus::Live | HandStatus::AllIn)
            })
            .count()
    }

    /// My own seat.
    #[must_use]
    pub fn my_seat(&self) -> Option<&SeatView> {
        self.seats.iter().find(|s| s.index == self.me)
    }

    /// My chips behind.
    #[must_use]
    pub fn my_chips(&self) -> Chips {
        self.my_seat().map_or(Chips::ZERO, |s| s.chips)
    }
}
