//! The room actor: one task owns one [`RoomState`] and is the only thing that changes it.
//!
//! Every change goes through [`RoomActor::submit`]: apply the op to a clone, append it to the
//! journal, only then swap the clone in and tell people. A failed op or a failed journal write
//! leaves the live state untouched.

use std::collections::{BTreeMap, VecDeque};
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use poker_engine::Event;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tokio::time::Instant;

use super::handle::{ConnId, ConnSender, Outbound, RoomHandle, RoomMsg};
use super::state::{Broadcast, HostCommand, Op, Outcome, RoomError, RoomState};
use crate::config::{Limits, Timings};
use crate::protocol::{ClientMessage, ErrorCode, Role, RoomConfig, ServerMessage};
use crate::store::journal::Journal;
use crate::store::{self, snapshot};
use crate::util::token;

/// Wall-clock milliseconds that also follow `tokio::time` (so tests can pause time).
#[derive(Clone, Copy, Debug)]
pub struct Clock {
    base_ms: u64,
    start: Instant,
}

impl Default for Clock {
    fn default() -> Self {
        Clock::new()
    }
}

impl Clock {
    /// Starts counting from the current wall-clock time.
    #[must_use]
    pub fn new() -> Self {
        let base_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |d| u64::try_from(d.as_millis()).unwrap_or(u64::MAX));
        Clock {
            base_ms,
            start: Instant::now(),
        }
    }

    /// Epoch milliseconds now.
    #[must_use]
    pub fn now_ms(&self) -> u64 {
        let elapsed = u64::try_from(self.start.elapsed().as_millis()).unwrap_or(u64::MAX);
        self.base_ms.saturating_add(elapsed)
    }

    fn instant_at(&self, at_ms: u64) -> Instant {
        self.start + Duration::from_millis(at_ms.saturating_sub(self.base_ms))
    }
}

/// Why an actor stopped.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ExitReason {
    /// The host ended the game.
    Ended,
    /// No activity for the room TTL.
    Expired,
    /// Told to stop.
    Closed,
    /// Every handle was dropped.
    Abandoned,
}

/// Everything needed to start a brand new room.
#[derive(Clone, Debug)]
pub struct NewRoom {
    /// Room code.
    pub code: String,
    /// Settings.
    pub config: RoomConfig,
    /// Host's display name.
    pub host_name: String,
    /// Where to persist, if anywhere (the room gets its own folder inside).
    pub data_dir: Option<PathBuf>,
}

/// A started room plus the secrets handed to its creator exactly once.
#[derive(Debug)]
pub struct Created {
    /// Talk to the room.
    pub handle: RoomHandle,
    /// The task; resolves when the room stops.
    pub task: JoinHandle<ExitReason>,
    /// Host proof.
    pub host_token: String,
    /// Host's session token.
    pub session_token: String,
    /// Host's player id.
    pub player_id: String,
}

struct Store {
    dir: PathBuf,
    journal: Journal,
}

struct Conn {
    player_id: String,
    tx: ConnSender,
}

/// Where a message goes.
enum Target {
    All(ServerMessage),
    Player(String, ServerMessage),
    Conn(ConnId, Option<String>, ServerMessage),
}

/// The task state.
pub struct RoomActor {
    state: RoomState,
    limits: Limits,
    timings: Timings,
    clock: Clock,
    store: Option<Store>,
    conns: BTreeMap<ConnId, Conn>,
    inbox: mpsc::Receiver<RoomMsg>,
    /// Earliest time an internal op may run again; stops a spin if one keeps failing.
    internal_floor_ms: u64,
}

fn internal(text: &str) -> RoomError {
    RoomError::new(ErrorCode::InternalError, text)
}

/// Creates a room, persists its first snapshot and starts the actor.
///
/// # Errors
/// A [`RoomError`] for bad settings or name, or `INTERNAL_ERROR` if randomness or disk fail.
pub fn create(
    new: NewRoom,
    limits: &Limits,
    timings: &Timings,
    clock: Clock,
) -> Result<Created, RoomError> {
    let host_token = token::generate().map_err(|_| internal("no randomness"))?;
    let session_token = token::generate().map_err(|_| internal("no randomness"))?;
    let state = RoomState::new(
        new.code.clone(),
        new.config,
        &new.host_name,
        token::hash(&host_token),
        token::hash(&session_token),
        clock.now_ms(),
    )?;
    let store = match new.data_dir {
        Some(root) => {
            let dir = store::room_dir(&root, &new.code);
            snapshot::write(&dir, &state, 0).map_err(|_| internal("cannot write snapshot"))?;
            let journal = Journal::open(&dir, 0).map_err(|_| internal("cannot open journal"))?;
            Some(Store { dir, journal })
        }
        None => None,
    };
    let player_id = state.host_id.clone();
    let (handle, task) = spawn(state, store, limits, timings, clock);
    Ok(Created {
        handle,
        task,
        host_token,
        session_token,
        player_id,
    })
}

/// Rebuilds a room from disk (snapshot plus journal) and starts it.
///
/// # Errors
/// [`store::StoreError`] if the files are missing or corrupt.
pub fn restore(
    dir: PathBuf,
    limits: &Limits,
    timings: &Timings,
    clock: Clock,
) -> Result<(RoomHandle, JoinHandle<ExitReason>), store::StoreError> {
    let restored = store::restore(&dir, timings)?;
    let journal = Journal::open(&dir, restored.last_seq)?;
    let state = restored.state;
    Ok(spawn(
        state,
        Some(Store { dir, journal }),
        limits,
        timings,
        clock,
    ))
}

fn spawn(
    state: RoomState,
    store: Option<Store>,
    limits: &Limits,
    timings: &Timings,
    clock: Clock,
) -> (RoomHandle, JoinHandle<ExitReason>) {
    let (tx, inbox) = mpsc::channel(limits.room_inbox);
    let handle = RoomHandle::new(state.code.clone(), tx);
    let actor = RoomActor {
        state,
        limits: limits.clone(),
        timings: timings.clone(),
        clock,
        store,
        conns: BTreeMap::new(),
        inbox,
        internal_floor_ms: 0,
    };
    (handle, tokio::spawn(actor.run()))
}

impl RoomActor {
    async fn run(mut self) -> ExitReason {
        loop {
            if let Some(reason) = self.run_due() {
                return reason;
            }
            let wake = self.clock.instant_at(self.next_wake_ms());
            tokio::select! {
                msg = self.inbox.recv() => match msg {
                    None => return ExitReason::Abandoned,
                    Some(RoomMsg::Close) => return ExitReason::Closed,
                    Some(msg) => self.on_msg(msg),
                },
                () = tokio::time::sleep_until(wake) => {}
            }
            if self.state.ended {
                self.finish_ended();
                return ExitReason::Ended;
            }
        }
    }

    fn expiry_ms(&self) -> u64 {
        let ttl = u64::try_from(self.limits.room_ttl.as_millis()).unwrap_or(u64::MAX);
        self.state.last_activity_ms.saturating_add(ttl)
    }

    fn next_wake_ms(&self) -> u64 {
        let due = self.state.next_wakeup_ms(&self.timings).unwrap_or(u64::MAX);
        due.max(self.internal_floor_ms).min(self.expiry_ms())
    }

    /// Runs whatever time has made due: turn timeout, presence check, room expiry.
    fn run_due(&mut self) -> Option<ExitReason> {
        let now = self.clock.now_ms();
        if now >= self.expiry_ms() {
            self.broadcast(Target::All(ServerMessage::RoomExpired));
            return Some(ExitReason::Expired);
        }
        if now < self.internal_floor_ms {
            return None;
        }
        let turn_due = !self.state.game.table.paused
            && self
                .state
                .turn_deadline_ms
                .is_some_and(|deadline| now >= deadline);
        let tick_due = self.state.presence.as_ref().map_or_else(
            || {
                self.state
                    .next_wakeup_ms(&self.timings)
                    .is_some_and(|at| now >= at)
            },
            |p| now >= p.deadline_ms,
        );
        if turn_due {
            self.internal_floor_ms = now.saturating_add(250);
            if let Err(error) = self.submit(&Op::Timeout { at_ms: now }) {
                tracing::warn!(code = ?error.code, "turn timeout was refused");
            }
        } else if tick_due {
            self.internal_floor_ms = now.saturating_add(250);
            let _ = self.submit(&Op::Tick { at_ms: now });
        }
        None
    }

    fn finish_ended(&mut self) {
        self.write_snapshot();
        self.broadcast(Target::All(ServerMessage::RoomExpired));
    }

    // -----------------------------------------------------------------------------------------
    // Changing state
    // -----------------------------------------------------------------------------------------

    /// Apply, journal, swap in, tell everybody. See the module docs.
    fn submit(&mut self, op: &Op) -> Result<Outcome, RoomError> {
        let mut next = self.state.clone();
        let outcome = next.apply(op.clone(), &self.timings)?;
        if !outcome.changed {
            return Ok(outcome);
        }
        if let Some(store) = self.store.as_mut()
            && let Err(error) = store.journal.append(op)
        {
            tracing::error!(%error, "journal write failed; change rejected");
            return Err(internal("could not persist the change"));
        }
        self.state = next;
        self.publish(&outcome);
        if outcome.engine_events.iter().any(snapshot_worthy) {
            self.write_snapshot();
        }
        Ok(outcome)
    }

    fn write_snapshot(&mut self) {
        let Some(store) = self.store.as_mut() else {
            return;
        };
        let seq = store.journal.last_seq();
        let result =
            snapshot::write(&store.dir, &self.state, seq).and_then(|()| store.journal.truncate());
        if let Err(error) = result {
            tracing::error!(%error, "snapshot failed; the journal still has everything");
        }
    }

    fn publish(&mut self, outcome: &Outcome) {
        let view = self.view();
        self.broadcast(Target::All(ServerMessage::StateUpdate {
            state_version: self.state.state_version,
            view,
        }));
        for item in &outcome.broadcasts {
            let target = match item {
                Broadcast::All(message) => Target::All(message.clone()),
                Broadcast::To(player, message) => Target::Player(player.clone(), message.clone()),
            };
            self.broadcast(target);
        }
    }

    fn view(&self) -> crate::protocol::RoomView {
        self.state
            .view(&|id| self.conns.values().any(|c| c.player_id == id))
    }

    // -----------------------------------------------------------------------------------------
    // Sending
    // -----------------------------------------------------------------------------------------

    /// Delivers a message; connections that cannot take it are dropped, and their disappearance
    /// is announced in turn.
    fn broadcast(&mut self, first: Target) {
        let mut queue = VecDeque::from([first]);
        while let Some(target) = queue.pop_front() {
            for conn in self.deliver(&target) {
                if let Some(notice) = self.remove_conn(conn) {
                    queue.push_back(notice);
                }
            }
        }
    }

    fn deliver(&self, target: &Target) -> Vec<ConnId> {
        let mut dead = Vec::new();
        for (id, conn) in &self.conns {
            let outbound = match target {
                Target::All(message) => Outbound {
                    req_id: None,
                    message: message.clone(),
                },
                Target::Player(player, message) if *player == conn.player_id => Outbound {
                    req_id: None,
                    message: message.clone(),
                },
                Target::Conn(only, req_id, message) if only == id => Outbound {
                    req_id: req_id.clone(),
                    message: message.clone(),
                },
                _ => continue,
            };
            if conn.tx.try_send(outbound).is_err() {
                tracing::warn!(conn = id, player = %conn.player_id, "dropping slow or closed connection");
                dead.push(*id);
            }
        }
        dead
    }

    /// Forgets a connection. Returns the `PLAYER_CONNECTION` notice if it was the player's last.
    fn remove_conn(&mut self, conn: ConnId) -> Option<Target> {
        let removed = self.conns.remove(&conn)?;
        if self
            .conns
            .values()
            .any(|c| c.player_id == removed.player_id)
        {
            return None;
        }
        self.connection_notice(&removed.player_id, false)
    }

    fn connection_notice(&self, player_id: &str, is_connected: bool) -> Option<Target> {
        let seat_index = self.state.players.get(player_id)?.seat?;
        Some(Target::All(ServerMessage::PlayerConnection {
            seat_index,
            player_id: player_id.to_owned(),
            is_connected,
        }))
    }

    fn reply(&mut self, conn: ConnId, req_id: Option<String>, message: ServerMessage) {
        self.broadcast(Target::Conn(conn, req_id, message));
    }

    fn reply_error(&mut self, conn: ConnId, req_id: Option<String>, error: &RoomError) {
        self.reply(conn, req_id, error.to_message());
    }

    // -----------------------------------------------------------------------------------------
    // Inbox
    // -----------------------------------------------------------------------------------------

    fn on_msg(&mut self, msg: RoomMsg) {
        match msg {
            RoomMsg::Join {
                conn,
                tx,
                req_id,
                name,
                spectator,
                seat,
                reply,
            } => {
                let result = self.on_join(conn, tx, req_id, name, spectator, seat);
                let _ = reply.send(result);
            }
            RoomMsg::Resume {
                conn,
                tx,
                req_id,
                session_token,
                host_token,
                reply,
            } => {
                let result =
                    self.on_resume(conn, tx, req_id, &session_token, host_token.as_deref());
                let _ = reply.send(result);
            }
            RoomMsg::Client {
                conn,
                req_id,
                message,
            } => self.on_client(conn, req_id, message),
            RoomMsg::Detach { conn } => {
                if let Some(notice) = self.remove_conn(conn) {
                    self.broadcast(notice);
                }
            }
            RoomMsg::Close => {}
        }
    }

    fn on_join(
        &mut self,
        conn: ConnId,
        tx: ConnSender,
        req_id: Option<String>,
        name: String,
        spectator: bool,
        seat: Option<u8>,
    ) -> Result<String, RoomError> {
        let session = token::generate().map_err(|_| internal("no randomness"))?;
        let player_id = self.state.peek_id(spectator);
        let op = Op::Join {
            player_id: player_id.clone(),
            name,
            spectator,
            seat,
            token_hash: token::hash(&session),
            at_ms: self.clock.now_ms(),
        };
        self.submit(&op)?;
        let (role, seat_index) = self
            .state
            .players
            .get(&player_id)
            .map_or((Role::Spectator, None), |p| (p.role, p.seat));
        let notice = self.attach(conn, &player_id, tx);
        self.reply(
            conn,
            req_id.clone(),
            ServerMessage::Joined {
                player_id: player_id.clone(),
                role,
                seat_index,
                session_token: session,
            },
        );
        self.send_snapshot(conn, req_id, &player_id);
        if let Some(notice) = notice {
            self.broadcast(notice);
        }
        Ok(player_id)
    }

    fn on_resume(
        &mut self,
        conn: ConnId,
        tx: ConnSender,
        req_id: Option<String>,
        session: &str,
        host_token: Option<&str>,
    ) -> Result<String, RoomError> {
        let invalid = || RoomError::new(ErrorCode::InvalidSession, "session token not recognised");
        let player = self.state.player_for_token(session).ok_or_else(invalid)?;
        if player.id == self.state.host_id
            && !host_token.is_some_and(|t| self.state.host_token_matches(t))
        {
            return Err(invalid());
        }
        let player_id = player.id.clone();
        let notice = self.attach(conn, &player_id, tx);
        self.send_snapshot(conn, req_id, &player_id);
        if let Some(notice) = notice {
            self.broadcast(notice);
        }
        Ok(player_id)
    }

    /// Registers the connection. Returns the `PLAYER_CONNECTION` notice to send once the new
    /// connection has its own `JOINED`/`SNAPSHOT` (so it never sees the notice first).
    fn attach(&mut self, conn: ConnId, player_id: &str, tx: ConnSender) -> Option<Target> {
        let first = !self.conns.values().any(|c| c.player_id == player_id);
        self.conns.insert(
            conn,
            Conn {
                player_id: player_id.to_owned(),
                tx,
            },
        );
        if first {
            self.connection_notice(player_id, true)
        } else {
            None
        }
    }

    fn send_snapshot(&mut self, conn: ConnId, req_id: Option<String>, player_id: &str) {
        let next_action_seq = self
            .state
            .players
            .get(player_id)
            .map_or(0, |p| p.next_action_seq);
        let snapshot = ServerMessage::Snapshot {
            state_version: self.state.state_version,
            server_time: self.clock.now_ms(),
            next_action_seq,
            view: self.view(),
        };
        self.reply(conn, req_id, snapshot);
        if let Some(prompt) = self.turn_prompt_for(player_id) {
            self.reply(conn, None, prompt);
        }
    }

    fn turn_prompt_for(&self, player_id: &str) -> Option<ServerMessage> {
        let (seat, legal) = self.state.game.legal_actions()?;
        let player = self.state.players.get(player_id)?;
        (player.seat == Some(seat.get())).then(|| ServerMessage::TurnPrompt {
            player_id: player.id.clone(),
            seat_index: seat.get(),
            turn_deadline_ms: self.state.turn_deadline_ms,
            next_action_seq: player.next_action_seq,
            legal,
        })
    }

    fn on_client(&mut self, conn: ConnId, req_id: Option<String>, message: ClientMessage) {
        let Some(player_id) = self.conns.get(&conn).map(|c| c.player_id.clone()) else {
            let error = RoomError::new(ErrorCode::NotAuthenticated, "join or resume first");
            self.reply_error(conn, req_id, &error);
            return;
        };
        let at_ms = self.clock.now_ms();
        let host = |command| Op::Host {
            by: player_id.clone(),
            command,
            at_ms,
        };
        let op = match message {
            ClientMessage::Ping { t } => {
                self.reply(conn, req_id, ServerMessage::Pong { t });
                return;
            }
            ClientMessage::GameAction { action_seq, action } => Op::Act {
                player_id: player_id.clone(),
                action_seq,
                action,
                at_ms,
            },
            ClientMessage::StartHand => host(HostCommand::StartHand),
            ClientMessage::BeginShowdown => host(HostCommand::BeginShowdown),
            ClientMessage::ResolveShowdown { allocations } => {
                host(HostCommand::ResolveShowdown { allocations })
            }
            ClientMessage::Undo => host(HostCommand::Undo),
            ClientMessage::Pause { reason } => host(HostCommand::Pause { reason }),
            ClientMessage::ResumeGame => host(HostCommand::ResumeGame),
            ClientMessage::ApproveRebuy {
                player_id: target,
                amount,
            } => host(HostCommand::ApproveRebuy {
                player_id: target,
                amount,
            }),
            ClientMessage::Kick { player_id: target } => {
                host(HostCommand::Kick { player_id: target })
            }
            ClientMessage::RoomConfigure { config } => host(HostCommand::Configure { config }),
            ClientMessage::EndGame => host(HostCommand::EndGame),
            ClientMessage::RequestRebuy { amount } => Op::RequestRebuy {
                player_id: player_id.clone(),
                amount,
                at_ms,
            },
            ClientMessage::SetSittingOut { sitting_out } => Op::SetSittingOut {
                player_id: player_id.clone(),
                sitting_out,
                at_ms,
            },
            ClientMessage::LeaveTable => Op::LeaveTable {
                player_id: player_id.clone(),
                at_ms,
            },
            ClientMessage::PresenceVote {
                player_id: subject,
                still_playing,
            } => Op::PresenceVote {
                voter: player_id.clone(),
                subject,
                still_playing,
                at_ms,
            },
            ClientMessage::PresenceAck => Op::PresenceAck {
                player_id: player_id.clone(),
                at_ms,
            },
            ClientMessage::CreateRoom { .. }
            | ClientMessage::JoinRoom { .. }
            | ClientMessage::Resume { .. } => {
                let error = RoomError::new(ErrorCode::BadRequest, "already in a room");
                self.reply_error(conn, req_id, &error);
                return;
            }
            ClientMessage::Unknown => {
                let error = RoomError::new(ErrorCode::UnknownMessage, "unknown message type");
                self.reply_error(conn, req_id, &error);
                return;
            }
        };
        match self.submit(&op) {
            Ok(outcome) => {
                let next_action_seq = self
                    .state
                    .players
                    .get(&player_id)
                    .map_or(0, |p| p.next_action_seq);
                let ack = ServerMessage::Ack {
                    next_action_seq,
                    duplicate: outcome.duplicate,
                };
                self.reply(conn, req_id, ack);
            }
            Err(error) => self.reply_error(conn, req_id, &error),
        }
    }
}

fn snapshot_worthy(event: &Event) -> bool {
    matches!(
        event,
        Event::HandEnded { .. } | Event::BlindsConfigured | Event::RebuyApplied { .. }
    )
}
