//! One WebSocket connection: authenticate with `CREATE_ROOM` / `JOIN_ROOM` / `RESUME`, then
//! pass messages between the socket and the room.
//!
//! Hygiene (`docs/RESILIENCE_AND_CRASH_HANDLING.md` 3.6): 16 KiB frames, an idle timeout that
//! only inbound frames reset, a deadline for the first message, a token bucket with three
//! strikes, and a write timeout so a stuck peer cannot hold the task.

use std::net::SocketAddr;
use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{ConnectInfo, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use tokio::sync::watch;
use tokio::time::{Instant, sleep_until, timeout, timeout_at};

use super::NetState;
use super::guards::{ConnectionGuard, TokenBucket};
use crate::protocol::{
    ClientMessage, ErrorCode, MAX_MESSAGE_BYTES, ParseError, ServerMessage, encode_server,
    parse_client,
};
use crate::room::handle::{ConnReceiver, ConnSender, Outbound};
use crate::room::session::Session;
use crate::room::state::RoomError;

/// `GET /v1/ws`
pub(crate) async fn upgrade(
    State(net): State<Arc<NetState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    ws: WebSocketUpgrade,
) -> Response {
    let Some(guard) = net.ip_limiter.try_acquire(addr.ip()) else {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    };
    ws.max_message_size(MAX_MESSAGE_BYTES)
        .max_frame_size(MAX_MESSAGE_BYTES)
        .on_upgrade(move |socket| serve(socket, net, guard))
}

/// Why a connection ended (only for the log).
#[derive(Debug)]
enum End {
    Closed,
    Idle,
    AuthTimeout,
    BadAuth,
    Version,
    RateLimited,
    WriteFailed,
    RoomLost,
    Shutdown,
}

struct Connection {
    socket: WebSocket,
    net: Arc<NetState>,
    tx: ConnSender,
    rx: ConnReceiver,
    conn_id: u64,
    bucket: TokenBucket,
    strikes: u32,
    shutdown: watch::Receiver<bool>,
    /// Holds the per-IP slot until the task ends, however it ends.
    _guard: ConnectionGuard,
}

async fn serve(socket: WebSocket, net: Arc<NetState>, guard: ConnectionGuard) {
    let (tx, rx) = ConnSender::channel(net.limits.outbound_queue);
    let conn_id = net.registry.next_conn_id();
    let bucket = TokenBucket::new(
        net.limits.rate_per_second,
        net.limits.rate_burst,
        Instant::now(),
    );
    let shutdown = net.shutdown.clone();
    let mut connection = Connection {
        socket,
        net,
        tx,
        rx,
        conn_id,
        bucket,
        strikes: 0,
        shutdown,
        _guard: guard,
    };
    let end = connection.run().await;
    tracing::debug!(conn = conn_id, ?end, "websocket closed");
    connection.close().await;
}

impl Connection {
    async fn run(&mut self) -> End {
        match self.authenticate().await {
            Ok(session) => self.serve_session(session).await,
            Err(end) => end,
        }
    }

    // -----------------------------------------------------------------------------------------
    // Writing
    // -----------------------------------------------------------------------------------------

    async fn write(&mut self, req_id: Option<&str>, message: &ServerMessage) -> Result<(), End> {
        let Ok(text) = encode_server(req_id, message) else {
            return Ok(());
        };
        let sent = timeout(
            self.net.limits.write_timeout,
            self.socket.send(Message::Text(text.into())),
        )
        .await;
        match sent {
            Ok(Ok(())) => Ok(()),
            Ok(Err(_)) | Err(_) => Err(End::WriteFailed),
        }
    }

    async fn write_error(&mut self, req_id: Option<&str>, error: &RoomError) -> Result<(), End> {
        self.write(req_id, &error.to_message()).await
    }

    async fn close(&mut self) {
        let _ = timeout(
            self.net.limits.write_timeout,
            self.socket.send(Message::Close(None)),
        )
        .await;
    }

    /// Takes a token. Returns `Err` after the third strike.
    async fn rate_check(&mut self, req_id: Option<&str>) -> Result<bool, End> {
        if self.bucket.allow(Instant::now()) {
            return Ok(true);
        }
        self.strikes += 1;
        let error = RoomError::new(ErrorCode::RateLimited, "slow down");
        self.write_error(req_id, &error).await?;
        if self.strikes >= self.net.limits.rate_strikes {
            return Err(End::RateLimited);
        }
        Ok(false)
    }

    // -----------------------------------------------------------------------------------------
    // Before the room: the first message decides who this connection is
    // -----------------------------------------------------------------------------------------

    async fn authenticate(&mut self) -> Result<Session, End> {
        let deadline = Instant::now() + self.net.limits.auth_timeout;
        loop {
            let frame = match timeout_at(deadline, self.socket.recv()).await {
                Err(_) => return Err(End::AuthTimeout),
                Ok(None | Some(Err(_))) => return Err(End::Closed),
                Ok(Some(Ok(frame))) => frame,
            };
            let text = match frame {
                Message::Text(text) => text,
                Message::Close(_) => return Err(End::Closed),
                Message::Ping(_) | Message::Pong(_) => continue,
                Message::Binary(_) => {
                    let error = RoomError::new(ErrorCode::BadRequest, "text frames only");
                    self.write_error(None, &error).await?;
                    continue;
                }
            };
            let envelope = match parse_client(text.as_str()) {
                Ok(envelope) => envelope,
                Err(failure) => {
                    let message = failure.error.to_message();
                    self.write(failure.req_id.as_deref(), &message).await?;
                    if failure.error == ParseError::VersionMismatch {
                        return Err(End::Version);
                    }
                    continue;
                }
            };
            let req_id = envelope.req_id;
            if !self.rate_check(req_id.as_deref()).await? {
                continue;
            }
            if let ClientMessage::Ping { t } = envelope.body {
                // Allowed before joining so a client can test the link.
                self.write(req_id.as_deref(), &ServerMessage::Pong { t })
                    .await?;
                continue;
            }
            match self.try_enter(req_id.clone(), envelope.body).await {
                Entry::Joined(session) => return Ok(session),
                Entry::Retry(error) => self.write_error(req_id.as_deref(), &error).await?,
                Entry::Reject(error) => {
                    self.write_error(req_id.as_deref(), &error).await?;
                    return Err(End::BadAuth);
                }
            }
        }
    }

    async fn try_enter(&mut self, req_id: Option<String>, message: ClientMessage) -> Entry {
        let registry = &self.net.registry;
        let (conn, tx) = (self.conn_id, self.tx.clone());
        let result = match message {
            ClientMessage::CreateRoom { host_name, config } => {
                registry
                    .create_room(conn, tx, req_id, host_name, config)
                    .await
            }
            ClientMessage::JoinRoom {
                room_code,
                name,
                seat_index,
                spectator,
            } => {
                registry
                    .join_room(&room_code, conn, tx, req_id, name, spectator, seat_index)
                    .await
            }
            ClientMessage::Resume {
                room_code,
                session_token,
                host_token,
                last_state_version: _,
            } => {
                registry
                    .resume_room(&room_code, conn, tx, req_id, session_token, host_token)
                    .await
            }
            _ => {
                return Entry::Reject(RoomError::new(
                    ErrorCode::NotAuthenticated,
                    "send CREATE_ROOM, JOIN_ROOM or RESUME first",
                ));
            }
        };
        match result {
            Ok(session) => Entry::Joined(session),
            Err(error) => match error.code {
                // A wrong name or a taken seat can be fixed on the same socket.
                ErrorCode::NameInvalid
                | ErrorCode::SeatOccupied
                | ErrorCode::AlreadySeated
                | ErrorCode::BadRequest
                | ErrorCode::InvalidAmount => Entry::Retry(error),
                _ => Entry::Reject(error),
            },
        }
    }

    // -----------------------------------------------------------------------------------------
    // Inside a room
    // -----------------------------------------------------------------------------------------

    async fn serve_session(&mut self, mut session: Session) -> End {
        let mut idle_at = Instant::now() + self.net.limits.idle_timeout;
        loop {
            tokio::select! {
                frame = self.socket.recv() => {
                    idle_at = Instant::now() + self.net.limits.idle_timeout;
                    if let Err(end) = self.on_frame(&session, frame).await {
                        return end;
                    }
                }
                outbound = self.rx.recv() => {
                    let Some(Outbound { req_id, message }) = outbound else {
                        return End::RoomLost;
                    };
                    if let Err(end) = self.write(req_id.as_deref(), &message).await {
                        return end;
                    }
                }
                alive = session.wait_change() => {
                    // Not a select branch future: it runs to completion even if other
                    // events arrive meanwhile.
                    if !alive || !session.follow_change().await {
                        return End::RoomLost;
                    }
                }
                () = sleep_until(idle_at) => return End::Idle,
                _ = self.shutdown.changed() => return End::Shutdown,
            }
        }
    }

    async fn on_frame(
        &mut self,
        session: &Session,
        frame: Option<Result<Message, axum::Error>>,
    ) -> Result<(), End> {
        let text = match frame {
            None | Some(Err(_) | Ok(Message::Close(_))) => return Err(End::Closed),
            Some(Ok(Message::Ping(_) | Message::Pong(_))) => return Ok(()),
            Some(Ok(Message::Binary(_))) => {
                let error = RoomError::new(ErrorCode::BadRequest, "text frames only");
                return self.write_error(None, &error).await;
            }
            Some(Ok(Message::Text(text))) => text,
        };
        let envelope = match parse_client(text.as_str()) {
            Ok(envelope) => envelope,
            Err(failure) => {
                let message = failure.error.to_message();
                self.write(failure.req_id.as_deref(), &message).await?;
                return if failure.error == ParseError::VersionMismatch {
                    Err(End::Version)
                } else {
                    Ok(())
                };
            }
        };
        let req_id = envelope.req_id;
        if !self.rate_check(req_id.as_deref()).await? {
            return Ok(());
        }
        if let Err(error) = session.send(req_id.clone(), envelope.body).await {
            self.write_error(req_id.as_deref(), &error).await?;
        }
        Ok(())
    }
}

/// Result of the first message.
enum Entry {
    Joined(Session),
    /// Refused, but the socket stays open for another try.
    Retry(RoomError),
    /// Refused; the socket closes.
    Reject(RoomError),
}
