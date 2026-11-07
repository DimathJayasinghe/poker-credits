//! The room actor: one task owns one [`RoomState`] and is the only thing that changes it.
//!
//! Every change goes through [`RoomActor::submit`]: apply the op to a clone, append it to the
//! journal, only then swap the clone in and tell people. A failed op or a failed journal write
//! leaves the live state untouched.

use std::collections::{BTreeMap, VecDeque};
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use poker_engine::{Event, MAX_SEATS, Phase};
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tokio::time::Instant;

use super::absence::Absence;
use super::bots::BotDriver;
use super::handle::{ConnId, ConnSender, JoinOk, Outbound, RoomHandle, RoomInfo, RoomMsg};
use super::state::{Broadcast, HostCommand, Op, Outcome, RoomError, RoomState};
use crate::cards::{Entropy, OsEntropy, shuffled_deck};
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

/// How long a solo game waits to be resumed.
const SOLO_TTL: Duration = Duration::from_hours(24 * 7);

/// What a room needs from the outside world: time and randomness. Both can be replaced in tests.
pub struct Deps {
    /// Wall clock (follows `tokio::time`).
    pub clock: Clock,
    /// Where the shuffle comes from.
    pub entropy: Box<dyn Entropy>,
}

impl Deps {
    /// Real randomness from the operating system.
    #[must_use]
    pub fn new(clock: Clock) -> Self {
        Deps {
            clock,
            entropy: Box::new(OsEntropy),
        }
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
    absence: Absence,
    entropy: Box<dyn Entropy>,
    /// The computer players of a solo game (empty otherwise).
    bots: BotDriver,
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
    create_with(new, limits, timings, Deps::new(clock))
}

/// [`create`] with explicit dependencies (a scripted shuffle in tests).
///
/// # Errors
/// As [`create`].
pub fn create_with(
    new: NewRoom,
    limits: &Limits,
    timings: &Timings,
    deps: Deps,
) -> Result<Created, RoomError> {
    let Deps { clock, mut entropy } = deps;
    let host_token = token::generate().map_err(|_| internal("no randomness"))?;
    let session_token = token::generate().map_err(|_| internal("no randomness"))?;
    let mut state = RoomState::new(
        new.code.clone(),
        new.config,
        &new.host_name,
        token::hash(&host_token),
        token::hash(&session_token),
        clock.now_ms(),
    )?;
    if state.is_solo() {
        // Everything about the opponents follows from one seed, which the snapshot keeps.
        let mut seed = [0_u8; 8];
        entropy
            .fill(&mut seed)
            .map_err(|_| internal("no randomness"))?;
        state.seat_bots(u64::from_le_bytes(seed))?;
    }
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
    let (handle, task) = spawn(state, store, limits, timings, Deps { clock, entropy });
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
    restore_with(dir, limits, timings, Deps::new(clock))
}

/// [`restore`] with explicit dependencies.
///
/// # Errors
/// As [`restore`].
pub fn restore_with(
    dir: PathBuf,
    limits: &Limits,
    timings: &Timings,
    deps: Deps,
) -> Result<(RoomHandle, JoinHandle<ExitReason>), store::StoreError> {
    let clock = deps.clock;
    let restored = store::restore(&dir, timings)?;
    let mut journal = Journal::open(&dir, restored.last_seq)?;
    let mut state = restored.state;
    // Downtime must not cost the player on turn their clock. Journaled, so replay agrees.
    let recover = Op::Recover {
        at_ms: clock.now_ms(),
    };
    let mut recovered = state.clone();
    if let Ok(outcome) = recovered.apply(recover.clone(), timings)
        && outcome.changed
    {
        // A full disk must not keep the room from coming back: a turn that times out is better
        // than a room that stays down, and the next journal write will report the problem.
        match journal.append(&recover) {
            Ok(_) => state = recovered,
            Err(error) => tracing::warn!(%error, "could not journal the clock restart; skipped"),
        }
    }
    Ok(spawn(
        state,
        Some(Store { dir, journal }),
        limits,
        timings,
        deps,
    ))
}

fn spawn(
    state: RoomState,
    store: Option<Store>,
    limits: &Limits,
    timings: &Timings,
    deps: Deps,
) -> (RoomHandle, JoinHandle<ExitReason>) {
    let Deps { clock, entropy } = deps;
    let (tx, inbox) = mpsc::channel(limits.room_inbox);
    let handle = RoomHandle::new(state.code.clone(), tx);
    let absence = Absence::new(&state, clock.now_ms());
    let bots = BotDriver::new(&state);
    let mut actor = RoomActor {
        state,
        limits: limits.clone(),
        timings: timings.clone(),
        clock,
        store,
        conns: BTreeMap::new(),
        inbox,
        internal_floor_ms: 0,
        absence,
        entropy,
        bots,
    };
    // A room that went down between the last bet and the payout finishes that hand now.
    actor.settle_showdown();
    actor.settle_solo();
    (handle, tokio::spawn(actor.run()))
}

impl RoomActor {
    async fn run(mut self) -> ExitReason {
        loop {
            if let Some(reason) = self.run_due() {
                return reason;
            }
            // What this loop just did may have handed a turn to a bot; plan it before sleeping.
            self.plan_bots(self.clock.now_ms());
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
        let mut ttl = self.limits.room_ttl;
        if self.state.is_solo() {
            // Somebody who puts a solo game down expects to pick it up later.
            ttl = ttl.max(SOLO_TTL);
        }
        let ttl = u64::try_from(ttl.as_millis()).unwrap_or(u64::MAX);
        self.state.last_activity_ms.saturating_add(ttl)
    }

    fn next_wake_ms(&self) -> u64 {
        let due = [
            self.state.next_wakeup_ms(&self.timings),
            self.absence.next_due_ms(&self.state, &self.timings),
            self.state.needs_auto_showdown().then_some(0),
            self.bots.next_due_ms(),
        ]
        .into_iter()
        .flatten()
        .min()
        .unwrap_or(u64::MAX);
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
        if self.state.needs_auto_showdown() {
            // Normally done in the same breath as the last bet; this only runs if that failed.
            self.internal_floor_ms = now.saturating_add(2_000);
            self.settle_showdown();
            return None;
        }
        self.plan_bots(now);
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
        } else if let Some(op) = self.absence.due_op(&self.state, &self.timings, now) {
            self.internal_floor_ms = now.saturating_add(250);
            if let Err(error) = self.submit(&op) {
                tracing::warn!(code = ?error.code, "absence action was refused");
            }
        } else if let Some(op) = self.bots.due_act(&self.state, now) {
            self.run_bot_act(&op, now);
        } else if self.bots.hand_due(now) {
            self.deal_next_solo_hand(now);
        } else if tick_due {
            self.internal_floor_ms = now.saturating_add(250);
            let _ = self.submit(&Op::Tick { at_ms: now });
        }
        None
    }

    fn plan_bots(&mut self, now: u64) {
        let human_here = self
            .conns
            .values()
            .any(|conn| conn.player_id == self.state.host_id);
        self.bots.plan(&self.state, now, human_here, &self.timings);
    }

    /// Journals a computer player's action. If the room refuses it (it should not), the bot
    /// checks or folds instead, so a hand can never stall on a bot.
    fn run_bot_act(&mut self, op: &Op, now: u64) {
        let Err(error) = self.submit(op) else {
            return;
        };
        tracing::warn!(code = ?error.code, "a computer player's action was refused");
        if let Some(fallback) = BotDriver::fallback_act(&self.state, now)
            && let Err(error) = self.submit(&fallback)
        {
            tracing::error!(code = ?error.code, "a computer player's fallback was refused");
            self.internal_floor_ms = now.saturating_add(250);
        }
    }

    /// Deals the next hand of a solo game: nobody there taps a button.
    fn deal_next_solo_hand(&mut self, now: u64) {
        self.bots.hand_attempted();
        let Ok(deck) = shuffled_deck(&mut *self.entropy) else {
            tracing::error!("could not shuffle for the next solo hand");
            self.internal_floor_ms = now.saturating_add(250);
            return;
        };
        let op = Op::Host {
            by: self.state.host_id.clone(),
            command: HostCommand::StartHand { deck: Some(deck) },
            at_ms: now,
        };
        if let Err(error) = self.submit(&op) {
            tracing::warn!(code = ?error.code, "the next solo hand could not be dealt");
            self.internal_floor_ms = now.saturating_add(250);
        }
    }

    fn finish_ended(&mut self) {
        self.write_snapshot();
        self.broadcast(Target::All(ServerMessage::RoomExpired));
    }

    // -----------------------------------------------------------------------------------------
    // Changing state
    // -----------------------------------------------------------------------------------------

    /// Apply, journal, swap in, tell everybody. See the module docs. A virtual room whose betting
    /// just ended then runs its own showdown.
    fn submit(&mut self, op: &Op) -> Result<Outcome, RoomError> {
        let outcome = self.submit_one(op)?;
        self.settle_showdown();
        self.settle_solo();
        Ok(outcome)
    }

    /// Ranks players who just went out of a solo game and names the winner, as its own journaled
    /// op, once the hand is paid.
    fn settle_solo(&mut self) {
        if let Some(op) = self.state.solo_sweep_op(self.clock.now_ms())
            && let Err(error) = self.submit_one(&op)
        {
            tracing::error!(code = ?error.code, "solo sweep was refused");
        }
    }

    /// Pays a virtual hand whose betting is over, as its own journaled op. Refused or failed, it
    /// leaves the state alone and is tried again later.
    fn settle_showdown(&mut self) {
        match self.state.auto_showdown_op(self.clock.now_ms()) {
            Ok(Some(op)) => {
                if let Err(error) = self.submit_one(&op) {
                    tracing::error!(code = ?error.code, "automatic showdown was refused");
                }
            }
            Ok(None) => {}
            Err(error) => tracing::error!(code = ?error.code, "automatic showdown could not rank"),
        }
    }

    fn submit_one(&mut self, op: &Op) -> Result<Outcome, RoomError> {
        let before = self.state.game.table.phase;
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
        self.bots
            .observe(before, &outcome.engine_events, &self.state);
        self.absence
            .note_events(&outcome.engine_events, self.clock.now_ms());
        self.absence.prune(&self.state);
        self.revoke_removed();
        self.publish(&outcome);
        if outcome.engine_events.iter().any(snapshot_worthy) {
            self.write_snapshot();
        }
        Ok(outcome)
    }

    /// Closes the connections of people who are no longer in the room (kicked, voted out).
    /// They get one `INVALID_SESSION` error, then their channel is dropped, so they receive no
    /// further state and cannot keep acting on an old connection.
    fn revoke_removed(&mut self) {
        let removed: Vec<ConnId> = self
            .conns
            .iter()
            .filter(|(_, conn)| !self.state.players.contains_key(&conn.player_id))
            .map(|(id, _)| *id)
            .collect();
        for id in removed {
            if let Some(conn) = self.conns.remove(&id) {
                let _sent = conn.tx.try_send(Outbound {
                    req_id: None,
                    message: RoomError::new(
                        ErrorCode::InvalidSession,
                        "you were removed from the room",
                    )
                    .to_message(),
                });
                conn.tx.close();
            }
        }
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
        // A computer player is always at the table, like anybody with a live connection.
        self.state
            .view(&|id| self.state.is_bot(id) || self.conns.values().any(|c| c.player_id == id))
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
            if !conn.tx.try_send(outbound) {
                tracing::warn!(conn = id, player = %conn.player_id, "dropping slow or closed connection");
                dead.push(*id);
            }
        }
        dead
    }

    /// Forgets a connection. Returns the `PLAYER_CONNECTION` notice if it was the player's last.
    fn remove_conn(&mut self, conn: ConnId) -> Option<Target> {
        let removed = self.conns.remove(&conn)?;
        removed.tx.close();
        if self
            .conns
            .values()
            .any(|c| c.player_id == removed.player_id)
        {
            return None;
        }
        self.absence.gone(&removed.player_id, self.clock.now_ms());
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

    fn info(&self) -> RoomInfo {
        RoomInfo {
            host_name: self
                .state
                .players
                .get(&self.state.host_id)
                .map(|host| host.name.clone())
                .unwrap_or_default(),
            player_count: self.state.game.table.seats.len(),
            max_players: usize::from(MAX_SEATS),
            in_progress: self.state.game.table.phase != Phase::Lobby,
            card_mode: self.state.config.card_mode,
        }
    }

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
            RoomMsg::Info { reply } => {
                let _sent = reply.send(self.info());
            }
            RoomMsg::Close => {}
            #[cfg(feature = "test-hooks")]
            #[allow(clippy::panic, reason = "deliberate crash for supervision tests")]
            RoomMsg::Panic => panic!("test-hooks: deliberate room panic"),
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
    ) -> Result<JoinOk, RoomError> {
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
                session_token: session.clone(),
            },
        );
        self.send_snapshot(conn, req_id, &player_id);
        if let Some(notice) = notice {
            self.broadcast(notice);
        }
        Ok(JoinOk {
            player_id,
            session_token: session,
        })
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
        self.supersede(conn, player_id);
        self.absence.present(player_id);
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

    /// One live connection per participant: older ones are told `SUPERSEDED` and closed.
    fn supersede(&mut self, keep: ConnId, player_id: &str) {
        let stale: Vec<ConnId> = self
            .conns
            .iter()
            .filter(|(id, c)| **id != keep && c.player_id == player_id)
            .map(|(id, _)| *id)
            .collect();
        for id in stale {
            if let Some(old) = self.conns.remove(&id) {
                let error = RoomError::new(ErrorCode::Superseded, "connected from another device");
                let _sent = old.tx.try_send(Outbound {
                    req_id: None,
                    message: error.to_message(),
                });
                old.tx.close();
            }
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
        // Private cards follow the snapshot to this connection alone, so a reconnect or a second
        // device always gets them back and nobody else ever does.
        if let Some(cards) = self.state.hole_cards_for(player_id) {
            self.reply(conn, None, cards);
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

    /// The host command a message stands for. A virtual room's `StartHand` gets its shuffled
    /// deck here, in the one place that owns the randomness, and it travels in the journaled op.
    fn host_command_for(
        &mut self,
        player_id: &str,
        message: ClientMessage,
    ) -> Result<HostCommand, RoomError> {
        let command = host_command(message)
            .ok_or_else(|| RoomError::new(ErrorCode::BadRequest, "not a host message"))?;
        let deals = matches!(command, HostCommand::StartHand { .. })
            && player_id == self.state.host_id
            && self.state.is_virtual();
        if !deals {
            return Ok(command);
        }
        shuffled_deck(&mut *self.entropy)
            .map(|deck| HostCommand::StartHand { deck: Some(deck) })
            .map_err(|_| internal("could not shuffle the deck"))
    }

    fn on_client(&mut self, conn: ConnId, req_id: Option<String>, message: ClientMessage) {
        let Some(player_id) = self.conns.get(&conn).map(|c| c.player_id.clone()) else {
            let error = RoomError::new(ErrorCode::NotAuthenticated, "join or resume first");
            self.reply_error(conn, req_id, &error);
            return;
        };
        if self.state.is_solo() && solo_refuses(&message) {
            let error = RoomError::new(ErrorCode::BadRequest, "not available in a solo game");
            self.reply_error(conn, req_id, &error);
            return;
        }
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
            ClientMessage::ChooseSeat { seat_index } => Op::ChooseSeat {
                player_id: player_id.clone(),
                seat_index,
                at_ms,
            },
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
            ClientMessage::StartHand
            | ClientMessage::BeginShowdown
            | ClientMessage::ResolveShowdown { .. }
            | ClientMessage::Undo
            | ClientMessage::Pause { .. }
            | ClientMessage::ResumeGame
            | ClientMessage::ApproveRebuy { .. }
            | ClientMessage::Kick { .. }
            | ClientMessage::MoveSeat { .. }
            | ClientMessage::RoomConfigure { .. }
            | ClientMessage::EndGame => match self.host_command_for(&player_id, message) {
                Ok(command) => host(command),
                Err(error) => {
                    self.reply_error(conn, req_id, &error);
                    return;
                }
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
        self.submit_for(conn, req_id, &player_id, &op);
    }

    /// Runs a client's op and answers that connection with an `ACK` or the refusal.
    fn submit_for(&mut self, conn: ConnId, req_id: Option<String>, player_id: &str, op: &Op) {
        match self.submit(op) {
            Ok(outcome) => {
                let next_action_seq = self
                    .state
                    .players
                    .get(player_id)
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

/// Messages a single-player game has no use for. The one person playing may act, pause, resume
/// and quit; there is no table to manage, nobody to wait for and no buying back in.
fn solo_refuses(message: &ClientMessage) -> bool {
    matches!(
        message,
        ClientMessage::ChooseSeat { .. }
            | ClientMessage::RequestRebuy { .. }
            | ClientMessage::SetSittingOut { .. }
            | ClientMessage::LeaveTable
            | ClientMessage::PresenceVote { .. }
            | ClientMessage::PresenceAck
            | ClientMessage::StartHand
            | ClientMessage::BeginShowdown
            | ClientMessage::ResolveShowdown { .. }
            | ClientMessage::Undo
            | ClientMessage::ApproveRebuy { .. }
            | ClientMessage::Kick { .. }
            | ClientMessage::MoveSeat { .. }
            | ClientMessage::RoomConfigure { .. }
    )
}

/// The host command a host-only message stands for; `None` for any other message.
fn host_command(message: ClientMessage) -> Option<HostCommand> {
    Some(match message {
        ClientMessage::ResolveShowdown { allocations } => {
            HostCommand::ResolveShowdown { allocations }
        }
        ClientMessage::Pause { reason } => HostCommand::Pause { reason },
        ClientMessage::ApproveRebuy { player_id, amount } => {
            HostCommand::ApproveRebuy { player_id, amount }
        }
        ClientMessage::Kick { player_id } => HostCommand::Kick { player_id },
        ClientMessage::MoveSeat {
            player_id,
            seat_index,
        } => HostCommand::MoveSeat {
            player_id,
            seat_index,
        },
        ClientMessage::RoomConfigure { config } => HostCommand::Configure { config },
        ClientMessage::BeginShowdown => HostCommand::BeginShowdown,
        ClientMessage::Undo => HostCommand::Undo,
        ClientMessage::ResumeGame => HostCommand::ResumeGame,
        ClientMessage::EndGame => HostCommand::EndGame,
        ClientMessage::StartHand => HostCommand::StartHand { deck: None },
        _ => return None,
    })
}

fn snapshot_worthy(event: &Event) -> bool {
    matches!(
        event,
        Event::HandEnded { .. } | Event::BlindsConfigured | Event::RebuyApplied { .. }
    )
}
