//! Everything that can change the table. Commands are what the journal stores and replays.

use serde::{Deserialize, Serialize};

use crate::blinds::BlindsMode;
use crate::deck::Deck;
use crate::types::{Chips, PlayerId, SeatIndex};

/// What a player may do on their turn.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
pub enum PlayerAction {
    /// Give up the hand.
    Fold,
    /// Pass without betting (only when nothing is owed).
    Check,
    /// Match the current bet (a short stack goes all-in).
    Call,
    /// Bet or raise so the street total becomes `to_amount`.
    Raise {
        /// Total the player will have in on this street after the raise.
        to_amount: Chips,
    },
    /// Put in the whole stack.
    AllIn,
}

/// Winners of one pot at showdown.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Allocation {
    /// Pot position, 0 = main pot.
    pub pot_index: u32,
    /// Players splitting the pot (more than one means a tie).
    pub winners: Vec<PlayerId>,
}

/// A request to change the table.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
pub enum Command {
    /// A player acts on their turn.
    Action {
        /// Acting player.
        player_id: PlayerId,
        /// What they do.
        action: PlayerAction,
    },
    /// The turn timer expired: check if free, otherwise fold.
    Timeout {
        /// Player whose clock ran out.
        player_id: PlayerId,
    },
    /// A player leaves (quit, disconnected for good, kicked by vote): they fold now if they are
    /// live in the hand, then sit out until they come back, so they play again from the next hand.
    LeaveHand {
        /// Player leaving.
        player_id: PlayerId,
    },
    /// Host: seat a player.
    AddPlayer {
        /// New player.
        player_id: PlayerId,
        /// Chosen seat.
        seat: SeatIndex,
        /// Buy-in.
        chips: Chips,
    },
    /// Move a seated player to another seat between hands. An empty target seat is simply taken;
    /// an occupied one is swapped with, so the host can reorder the table in one step. The button
    /// and blind markers stay on their seats (a physical button stays on its chair), so they
    /// follow the chairs, not the people.
    MoveSeat {
        /// Player to move.
        player_id: PlayerId,
        /// Target seat.
        seat: SeatIndex,
    },
    /// Host: remove a player (not while they are in a hand).
    RemovePlayer {
        /// Player to remove.
        player_id: PlayerId,
    },
    /// Host or player: skip or rejoin from the next hand.
    SetSittingOut {
        /// Player.
        player_id: PlayerId,
        /// New state.
        sitting_out: bool,
    },
    /// Host: add chips between hands.
    Rebuy {
        /// Player topping up.
        player_id: PlayerId,
        /// Chips to add.
        amount: Chips,
    },
    /// Host: change the blind structure between hands.
    Configure {
        /// New structure.
        blinds: BlindsMode,
    },
    /// Host: deal the next hand.
    StartHand {
        /// Tournament time elapsed, supplied by the server so replay is exact.
        elapsed_ms: u64,
        /// Virtual-card rooms: the shuffled deck, drawn by the server and recorded in the journal
        /// (the engine never shuffles). `None` for physical cards, and in every old journal.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        deck: Option<Deck>,
    },
    /// Host: end the all-in run-out and go to showdown.
    BeginShowdown,
    /// Host: pick winners for every pot.
    ResolveShowdown {
        /// One allocation per pot.
        allocations: Vec<Allocation>,
    },
    /// Host: freeze the game.
    Pause,
    /// Host: unfreeze the game.
    Resume,
    /// Host: step back one action (up to five).
    Undo,
}

/// Who is allowed to originate a command. The server enforces this before calling `apply`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Origin {
    /// Any seated player, for themselves only.
    Player,
    /// The authenticated host (otherwise the server answers `HOST_ONLY_ACTION`).
    Host,
    /// The server itself (turn timer). A client must never be able to send these.
    Server,
}

impl Command {
    /// Who may send this command.
    ///
    /// [`Command::MoveSeat`] is a host command, but the server also lets a player move themselves
    /// into a *free* seat (never displacing anyone), so a guest can pick where they sit.
    ///
    /// The engine trusts the `player_id` it is given: for [`Command::Action`],
    /// [`Command::SetSittingOut`] and [`Command::LeaveHand`] (origin [`Origin::Player`]) the server must bind it to the
    /// authenticated session, never take it from the message body.
    #[must_use]
    pub fn origin(&self) -> Origin {
        match self {
            Command::Action { .. } | Command::SetSittingOut { .. } | Command::LeaveHand { .. } => {
                Origin::Player
            }
            Command::Timeout { .. } => Origin::Server,
            Command::AddPlayer { .. }
            | Command::MoveSeat { .. }
            | Command::RemovePlayer { .. }
            | Command::Rebuy { .. }
            | Command::Configure { .. }
            | Command::StartHand { .. }
            | Command::BeginShowdown
            | Command::ResolveShowdown { .. }
            | Command::Pause
            | Command::Resume
            | Command::Undo => Origin::Host,
        }
    }
}
