//! All rooms of one server: creating, finding and restoring them.

use std::collections::{BTreeMap, VecDeque};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use tokio::sync::watch;

use crate::config::{Limits, Timings};
use crate::protocol::{ErrorCode, RoomConfig, ServerMessage};
use crate::room::actor::{self, Clock, NewRoom};
use crate::room::handle::{ConnSender, Outbound, RoomHandle, RoomInfo, RoomStatus};
use crate::room::session::Session;
use crate::room::state::RoomError;
use crate::store;
use crate::supervisor;
use crate::util::room_code;

type Slot = Arc<watch::Sender<RoomStatus>>;

/// What a creator gets back from a freshly started room (the task is already supervised).
struct Parts {
    handle: crate::room::handle::RoomHandle,
    host_token: String,
    session_token: String,
    player_id: String,
}

/// A room made by [`Registry::create_room_detached`], with the secrets for its host.
#[derive(Clone, Debug)]
pub struct CreatedRoom {
    /// Room code to share with players.
    pub room_code: String,
    /// The host's player id.
    pub player_id: String,
    /// The host's session token.
    pub session_token: String,
    /// Proof that the holder is the host.
    pub host_token: String,
}

struct Inner {
    rooms: Mutex<BTreeMap<String, Slot>>,
    limits: Limits,
    timings: Timings,
    data_dir: Option<PathBuf>,
    clock: Clock,
    next_conn: AtomicU64,
}

/// Cloneable access to every room on this server.
#[derive(Clone)]
pub struct Registry {
    inner: Arc<Inner>,
}

impl std::fmt::Debug for Registry {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Registry")
            .field("rooms", &self.room_count())
            .finish_non_exhaustive()
    }
}

fn internal(text: &str) -> RoomError {
    RoomError::new(ErrorCode::InternalError, text)
}

/// The most rooms `GET /v1/lobbies` lists.
pub const MAX_LISTED_LOBBIES: usize = 16;

/// How long one room may take to describe itself for the lobby list.
const LOBBY_REPLY_WAIT: Duration = Duration::from_millis(300);

impl Registry {
    /// An empty registry. With a `data_dir`, rooms are persisted and can be restored.
    #[must_use]
    pub fn new(limits: Limits, timings: Timings, data_dir: Option<PathBuf>, clock: Clock) -> Self {
        Registry {
            inner: Arc::new(Inner {
                rooms: Mutex::new(BTreeMap::new()),
                limits,
                timings,
                data_dir,
                clock,
                next_conn: AtomicU64::new(1),
            }),
        }
    }

    pub(crate) fn limits(&self) -> &Limits {
        &self.inner.limits
    }

    pub(crate) fn timings(&self) -> &Timings {
        &self.inner.timings
    }

    pub(crate) fn clock(&self) -> Clock {
        self.inner.clock
    }

    fn rooms(&self) -> MutexGuard<'_, BTreeMap<String, Slot>> {
        self.inner
            .rooms
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }

    pub(crate) fn forget(&self, code: &str) {
        self.rooms().remove(code);
    }

    /// A fresh connection id.
    #[must_use]
    pub fn next_conn_id(&self) -> u64 {
        self.inner.next_conn.fetch_add(1, Ordering::Relaxed)
    }

    /// Rooms currently known (running or frozen).
    #[must_use]
    pub fn room_count(&self) -> usize {
        self.rooms().len()
    }

    /// Is there a room with this code?
    #[must_use]
    pub fn contains(&self, code: &str) -> bool {
        room_code::normalize(code).is_some_and(|code| self.rooms().contains_key(&code))
    }

    /// Public facts about a room, or `None` if it is unknown, frozen or just stopped.
    pub async fn room_info(&self, code: &str) -> Option<RoomInfo> {
        let (handle, _) = self.lookup(code).ok()?;
        handle.info().await.ok()
    }

    /// Rooms still in their lobby with a free seat, newest facts first by code order, for the
    /// join screen's "games on this Wi-Fi" list. At most [`MAX_LISTED_LOBBIES`]; a room that does
    /// not answer in time is left out rather than holding the list up.
    pub async fn open_lobbies(&self) -> Vec<(String, RoomInfo)> {
        let codes: Vec<String> = self
            .rooms()
            .keys()
            .take(MAX_LISTED_LOBBIES * 4)
            .cloned()
            .collect();
        let mut open = Vec::new();
        for code in codes {
            let info = tokio::time::timeout(LOBBY_REPLY_WAIT, self.room_info(&code))
                .await
                .ok()
                .flatten();
            if let Some(info) = info.filter(|i| !i.in_progress && i.player_count < i.max_players) {
                open.push((code, info));
            }
            if open.len() >= MAX_LISTED_LOBBIES {
                break;
            }
        }
        open
    }

    /// The configured limits.
    #[must_use]
    pub fn server_limits(&self) -> &Limits {
        &self.inner.limits
    }

    fn lookup(&self, code: &str) -> Result<(RoomHandle, watch::Receiver<RoomStatus>), RoomError> {
        let not_found = || RoomError::new(ErrorCode::RoomNotFound, "no room with that code");
        let code = room_code::normalize(code).ok_or_else(not_found)?;
        let slot = self.rooms().get(&code).cloned().ok_or_else(not_found)?;
        let status = slot.subscribe();
        let current = status.borrow().clone();
        match current {
            RoomStatus::Running(handle) => Ok((handle, status)),
            RoomStatus::Frozen => Err(RoomError::new(
                ErrorCode::RoomCrashed,
                "the room has crashed",
            )),
            RoomStatus::Gone => Err(not_found()),
        }
    }

    /// Creates a room without attaching anyone. The host app uses this in host mode and then
    /// connects like a reconnecting host (`RESUME` with both tokens).
    ///
    /// # Errors
    /// Bad settings or name, or `ROOM_FULL` when the server holds `max_rooms` already.
    pub fn create_room_detached(
        &self,
        host_name: String,
        config: RoomConfig,
    ) -> Result<CreatedRoom, RoomError> {
        self.create_inner(host_name, config)
            .map(|(created, _)| CreatedRoom {
                room_code: created.handle.code().to_owned(),
                player_id: created.player_id,
                session_token: created.session_token,
                host_token: created.host_token,
            })
    }

    /// Creates a room and attaches the creator as host. `ROOM_CREATED` and then `SNAPSHOT`
    /// arrive on `tx`.
    ///
    /// # Errors
    /// Bad settings or name, or `ROOM_FULL` when the server holds `max_rooms` already.
    pub async fn create_room(
        &self,
        conn: u64,
        tx: ConnSender,
        req_id: Option<String>,
        host_name: String,
        config: RoomConfig,
    ) -> Result<Session, RoomError> {
        if config.solo.is_some() {
            // A single-player game exists only on the app's own loopback server.
            return Err(RoomError::new(
                ErrorCode::BadRequest,
                "single-player games cannot be created over the network",
            ));
        }
        let (created, status) = self.create_inner(host_name, config)?;
        let code = created.handle.code().to_owned();
        let _queued = tx.try_send(Outbound {
            req_id: req_id.clone(),
            message: ServerMessage::RoomCreated {
                room_code: code,
                host_token: created.host_token.clone(),
                session_token: created.session_token.clone(),
                player_id: created.player_id.clone(),
            },
        });
        let player_id = created
            .handle
            .resume(
                conn,
                tx.clone(),
                req_id,
                created.session_token.clone(),
                Some(created.host_token.clone()),
            )
            .await?;
        Ok(Session::new(
            conn,
            tx,
            status,
            player_id,
            created.session_token,
            Some(created.host_token),
        ))
    }

    /// Allocates a free code, creates the room and starts supervising it.
    fn create_inner(
        &self,
        host_name: String,
        config: RoomConfig,
    ) -> Result<(Parts, watch::Receiver<RoomStatus>), RoomError> {
        let (created, slot) = {
            let mut rooms = self.rooms();
            if rooms.len() >= self.inner.limits.max_rooms {
                return Err(RoomError::new(ErrorCode::RoomFull, "the server is full"));
            }
            let mut code = None;
            for _ in 0..20 {
                let candidate = room_code::generate().map_err(|_| internal("no randomness"))?;
                let on_disk = self
                    .inner
                    .data_dir
                    .as_ref()
                    .is_some_and(|root| store::room_dir(root, &candidate).exists());
                if !rooms.contains_key(&candidate) && !on_disk {
                    code = Some(candidate);
                    break;
                }
            }
            let code = code.ok_or_else(|| internal("could not find a free room code"))?;
            let new = NewRoom {
                code: code.clone(),
                config,
                host_name,
                data_dir: self.inner.data_dir.clone(),
            };
            let created = actor::create(
                new,
                &self.inner.limits,
                &self.inner.timings,
                self.inner.clock,
            )?;
            let slot: Slot =
                Arc::new(watch::channel(RoomStatus::Running(created.handle.clone())).0);
            rooms.insert(code, Arc::clone(&slot));
            (created, slot)
        };
        let code = created.handle.code().to_owned();
        let dir = self
            .inner
            .data_dir
            .as_ref()
            .map(|root| store::room_dir(root, &code));
        tokio::spawn(supervisor::supervise(
            self.clone(),
            code,
            dir,
            created.task,
            Arc::clone(&slot),
        ));
        let status = slot.subscribe();
        let parts = Parts {
            handle: created.handle,
            host_token: created.host_token,
            session_token: created.session_token,
            player_id: created.player_id,
        };
        Ok((parts, status))
    }

    /// Joins a room. `JOINED` and `SNAPSHOT` arrive on `tx`.
    ///
    /// # Errors
    /// `ROOM_NOT_FOUND`, `ROOM_CRASHED`, or the room's own refusal.
    pub async fn join_room(
        &self,
        code: &str,
        conn: u64,
        tx: ConnSender,
        req_id: Option<String>,
        name: String,
        spectator: bool,
        seat: Option<u8>,
    ) -> Result<Session, RoomError> {
        let (handle, status) = self.lookup(code)?;
        let joined = handle
            .join(conn, tx.clone(), req_id, name, spectator, seat)
            .await?;
        Ok(Session::new(
            conn,
            tx,
            status,
            joined.player_id,
            joined.session_token,
            None,
        ))
    }

    /// Re-attaches with a session token. `SNAPSHOT` arrives on `tx`.
    ///
    /// # Errors
    /// `ROOM_NOT_FOUND`, `ROOM_CRASHED` or `INVALID_SESSION`.
    pub async fn resume_room(
        &self,
        code: &str,
        conn: u64,
        tx: ConnSender,
        req_id: Option<String>,
        session_token: String,
        host_token: Option<String>,
    ) -> Result<Session, RoomError> {
        let (handle, status) = self.lookup(code)?;
        let player_id = handle
            .resume(
                conn,
                tx.clone(),
                req_id,
                session_token.clone(),
                host_token.clone(),
            )
            .await?;
        Ok(Session::new(
            conn,
            tx,
            status,
            player_id,
            session_token,
            host_token,
        ))
    }

    /// Restores every room found in the data folder. Rooms that cannot be rebuilt are skipped
    /// and left on disk. Returns how many are running again.
    pub fn restore_all(&self) -> usize {
        let Some(root) = self.inner.data_dir.clone() else {
            return 0;
        };
        let Ok(entries) = std::fs::read_dir(&root) else {
            return 0;
        };
        let mut restored = 0;
        for entry in entries.flatten() {
            let Some(code) = entry.file_name().to_str().and_then(room_code::normalize) else {
                continue;
            };
            let dir = entry.path();
            if !dir.join("snapshot.json").exists() || self.rooms().contains_key(&code) {
                continue;
            }
            let mut strikes = VecDeque::new();
            let Some((handle, task)) = supervisor::recover(
                &dir,
                &self.inner.limits,
                &self.inner.timings,
                self.inner.clock,
                &mut strikes,
            ) else {
                tracing::error!(%code, "could not restore room; leaving its files alone");
                continue;
            };
            let slot: Slot = Arc::new(watch::channel(RoomStatus::Running(handle)).0);
            self.rooms().insert(code.clone(), Arc::clone(&slot));
            tokio::spawn(supervisor::supervise(
                self.clone(),
                code,
                Some(dir),
                task,
                slot,
            ));
            restored += 1;
        }
        restored
    }

    /// Makes a room's task panic (supervision tests only).
    #[cfg(feature = "test-hooks")]
    pub async fn panic_room_for_test(&self, code: &str) {
        if let Ok((handle, _)) = self.lookup(code) {
            handle.panic_for_test().await;
        }
    }

    /// Asks every room to stop and waits (up to `grace`) until they have. Files stay on disk.
    pub async fn shutdown(&self, grace: Duration) {
        let handles: Vec<RoomHandle> = self
            .rooms()
            .values()
            .filter_map(|slot| match &*slot.borrow() {
                RoomStatus::Running(handle) => Some(handle.clone()),
                _ => None,
            })
            .collect();
        for handle in handles {
            handle.close().await;
        }
        let deadline = tokio::time::Instant::now() + grace;
        while self.room_count() > 0 && tokio::time::Instant::now() < deadline {
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    }
}
