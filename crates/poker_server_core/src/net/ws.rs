//! One WebSocket connection: authenticate with `CREATE_ROOM` / `JOIN_ROOM` / `RESUME`, then
//! pass messages between the socket and the room.
//!
//! Hygiene (`docs/RESILIENCE_AND_CRASH_HANDLING.md` 3.6): 16 KiB frames, an idle timeout that
//! only well-formed inbound frames reset, a deadline for the first message, a token bucket that
//! charges every inbound data frame (garbage included) with three strikes, per-IP limits on
//! failed joins and on room creation that outlive the connection, and a write timeout so a
//! stuck peer cannot hold the task.

use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{ConnectInfo, State};
use axum::http::{HeaderMap, StatusCode, header};
use axum::response::{IntoResponse, Response};
use tokio::sync::watch;
use tokio::time::{Instant, sleep_until, timeout, timeout_at};

use super::NetState;
use super::guards::{ConnectionGuard, TokenBucket, origin_allowed};
use crate::protocol::{
    ClientMessage, ErrorCode, MAX_MESSAGE_BYTES, ParseError, ServerMessage, encode_server,
    parse_client,
};
use crate::room::handle::{ConnReceiver, ConnSender};
use crate::room::session::Session;
use crate::room::state::RoomError;

/// `GET /v1/ws`
pub(crate) async fn upgrade(
    State(net): State<Arc<NetState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    ws: WebSocketUpgrade,
) -> Response {
    let header_text = |name| headers.get(name).and_then(|value| value.to_str().ok());
    let origin = headers
        .get(header::ORIGIN)
        .map(|value| value.to_str().unwrap_or("null"));
    if !origin_allowed(
        origin,
        header_text(header::HOST),
        &net.limits.allowed_origins,
    ) {
        tracing::warn!(peer = %addr.ip(), "websocket refused: foreign origin");
        return StatusCode::FORBIDDEN.into_response();
    }
    let Some(guard) = net.ip_limiter.try_acquire(addr.ip()) else {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    };
    ws.max_message_size(MAX_MESSAGE_BYTES)
        .max_frame_size(MAX_MESSAGE_BYTES)
        .on_upgrade(move |socket| serve(socket, net, addr.ip(), guard))
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
    peer: IpAddr,
    tx: ConnSender,
    rx: ConnReceiver,
    conn_id: u64,
    bucket: TokenBucket,
    strikes: u32,
    shutdown: watch::Receiver<bool>,
    /// Holds the per-IP slot until the task ends, however it ends.
    _guard: ConnectionGuard,
}

/// What one inbound frame turned out to be.
enum Inbound {
    /// A well-formed request (the idle timer restarts).
    Request(Option<String>, ClientMessage),
    /// A WebSocket ping or pong (the idle timer restarts, nothing else happens).
    Control,
    /// Garbage, already answered with an error (the idle timer does not restart).
    Rejected,
}

async fn serve(socket: WebSocket, net: Arc<NetState>, peer: IpAddr, guard: ConnectionGuard) {
    let (tx, rx) = ConnSender::channel(net.limits.outbound_queue);
    let conn_id = net.registry.next_conn_id();
    let bucket = TokenBucket::new(
        net.limits.rate_per_second.saturating_mul(60),
        net.limits.rate_burst,
        Instant::now(),
    );
    let shutdown = net.shutdown.clone();
    let mut connection = Connection {
        socket,
        net,
        peer,
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

    // -----------------------------------------------------------------------------------------
    // Reading
    // -----------------------------------------------------------------------------------------

    /// Charges one token. After the third refusal the connection is closed.
    async fn charge(&mut self) -> Result<bool, End> {
        if self.bucket.allow(Instant::now()) {
            return Ok(true);
        }
        self.strikes += 1;
        let error = RoomError::new(ErrorCode::RateLimited, "slow down");
        self.write_error(None, &error).await?;
        if self.strikes >= self.net.limits.rate_strikes {
            return Err(End::RateLimited);
        }
        Ok(false)
    }

    /// Classifies a frame. Every text or binary frame is charged *before* it is parsed, so
    /// garbage costs as much as a real request.
    async fn read(&mut self, frame: Option<Result<Message, axum::Error>>) -> Result<Inbound, End> {
        let text = match frame {
            None | Some(Err(_) | Ok(Message::Close(_))) => return Err(End::Closed),
            Some(Ok(Message::Ping(_) | Message::Pong(_))) => return Ok(Inbound::Control),
            Some(Ok(Message::Binary(_))) => {
                if self.charge().await? {
                    let error = RoomError::new(ErrorCode::BadRequest, "text frames only");
                    self.write_error(None, &error).await?;
                }
                return Ok(Inbound::Rejected);
            }
            Some(Ok(Message::Text(text))) => text,
        };
        if !self.charge().await? {
            return Ok(Inbound::Rejected);
        }
        match parse_client(text.as_str()) {
            Ok(envelope) => Ok(Inbound::Request(envelope.req_id, envelope.body)),
            Err(failure) => {
                let message = failure.error.to_message();
                self.write(failure.req_id.as_deref(), &message).await?;
                if failure.error == ParseError::VersionMismatch {
                    Err(End::Version)
                } else {
                    Ok(Inbound::Rejected)
                }
            }
        }
    }

    // -----------------------------------------------------------------------------------------
    // Before the room: the first message decides who this connection is
    // -----------------------------------------------------------------------------------------

    async fn authenticate(&mut self) -> Result<Session, End> {
        let deadline = Instant::now() + self.net.limits.auth_timeout;
        loop {
            let Ok(frame) = timeout_at(deadline, self.socket.recv()).await else {
                return Err(End::AuthTimeout);
            };
            let Inbound::Request(req_id, body) = self.read(frame).await? else {
                continue;
            };
            if let ClientMessage::Ping { t } = body {
                // Allowed before joining so a client can test the link.
                self.write(req_id.as_deref(), &ServerMessage::Pong { t })
                    .await?;
                continue;
            }
            match self.try_enter(req_id.clone(), body).await {
                Entry::Joined(session) => return Ok(session),
                Entry::Retry(error) => self.write_error(req_id.as_deref(), &error).await?,
                Entry::Reject(error) => {
                    self.write_error(req_id.as_deref(), &error).await?;
                    return Err(End::BadAuth);
                }
            }
        }
    }

    /// Tries to attach to a room. Wrong codes and tokens are counted per IP address, so
    /// reconnecting does not reset the budget of someone scanning for rooms.
    async fn try_enter(&mut self, req_id: Option<String>, message: ClientMessage) -> Entry {
        let peer = self.peer;
        let net = Arc::clone(&self.net);
        let (conn, tx) = (self.conn_id, self.tx.clone());
        let is_join = matches!(
            message,
            ClientMessage::JoinRoom { .. } | ClientMessage::Resume { .. }
        );
        if is_join && !net.join_failures.allowed(peer) {
            return Entry::Reject(RoomError::new(
                ErrorCode::RateLimited,
                "too many failed attempts, try again later",
            ));
        }
        let result = match message {
            ClientMessage::CreateRoom { host_name, config } => {
                if net.mode == crate::ServerMode::Host {
                    return Entry::Reject(RoomError::new(
                        ErrorCode::BadRequest,
                        "rooms are created by the host app, not over the network",
                    ));
                }
                if !net.create_limiter.check(peer) {
                    return Entry::Reject(RoomError::new(
                        ErrorCode::RateLimited,
                        "too many rooms created, try again later",
                    ));
                }
                net.registry
                    .create_room(conn, tx, req_id, host_name, config)
                    .await
            }
            ClientMessage::JoinRoom {
                room_code,
                name,
                seat_index,
                spectator,
            } => {
                net.registry
                    .join_room(&room_code, conn, tx, req_id, name, spectator, seat_index)
                    .await
            }
            ClientMessage::Resume {
                room_code,
                session_token,
                host_token,
                last_state_version: _,
            } => {
                net.registry
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
            Err(error) => {
                if is_join {
                    net.join_failures.record_failure(peer);
                }
                match error.code {
                    // A wrong name or a taken seat can be fixed on the same socket.
                    ErrorCode::NameInvalid
                    | ErrorCode::SeatOccupied
                    | ErrorCode::AlreadySeated
                    | ErrorCode::BadRequest
                    | ErrorCode::InvalidAmount => Entry::Retry(error),
                    _ => Entry::Reject(error),
                }
            }
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
                    match self.read(frame).await {
                        Ok(Inbound::Request(req_id, body)) => {
                            idle_at = Instant::now() + self.net.limits.idle_timeout;
                            if let Err(error) = session.send(req_id.clone(), body).await
                                && let Err(end) = self.write_error(req_id.as_deref(), &error).await
                            {
                                return end;
                            }
                        }
                        Ok(Inbound::Control) => {
                            idle_at = Instant::now() + self.net.limits.idle_timeout;
                        }
                        Ok(Inbound::Rejected) => {}
                        Err(end) => return end,
                    }
                }
                outbound = self.rx.recv() => {
                    let Some(outbound) = outbound else {
                        return End::RoomLost;
                    };
                    if let Err(end) = self.write(outbound.req_id.as_deref(), &outbound.message).await {
                        return end;
                    }
                }
                alive = session.wait_change() => {
                    // Not a select branch future: it runs to completion even if other
                    // events arrive meanwhile.
                    if !alive || !session.follow_change().await {
                        // The room is over. Deliver what it said last (for example
                        // ROOM_EXPIRED) before closing.
                        return self.flush_queue().await.unwrap_or_else(|end| end);
                    }
                }
                () = sleep_until(idle_at) => return End::Idle,
                _ = self.shutdown.changed() => return End::Shutdown,
            }
        }
    }

    /// Writes everything already queued for this connection, then reports the room as lost.
    async fn flush_queue(&mut self) -> Result<End, End> {
        while let Some(outbound) = self.rx.try_recv() {
            self.write(outbound.req_id.as_deref(), &outbound.message)
                .await?;
        }
        Ok(End::RoomLost)
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
