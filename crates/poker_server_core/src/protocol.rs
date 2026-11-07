//! The wire protocol: one JSON object per WebSocket text frame (`docs/API_AND_EVENTS.md`).
//!
//! Rust is the schema. Dart mirrors it in `packages/poker_protocol` and both sides are tested
//! against the golden files in `protocol/fixtures/v1/`.

use poker_engine::card::Card;
use poker_engine::hand_rank::HandCategory;
use poker_engine::{ActionKind, LegalActions, PlayerAction, PokerError};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::PROTOCOL_VERSION;

/// Largest accepted frame, in bytes.
pub const MAX_MESSAGE_BYTES: usize = 16 * 1024;

/// A message plus its envelope fields (`v`, `reqId`).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Envelope<T> {
    /// Protocol version.
    pub v: u16,
    /// Client-chosen id echoed on the answer.
    #[serde(rename = "reqId", default, skip_serializing_if = "Option::is_none")]
    pub req_id: Option<String>,
    /// The typed message (flattened so `type` and its fields sit next to `v`).
    #[serde(flatten)]
    pub body: T,
}

/// What a connection is allowed to do.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Role {
    /// Created the room; may send admin messages.
    Host,
    /// Seated; may act on its own turn.
    Player,
    /// Read-only.
    Spectator,
}

/// A client feature a virtual-card room requires (sent in `JOIN_ROOM` / `RESUME` `features`).
pub const FEATURE_VIRTUAL_CARDS: &str = "VIRTUAL_CARDS";

/// Who deals the cards. Fixed for the life of a room (ADR-016).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum CardMode {
    /// Real cards on the table; the app handles chips and pots (the original mode).
    #[default]
    Physical,
    /// The server shuffles, deals, reveals and ranks.
    Virtual,
}

impl CardMode {
    /// For `skip_serializing_if`: physical rooms serialise exactly as they always did.
    #[must_use]
    pub fn is_physical(&self) -> bool {
        matches!(self, CardMode::Physical)
    }
}

/// Room settings chosen by the host.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RoomConfig {
    /// Stack every player starts with.
    pub starting_chips: u64,
    /// Small blind (first level for tournaments).
    pub small_blind: u64,
    /// Big blind (first level for tournaments).
    pub big_blind: u64,
    /// Ante, zero for none.
    pub ante: u64,
    /// Escalating blinds instead of fixed ones.
    pub is_tournament: bool,
    /// Minutes per tournament level.
    pub blind_level_minutes: u32,
    /// Seconds a player has to act, zero for no timer.
    pub turn_time_limit_seconds: u32,
    /// Real or virtual cards (absent means real).
    #[serde(default, skip_serializing_if = "CardMode::is_physical")]
    pub card_mode: CardMode,
    /// A single-player game against computer players (absent means an ordinary room). Only the
    /// app's own loopback server accepts it; the network `CREATE_ROOM` refuses it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub solo: Option<SoloConfig>,
}

/// The extra settings of a single-player game (ADR-018).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SoloConfig {
    /// Computer players at the table, 1 to 9.
    pub bots: u8,
    /// How well they play.
    pub skill: poker_bots::Skill,
    /// Hands played at each blind level.
    pub ladder_hands: u32,
}

/// Most computer players a solo table holds (the engine seats ten).
pub const MAX_BOTS: u8 = 9;

/// Winners of one pot as sent by the host.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WireAllocation {
    /// Pot position, 0 = main pot.
    pub pot_index: u32,
    /// Players splitting the pot.
    pub winner_player_ids: Vec<String>,
}

/// Everything a client may send.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
pub enum ClientMessage {
    /// Cloud mode: create a room.
    CreateRoom {
        /// Host's display name.
        host_name: String,
        /// Room settings.
        config: RoomConfig,
    },
    /// Take a seat or watch.
    JoinRoom {
        /// Room to join (case-insensitive).
        room_code: String,
        /// Display name.
        name: String,
        /// Preferred seat, first free one if absent.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        seat_index: Option<u8>,
        /// Watch only.
        #[serde(default)]
        spectator: bool,
        /// Optional abilities of this client, for example `VIRTUAL_CARDS`.
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        features: Vec<String>,
    },
    /// Re-attach after a lost connection.
    Resume {
        /// Room to resume.
        room_code: String,
        /// Token from `JOINED` / `ROOM_CREATED`.
        session_token: String,
        /// Last state version the client saw.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        last_state_version: Option<u64>,
        /// Host proof, only for the host.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        host_token: Option<String>,
        /// Optional abilities of this client, for example `VIRTUAL_CARDS`.
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        features: Vec<String>,
    },
    /// Host: deal the next hand.
    StartHand,
    /// Player: act on the turn.
    GameAction {
        /// Per-session counter from the server's `nextActionSeq`.
        action_seq: u64,
        /// The action.
        action: PlayerAction,
    },
    /// Host: end the all-in run-out.
    BeginShowdown,
    /// Host: choose winners.
    ResolveShowdown {
        /// One entry per pot.
        allocations: Vec<WireAllocation>,
    },
    /// Host: take back the last action.
    Undo,
    /// Host: freeze the game.
    Pause {
        /// Free text shown to players.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        reason: Option<String>,
    },
    /// Host: unfreeze the game.
    ResumeGame,
    /// Host: approve a queued top-up.
    ApproveRebuy {
        /// Player topping up.
        player_id: String,
        /// Chips to add.
        amount: u64,
    },
    /// Host: remove a player.
    Kick {
        /// Player to remove.
        player_id: String,
    },
    /// Host: move a player to another seat between hands. An occupied target seat is swapped
    /// with, so the host can reorder the table to match who sits where.
    MoveSeat {
        /// Player to move.
        player_id: String,
        /// Target seat, `0..10`, clockwise.
        seat_index: u8,
    },
    /// Player: move myself to a free seat between hands.
    ChooseSeat {
        /// Target seat, `0..10`, clockwise.
        seat_index: u8,
    },
    /// Host: change settings between hands.
    RoomConfigure {
        /// New settings.
        config: RoomConfig,
    },
    /// Host: close the room.
    EndGame,
    /// Player: ask for a top-up.
    RequestRebuy {
        /// Chips wanted.
        amount: u64,
    },
    /// Player: skip or rejoin from the next hand.
    SetSittingOut {
        /// New state.
        sitting_out: bool,
    },
    /// Player: fold now and leave the table (keeps the room session).
    LeaveTable,
    /// Player: answer a presence check.
    PresenceVote {
        /// Player the check is about.
        player_id: String,
        /// "Yes, they are still playing."
        still_playing: bool,
    },
    /// Player: "I am still here", cancels a check about myself.
    PresenceAck,
    /// Keep-alive.
    Ping {
        /// Client time, echoed in `PONG`.
        t: u64,
    },
    /// Any `type` this server does not know.
    #[serde(other)]
    Unknown,
}

/// Phase names on the wire. `PAUSED` is derived from the engine's `paused` flag.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum WirePhase {
    /// No hand yet.
    Lobby,
    /// Betting.
    PreFlop,
    /// Betting.
    Flop,
    /// Betting.
    Turn,
    /// Betting.
    River,
    /// Everyone left is all-in.
    AllInRunout,
    /// Host picks winners.
    Showdown,
    /// Ready to deal.
    NextHandPrep,
    /// Host paused.
    Paused,
}

/// One seat in `RoomView`.
#[allow(
    clippy::struct_excessive_bools,
    reason = "mirrors the wire `seats[]` object"
)]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SeatView {
    /// Position.
    pub seat_index: u8,
    /// Occupant.
    pub player_id: String,
    /// Display name.
    pub name: String,
    /// Chips behind.
    pub chips: u64,
    /// Chips in on this street.
    pub street_bet: u64,
    /// Folded this hand.
    pub has_folded: bool,
    /// All-in this hand.
    pub is_all_in: bool,
    /// Skipped from the next hand.
    pub is_sitting_out: bool,
    /// Has a live connection.
    pub is_connected: bool,
    /// Virtual cards: a hand was dealt to this seat (draw a card back).
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub has_cards: bool,
}

/// One pot in `RoomView`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PotView {
    /// 0 = main pot.
    pub tier_index: u32,
    /// Chips in the pot.
    pub amount: u64,
    /// Players who can win it.
    pub eligible_player_ids: Vec<String>,
}

/// A hand turned face up at showdown (virtual cards).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevealView {
    /// Whose hand.
    pub player_id: String,
    /// Their name when the hand was paid.
    pub name: String,
    /// The two hole cards.
    pub cards: [Card; 2],
    /// What the hand is.
    pub category: HandCategory,
    /// The five cards that make it.
    pub best_five: [Card; 5],
}

/// What one player received from a pot.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ShareView {
    /// Winner.
    pub player_id: String,
    /// Their name when the hand was paid.
    pub name: String,
    /// Chips received.
    pub amount: u64,
}

/// How one pot was paid.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PotResultView {
    /// 0 = main pot.
    pub pot_index: u32,
    /// Chips in the pot.
    pub amount: u64,
    /// Everyone who shared it.
    pub winner_player_ids: Vec<String>,
    /// Each winner's amount.
    pub shares: Vec<ShareView>,
}

/// How the last hand was paid (virtual cards), kept until the next hand starts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HandResultView {
    /// Everyone else folded; no hands were compared.
    pub uncontested: bool,
    /// One entry per pot, main pot first.
    pub pots: Vec<PotResultView>,
}

/// The public table state. Never contains private data.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RoomView {
    /// Room code.
    pub room_code: String,
    /// Hands dealt so far.
    pub hand_number: u32,
    /// Phase (`PAUSED` while the host has paused).
    pub phase: WirePhase,
    /// Button seat.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dealer_seat: Option<u8>,
    /// Small blind seat (absent when the small blind is dead).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub small_blind_seat: Option<u8>,
    /// Big blind seat.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub big_blind_seat: Option<u8>,
    /// Seat to act.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub active_seat: Option<u8>,
    /// Highest street total.
    pub current_high_bet: u64,
    /// Smallest raise-to total for the next raise (zero outside betting).
    pub min_raise_to: u64,
    /// Chips committed to the hand.
    pub total_pot: u64,
    /// Final pots (empty during betting).
    pub pots: Vec<PotView>,
    /// Occupied seats.
    pub seats: Vec<SeatView>,
    /// Host paused.
    pub paused: bool,
    /// Absolute server time the turn ends, if a timer runs.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub turn_deadline_ms: Option<u64>,
    /// People watching.
    pub spectator_count: u32,
    /// Top-ups waiting for the host (or for the end of the hand once approved).
    pub pending_rebuys: Vec<PendingRebuyView>,
    /// Virtual cards: the board cards everyone may see.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub board: Vec<Card>,
    /// Virtual cards: hands turned face up at showdown.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub reveals: Vec<RevealView>,
    /// Virtual cards: how the last hand was paid.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub result: Option<HandResultView>,
    /// Solo games: who has been knocked out, in the order it happened, and the winner last.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub finish_order: Vec<FinishView>,
}

/// One finishing place in a solo game.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FinishView {
    /// Who finished.
    pub player_id: String,
    /// Their name (the seat may be gone by now).
    pub name: String,
    /// 1 = winner, 2 = runner-up, and so on.
    pub place: u8,
}

/// A top-up request, public so the host can approve it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PendingRebuyView {
    /// Player asking.
    pub player_id: String,
    /// Chips requested.
    pub amount: u64,
    /// The host already approved it; it applies between hands.
    pub approved: bool,
}

/// Wire error codes (`docs/API_AND_EVENTS.md` section 6).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    /// Protocol version not supported.
    VersionMismatch,
    /// Unknown message type.
    UnknownMessage,
    /// Malformed JSON or field out of range.
    BadRequest,
    /// First message was not join/create/resume.
    NotAuthenticated,
    /// Token missing, expired or wrong.
    InvalidSession,
    /// No such room.
    RoomNotFound,
    /// All seats taken.
    RoomFull,
    /// Spectator limit reached.
    SpectatorsFull,
    /// Seat already taken.
    SeatOccupied,
    /// Player already has a seat.
    AlreadySeated,
    /// Name fails validation.
    NameInvalid,
    /// Out of turn.
    NotYourTurn,
    /// Check while facing a bet.
    InvalidCheck,
    /// Action makes no sense now (for example call with nothing to call).
    InvalidAction,
    /// Raise too small.
    BelowMinRaise,
    /// Short all-in did not reopen betting.
    BettingNotReopened,
    /// More than the stack.
    InsufficientFunds,
    /// Amount zero, too large or over the table cap.
    InvalidAmount,
    /// `actionSeq` ahead of the server.
    OutOfSync,
    /// Admin message from a non-host.
    HostOnlyAction,
    /// No hand running.
    HandNotInProgress,
    /// A hand is already running.
    HandInProgress,
    /// Game paused.
    GamePaused,
    /// Resume while not paused.
    NotPaused,
    /// Fewer than two players can be dealt in.
    NotEnoughPlayers,
    /// No such player.
    UnknownPlayer,
    /// Nothing to undo.
    NothingToUndo,
    /// Showdown allocation rejected.
    InvalidAllocation,
    /// Phase change not allowed.
    IllegalState,
    /// No presence check is running for that player.
    NoPresenceCheck,
    /// Too many messages.
    RateLimited,
    /// Same seat connected elsewhere.
    Superseded,
    /// This app version cannot play this room (for example it needs virtual cards).
    UpdateRequired,
    /// Room frozen after repeated panics.
    RoomCrashed,
    /// Unexpected server failure.
    InternalError,
}

impl From<&PokerError> for ErrorCode {
    fn from(error: &PokerError) -> Self {
        match error {
            PokerError::NotYourTurn => ErrorCode::NotYourTurn,
            PokerError::CannotCheck => ErrorCode::InvalidCheck,
            PokerError::NothingToCall => ErrorCode::InvalidAction,
            PokerError::BelowMinRaise { .. } => ErrorCode::BelowMinRaise,
            PokerError::BettingNotReopened => ErrorCode::BettingNotReopened,
            PokerError::InsufficientFunds { .. } => ErrorCode::InsufficientFunds,
            PokerError::HandNotInProgress => ErrorCode::HandNotInProgress,
            PokerError::HandInProgress => ErrorCode::HandInProgress,
            PokerError::GamePaused => ErrorCode::GamePaused,
            PokerError::NotPaused => ErrorCode::NotPaused,
            PokerError::NotEnoughPlayers => ErrorCode::NotEnoughPlayers,
            PokerError::UnknownPlayer => ErrorCode::UnknownPlayer,
            PokerError::PlayerExists => ErrorCode::AlreadySeated,
            PokerError::SeatOccupied => ErrorCode::SeatOccupied,
            PokerError::InvalidSeat | PokerError::InvalidDeck | PokerError::InvalidHand => {
                ErrorCode::BadRequest
            }
            PokerError::InvalidAmount => ErrorCode::InvalidAmount,
            PokerError::Overflow => ErrorCode::InternalError,
            PokerError::IllegalTransition { .. } => ErrorCode::IllegalState,
            PokerError::NothingToUndo => ErrorCode::NothingToUndo,
            PokerError::InvalidAllocation(_) => ErrorCode::InvalidAllocation,
        }
    }
}

/// An `ERROR` message body built from an engine error, with the numbers the UI needs.
#[must_use]
pub fn error_from_engine(error: &PokerError) -> ServerMessage {
    let details = match error {
        PokerError::BelowMinRaise { min_raise_to } => {
            Some(serde_json::json!({ "minRaiseTo": min_raise_to.get() }))
        }
        PokerError::InsufficientFunds { max_to } => {
            Some(serde_json::json!({ "maxTo": max_to.get() }))
        }
        _ => None,
    };
    ServerMessage::Error {
        code: ErrorCode::from(error),
        message: error.to_string(),
        details,
    }
}

/// Everything the server may send.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
pub enum ServerMessage {
    /// Answer to `CREATE_ROOM` (and the host-mode bridge call).
    RoomCreated {
        /// New room's code.
        room_code: String,
        /// Host proof, stored in secure storage.
        host_token: String,
        /// Host's session.
        session_token: String,
        /// Host's player id.
        player_id: String,
    },
    /// Answer to `JOIN_ROOM`.
    Joined {
        /// Assigned id.
        player_id: String,
        /// Granted role.
        role: Role,
        /// Seat, absent for spectators.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        seat_index: Option<u8>,
        /// Session secret.
        session_token: String,
    },
    /// Full state, sent after join/resume and when a client must resync.
    Snapshot {
        /// Monotonic state counter.
        state_version: u64,
        /// Server clock, epoch milliseconds.
        server_time: u64,
        /// Value the next `GAME_ACTION` must carry.
        next_action_seq: u64,
        /// Public table state.
        view: RoomView,
    },
    /// New state after every change.
    StateUpdate {
        /// Monotonic state counter (+1 per change).
        state_version: u64,
        /// Public table state.
        view: RoomView,
    },
    /// Only to the acting player.
    TurnPrompt {
        /// Player to act.
        player_id: String,
        /// Their seat.
        seat_index: u8,
        /// Absolute server time the turn ends.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        turn_deadline_ms: Option<u64>,
        /// Value the next `GAME_ACTION` must carry.
        next_action_seq: u64,
        /// What the player may do.
        legal: LegalActions,
    },
    /// Ticker and sound feed.
    ActionPerformed {
        /// Who acted.
        player_id: String,
        /// Display name.
        player_name: String,
        /// What happened (`BET` is additive to the original list).
        kind: ActionKind,
        /// Street total after the action ("raises to 60").
        amount: u64,
        /// Chips left behind.
        chips_remaining: u64,
        /// Used the last chip.
        all_in: bool,
        /// Chosen by the server after a timeout.
        auto: bool,
    },
    /// Virtual cards: your two cards. Only ever sent to their owner.
    HoleCards {
        /// Hand the cards belong to.
        hand_number: u32,
        /// The cards.
        cards: [Card; 2],
    },
    /// Request accepted.
    Ack {
        /// Counter for the next action.
        next_action_seq: u64,
        /// Already applied earlier; nothing changed.
        duplicate: bool,
    },
    /// Request refused.
    Error {
        /// Machine-readable code.
        code: ErrorCode,
        /// Human-readable text.
        message: String,
        /// Extra numbers (for example `minRaiseTo`).
        #[serde(default, skip_serializing_if = "Option::is_none")]
        details: Option<Value>,
    },
    /// A player connected or disconnected.
    PlayerConnection {
        /// Seat.
        seat_index: u8,
        /// Player.
        player_id: String,
        /// New state.
        is_connected: bool,
    },
    /// Host paused.
    GamePaused {
        /// Who paused.
        paused_by: String,
        /// Optional text.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        reason: Option<String>,
    },
    /// Host resumed.
    GameResumed {
        /// Who resumed.
        resumed_by: String,
        /// New deadline, extended by the paused time.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        turn_deadline_ms: Option<u64>,
    },
    /// The room restarted after a server fault; a `SNAPSHOT` follows.
    RoomRecovered {
        /// Why.
        reason: String,
    },
    /// The room is frozen.
    RoomCrashed {
        /// Why.
        reason: String,
    },
    /// The room was purged.
    RoomExpired,
    /// Answer to `PING`.
    Pong {
        /// Echoed time.
        t: u64,
    },
    /// A player missed their turns and sits out.
    PlayerAway {
        /// Player.
        player_id: String,
        /// Seat.
        seat_index: u8,
    },
    /// "Is NAME still playing?"
    PresenceCheck {
        /// Player being asked about.
        subject_player_id: String,
        /// Their name.
        subject_name: String,
        /// Absolute server time the check ends.
        deadline_ms: u64,
    },
    /// The check ended.
    PresenceResolved {
        /// Player the check was about.
        subject_player_id: String,
        /// They were removed from the table.
        removed: bool,
    },
}

/// Why an inbound frame could not become a message.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ParseError {
    /// Frame larger than [`MAX_MESSAGE_BYTES`].
    TooLarge,
    /// Not a JSON object with a numeric `v`.
    BadRequest(String),
    /// `v` is not [`PROTOCOL_VERSION`].
    VersionMismatch,
}

impl ParseError {
    /// The code and text to send back.
    #[must_use]
    pub fn to_message(&self) -> ServerMessage {
        let (code, message) = match self {
            ParseError::TooLarge => (ErrorCode::BadRequest, "message too large".to_owned()),
            ParseError::BadRequest(text) => (ErrorCode::BadRequest, text.clone()),
            ParseError::VersionMismatch => (
                ErrorCode::VersionMismatch,
                format!("protocol version {PROTOCOL_VERSION} is required"),
            ),
        };
        ServerMessage::Error {
            code,
            message,
            details: None,
        }
    }
}

/// A failed parse, with the `reqId` if one could be read so the error can echo it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ParseFailure {
    /// `reqId` of the offending frame, if readable.
    pub req_id: Option<String>,
    /// Why parsing failed.
    pub error: ParseError,
}

/// Parses one inbound frame.
///
/// The version is checked on the raw JSON before the body is interpreted, so a future version
/// with a different body shape still gets `VERSION_MISMATCH` instead of `BAD_REQUEST`.
///
/// # Errors
/// A [`ParseFailure`] describing what is wrong with the frame.
pub fn parse_client(text: &str) -> Result<Envelope<ClientMessage>, ParseFailure> {
    let fail = |req_id: Option<String>, error: ParseError| ParseFailure { req_id, error };
    if text.len() > MAX_MESSAGE_BYTES {
        return Err(fail(None, ParseError::TooLarge));
    }
    let value: Value = serde_json::from_str(text)
        .map_err(|e| fail(None, ParseError::BadRequest(e.to_string())))?;
    let object = value.as_object().ok_or_else(|| {
        fail(
            None,
            ParseError::BadRequest("expected a JSON object".to_owned()),
        )
    })?;
    let req_id = object
        .get("reqId")
        .and_then(Value::as_str)
        .map(str::to_owned);
    match object.get("v").and_then(Value::as_u64) {
        Some(v) if v == u64::from(PROTOCOL_VERSION) => {}
        Some(_) => return Err(fail(req_id, ParseError::VersionMismatch)),
        None => {
            return Err(fail(
                req_id,
                ParseError::BadRequest("missing protocol version".to_owned()),
            ));
        }
    }
    let body: ClientMessage = serde_json::from_value(value)
        .map_err(|e| fail(req_id.clone(), ParseError::BadRequest(e.to_string())))?;
    Ok(Envelope {
        v: PROTOCOL_VERSION,
        req_id,
        body,
    })
}

/// Serialises a server message with its envelope.
///
/// # Errors
/// Only if serialisation fails, which cannot happen for these types.
pub fn encode_server(
    req_id: Option<&str>,
    message: &ServerMessage,
) -> Result<String, serde_json::Error> {
    #[derive(Serialize)]
    struct Out<'a> {
        v: u16,
        #[serde(rename = "reqId", skip_serializing_if = "Option::is_none")]
        req_id: Option<&'a str>,
        #[serde(flatten)]
        body: &'a ServerMessage,
    }
    serde_json::to_string(&Out {
        v: PROTOCOL_VERSION,
        req_id,
        body: message,
    })
}
