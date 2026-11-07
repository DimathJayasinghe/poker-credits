//! Facts the server turns into wire messages, tickers and sounds. The engine knows no sockets.

use serde::{Deserialize, Serialize};

use crate::card::Card;
use crate::state::PotTier;
use crate::types::{Chips, Phase, PlayerId, SeatIndex};

/// What an action was, for the ticker.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ActionKind {
    /// Folded.
    Fold,
    /// Checked.
    Check,
    /// Called.
    Call,
    /// Opened the betting.
    Bet,
    /// Raised.
    Raise,
}

/// A forced bet.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BlindKind {
    /// Ante.
    Ante,
    /// Small blind.
    SmallBlind,
    /// Big blind.
    BigBlind,
}

/// Something that happened while applying a command.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
pub enum Event {
    /// A player was seated.
    PlayerAdded {
        /// New player.
        player_id: PlayerId,
        /// Their seat.
        seat: SeatIndex,
    },
    /// A player changed seat (once per player; a swap emits two events).
    SeatMoved {
        /// Player who moved.
        player_id: PlayerId,
        /// Seat they left.
        from: SeatIndex,
        /// Seat they now hold.
        to: SeatIndex,
    },
    /// A player was removed. Their stack leaves the table, so the server must credit `chips` to
    /// the room ledger or the credits vanish.
    PlayerRemoved {
        /// Removed player.
        player_id: PlayerId,
        /// Chips they took away.
        chips: Chips,
    },
    /// A player's sit-out flag changed.
    SittingOutChanged {
        /// Player.
        player_id: PlayerId,
        /// New flag.
        sitting_out: bool,
    },
    /// A player missed too many turns in a row and was sat out. The server starts the presence
    /// check clock for them.
    PlayerAway {
        /// Player who is now sitting out.
        player_id: PlayerId,
    },
    /// Chips were added to a stack.
    RebuyApplied {
        /// Player.
        player_id: PlayerId,
        /// Chips added.
        amount: Chips,
    },
    /// The blind structure changed.
    BlindsConfigured,
    /// A hand was dealt.
    HandStarted {
        /// 1-based hand counter.
        hand_number: u32,
        /// Button seat.
        dealer: SeatIndex,
        /// Small blind seat, `None` for a dead small blind.
        small_blind: Option<SeatIndex>,
        /// Big blind seat.
        big_blind: SeatIndex,
    },
    /// A forced bet was posted.
    BlindPosted {
        /// Who posted.
        player_id: PlayerId,
        /// Which forced bet.
        blind: BlindKind,
        /// Chips posted (less than the blind if the stack was short).
        amount: Chips,
    },
    /// A player acted.
    ActionPerformed {
        /// Who acted.
        player_id: PlayerId,
        /// What they did.
        action: ActionKind,
        /// Chips moved by this action.
        amount: Chips,
        /// Street total after the action.
        street_total: Chips,
        /// Chips left behind.
        chips_remaining: Chips,
        /// The action used the last chip.
        all_in: bool,
        /// Chosen by the engine after a timeout.
        auto: bool,
    },
    /// It is now this seat's turn.
    TurnStarted {
        /// Seat to act.
        seat: SeatIndex,
        /// Occupant.
        player_id: PlayerId,
    },
    /// The street changed.
    PhaseChanged {
        /// New phase.
        phase: Phase,
    },
    /// An unmatched bet went back to its owner.
    UncalledReturned {
        /// Owner.
        player_id: PlayerId,
        /// Chips returned.
        amount: Chips,
    },
    /// Virtual cards: new board cards became visible (public information).
    BoardRevealed {
        /// The newly visible cards, in board order.
        cards: Vec<Card>,
    },
    /// Virtual cards: these players' hole cards became public at showdown.
    HandsRevealed {
        /// Contenders whose hands are now visible.
        players: Vec<PlayerId>,
    },
    /// Betting ended with players all-in; the dealer runs out the board.
    RunoutStarted {
        /// Final pots.
        pots: Vec<PotTier>,
    },
    /// Betting ended; the host picks winners.
    ShowdownStarted {
        /// Final pots.
        pots: Vec<PotTier>,
    },
    /// Chips were paid out of a pot.
    PotAwarded {
        /// Pot position.
        pot_index: u32,
        /// Winner.
        player_id: PlayerId,
        /// Chips won from this pot.
        amount: Chips,
    },
    /// The hand is over.
    HandEnded {
        /// Phase the table moved to.
        next_phase: Phase,
    },
    /// The host paused.
    Paused,
    /// The host resumed.
    Resumed,
    /// The last action was taken back.
    UndoApplied,
}
