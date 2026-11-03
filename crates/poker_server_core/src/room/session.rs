//! A connection's link to its room. It outlives the room's task: when the supervisor restarts
//! a crashed room, [`Session::changed`] re-attaches the same connection to the new task.

use tokio::sync::watch;

use super::handle::{ConnId, ConnSender, Outbound, RoomHandle, RoomStatus};
use super::state::RoomError;
use crate::protocol::{ClientMessage, ErrorCode, ServerMessage};

/// One attached connection.
#[derive(Debug)]
pub struct Session {
    conn: ConnId,
    tx: ConnSender,
    status: watch::Receiver<RoomStatus>,
    player_id: String,
    token: String,
    host_token: Option<String>,
}

impl Session {
    pub(crate) fn new(
        conn: ConnId,
        tx: ConnSender,
        status: watch::Receiver<RoomStatus>,
        player_id: String,
        session_token: String,
        host_token: Option<String>,
    ) -> Self {
        Session {
            conn,
            tx,
            status,
            player_id,
            token: session_token,
            host_token,
        }
    }

    /// Connection id inside the room.
    #[must_use]
    pub fn conn(&self) -> ConnId {
        self.conn
    }

    /// The participant this connection speaks for.
    #[must_use]
    pub fn player_id(&self) -> &str {
        &self.player_id
    }

    /// The session secret.
    #[must_use]
    pub fn session_token(&self) -> &str {
        &self.token
    }

    fn handle(&self) -> Result<RoomHandle, RoomError> {
        match &*self.status.borrow() {
            RoomStatus::Running(handle) => Ok(handle.clone()),
            RoomStatus::Frozen => Err(RoomError::new(
                ErrorCode::RoomCrashed,
                "the room has crashed",
            )),
            RoomStatus::Gone => Err(RoomError::new(ErrorCode::RoomNotFound, "the room is over")),
        }
    }

    /// Forwards a client message to the room.
    ///
    /// # Errors
    /// `ROOM_CRASHED` or `ROOM_NOT_FOUND` when there is no running room. During a restart the
    /// send may fail with `ROOM_NOT_FOUND`; the client retries and `actionSeq` keeps it safe.
    pub async fn send(
        &self,
        req_id: Option<String>,
        message: ClientMessage,
    ) -> Result<(), RoomError> {
        self.handle()?.send(self.conn, req_id, message).await
    }

    /// Tells the room this connection is gone.
    pub fn detach(&self) {
        if let Ok(handle) = self.handle() {
            handle.detach(self.conn);
        }
    }

    /// Waits until the room's status changes (restart, freeze, end). Cancel-safe. `false` when
    /// the registry itself is gone. Pair with [`Session::follow_change`], run outside any
    /// `select!` future so that it always finishes.
    pub async fn wait_change(&mut self) -> bool {
        self.status.changed().await.is_ok()
    }

    /// Reacts to the current status: re-attaches after a restart (`ROOM_RECOVERED`, then the
    /// room sends a fresh `SNAPSHOT`), sends `ROOM_CRASHED` when frozen. Returns `false` once
    /// the room is gone for good, so the caller can close the socket.
    pub async fn follow_change(&mut self) -> bool {
        let status = self.status.borrow().clone();
        match status {
            RoomStatus::Running(handle) => {
                self.notify(ServerMessage::RoomRecovered {
                    reason: "the room restarted after a server fault".to_owned(),
                });
                let resumed = handle
                    .resume(
                        self.conn,
                        self.tx.clone(),
                        None,
                        self.token.clone(),
                        self.host_token.clone(),
                    )
                    .await;
                if let Err(error) = resumed {
                    self.notify(error.to_message());
                }
                true
            }
            RoomStatus::Frozen => {
                self.notify(ServerMessage::RoomCrashed {
                    reason: "the room crashed repeatedly and is frozen".to_owned(),
                });
                true
            }
            RoomStatus::Gone => false,
        }
    }

    /// [`wait_change`](Session::wait_change) then [`follow_change`](Session::follow_change).
    pub async fn changed(&mut self) -> bool {
        self.wait_change().await && self.follow_change().await
    }

    fn notify(&self, message: ServerMessage) {
        let _queued = self.tx.try_send(Outbound {
            req_id: None,
            message,
        });
    }
}

impl Drop for Session {
    /// A dropped session (task ended, panicked or was cancelled) always tells the room.
    fn drop(&mut self) {
        self.detach();
    }
}
