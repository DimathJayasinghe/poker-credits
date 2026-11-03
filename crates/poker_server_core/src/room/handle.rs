//! The outside view of a room: a cheap, cloneable [`RoomHandle`] that talks to the actor over a
//! bounded channel, and the messages it sends.

use tokio::sync::{mpsc, oneshot};

use super::state::RoomError;
use crate::protocol::{ClientMessage, ErrorCode, ServerMessage};

/// Identifies one WebSocket connection inside a room.
pub type ConnId = u64;

/// A message queued for one connection. The connection task encodes it with its `reqId`.
#[derive(Clone, Debug, PartialEq)]
pub struct Outbound {
    /// `reqId` of the request this answers, if any.
    pub req_id: Option<String>,
    /// The message.
    pub message: ServerMessage,
}

/// Sending half the actor uses to reach a connection. Bounded: a full queue means a slow
/// consumer and the actor drops the connection instead of waiting.
pub type ConnSender = mpsc::Sender<Outbound>;

/// What the actor receives.
#[derive(Debug)]
pub enum RoomMsg {
    /// A new participant. The actor answers with `JOINED` then `SNAPSHOT` on `tx`.
    Join {
        /// Connection.
        conn: ConnId,
        /// Where to send.
        tx: ConnSender,
        /// `reqId` to echo.
        req_id: Option<String>,
        /// Display name.
        name: String,
        /// Watch only.
        spectator: bool,
        /// Preferred seat.
        seat: Option<u8>,
        /// Result: the new player id.
        reply: oneshot::Sender<Result<String, RoomError>>,
    },
    /// An existing participant re-attaches. The actor answers with `SNAPSHOT` on `tx`.
    Resume {
        /// Connection.
        conn: ConnId,
        /// Where to send.
        tx: ConnSender,
        /// `reqId` to echo.
        req_id: Option<String>,
        /// Session token.
        session_token: String,
        /// Host token (required for the host).
        host_token: Option<String>,
        /// Result: the player id.
        reply: oneshot::Sender<Result<String, RoomError>>,
    },
    /// A message from an attached connection.
    Client {
        /// Connection.
        conn: ConnId,
        /// `reqId` to echo.
        req_id: Option<String>,
        /// The message.
        message: ClientMessage,
    },
    /// The connection closed.
    Detach {
        /// Connection.
        conn: ConnId,
    },
    /// Shut the room down.
    Close,
}

/// Cloneable access to a running room.
#[derive(Clone, Debug)]
pub struct RoomHandle {
    code: String,
    tx: mpsc::Sender<RoomMsg>,
}

fn gone() -> RoomError {
    RoomError::new(ErrorCode::RoomNotFound, "the room is no longer running")
}

impl RoomHandle {
    pub(super) fn new(code: String, tx: mpsc::Sender<RoomMsg>) -> Self {
        RoomHandle { code, tx }
    }

    /// The room code.
    #[must_use]
    pub fn code(&self) -> &str {
        &self.code
    }

    /// Whether the actor is gone.
    #[must_use]
    pub fn is_closed(&self) -> bool {
        self.tx.is_closed()
    }

    /// Joins as player or spectator; returns the player id. `JOINED` and `SNAPSHOT` arrive on
    /// `tx`.
    ///
    /// # Errors
    /// The refusal (`NAME_INVALID`, `ROOM_FULL`, ...), or `ROOM_NOT_FOUND` if the room stopped.
    pub async fn join(
        &self,
        conn: ConnId,
        tx: ConnSender,
        req_id: Option<String>,
        name: String,
        spectator: bool,
        seat: Option<u8>,
    ) -> Result<String, RoomError> {
        let (reply, answer) = oneshot::channel();
        let msg = RoomMsg::Join {
            conn,
            tx,
            req_id,
            name,
            spectator,
            seat,
            reply,
        };
        self.tx.send(msg).await.map_err(|_| gone())?;
        answer.await.map_err(|_| gone())?
    }

    /// Re-attaches with a session token; returns the player id. `SNAPSHOT` arrives on `tx`.
    ///
    /// # Errors
    /// `INVALID_SESSION` for a wrong token, or `ROOM_NOT_FOUND` if the room stopped.
    pub async fn resume(
        &self,
        conn: ConnId,
        tx: ConnSender,
        req_id: Option<String>,
        session_token: String,
        host_token: Option<String>,
    ) -> Result<String, RoomError> {
        let (reply, answer) = oneshot::channel();
        let msg = RoomMsg::Resume {
            conn,
            tx,
            req_id,
            session_token,
            host_token,
            reply,
        };
        self.tx.send(msg).await.map_err(|_| gone())?;
        answer.await.map_err(|_| gone())?
    }

    /// Forwards a client message.
    ///
    /// # Errors
    /// `ROOM_NOT_FOUND` if the room stopped.
    pub async fn send(
        &self,
        conn: ConnId,
        req_id: Option<String>,
        message: ClientMessage,
    ) -> Result<(), RoomError> {
        self.tx
            .send(RoomMsg::Client {
                conn,
                req_id,
                message,
            })
            .await
            .map_err(|_| gone())
    }

    /// Tells the room a connection is gone. Never blocks; if the inbox is full the room will
    /// notice the closed connection on its next send anyway.
    pub fn detach(&self, conn: ConnId) {
        let _ = self.tx.try_send(RoomMsg::Detach { conn });
    }

    /// Asks the room to stop.
    pub async fn close(&self) {
        let _ = self.tx.send(RoomMsg::Close).await;
    }
}
