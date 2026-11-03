//! Start and stop the embedded server, and watch it.
//!
//! The host's phone or laptop runs `poker_server_core` inside the app. Dart starts it with
//! [`start_server`], listens to the event stream, and connects its own UI over loopback like any
//! other client (ADR-004). A panic inside a room never reaches Dart through this module: the
//! room supervisor recovers the room and the clients see `ROOM_RECOVERED` on their sockets.
#![forbid(unsafe_code)]

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;

use flutter_rust_bridge::frb;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::event::ServerEvent;
use poker_server_core::{ServerConfig, ServerHandle, ServerMode, StartError};
use tokio::sync::{Mutex, mpsc};

use crate::frb_generated::StreamSink;

/// Events buffered between the server and Dart. Events are dropped when Dart falls behind.
const EVENT_QUEUE: usize = 64;

/// Default port for host mode (`docs/ARCHITECTURE.md` 6.1).
pub const DEFAULT_PORT: u16 = 7878;

/// What the app asks for when it hosts a game.
#[derive(Clone, Debug)]
pub struct RsServerConfig {
    /// TCP port; 0 picks a free one (read it back from [`RsServerHandle::port`]).
    pub port: u16,
    /// `true` listens on every network interface so other devices can join, `false` only on
    /// loopback.
    pub expose_on_lan: bool,
    /// Folder where rooms are saved so a restarted app can resume the game. Empty keeps
    /// everything in memory.
    pub data_dir: String,
    /// Name shown by `GET /v1/info`.
    pub server_name: String,
}

/// What kind of server event this is.
///
/// Events are a struct with a plain enum, not an enum with data, because the generator would
/// then need the `freezed` package, which is not on the approved dependency list.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RsServerEventKind {
    /// The listener is up; `value` is the port.
    Listening,
    /// Rooms found in the data folder were started again; `value` is how many.
    RoomsRestored,
    /// The server has stopped; `value` is 0.
    Stopped,
}

/// Something that happened to the server as a whole.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RsServerEvent {
    /// What happened.
    pub kind: RsServerEventKind,
    /// Port or count, see [`RsServerEventKind`].
    pub value: u32,
}

/// Why the server could not be started.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RsServerErrorKind {
    /// The address is in use or not allowed.
    Bind,
    /// The data folder could not be created.
    DataDir,
}

/// The server could not be started.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RsServerError {
    /// Which step failed.
    pub kind: RsServerErrorKind,
    /// The address or folder that was tried.
    pub target: String,
    /// System message.
    pub message: String,
}

impl std::fmt::Display for RsServerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.kind {
            RsServerErrorKind::Bind => {
                write!(f, "cannot listen on {}: {}", self.target, self.message)
            }
            RsServerErrorKind::DataDir => {
                write!(
                    f,
                    "cannot create the data folder {}: {}",
                    self.target, self.message
                )
            }
        }
    }
}

impl std::error::Error for RsServerError {}

impl From<StartError> for RsServerError {
    fn from(error: StartError) -> Self {
        match error {
            StartError::Bind { addr, source } => RsServerError {
                kind: RsServerErrorKind::Bind,
                target: addr.to_string(),
                message: source.to_string(),
            },
            StartError::DataDir { path, source } => RsServerError {
                kind: RsServerErrorKind::DataDir,
                target: path.display().to_string(),
                message: source.to_string(),
            },
        }
    }
}

/// A running embedded server. Opaque to Dart.
#[frb(opaque)]
pub struct RsServerHandle {
    port: u16,
    inner: Mutex<Option<ServerHandle>>,
    /// Events wait here until Dart subscribes, so `Listening` is never missed.
    pending_events: std::sync::Mutex<Option<mpsc::Receiver<ServerEvent>>>,
}

impl RsServerHandle {
    /// The port the server actually listens on.
    #[frb(sync, getter)]
    #[must_use]
    pub fn port(&self) -> u16 {
        self.port
    }

    /// Whether [`RsServerHandle::stop`] has not been called yet.
    pub async fn is_running(&self) -> bool {
        self.inner.lock().await.is_some()
    }

    /// Streams [`RsServerEvent`]s into `events` until the server stops. Only the first call
    /// gets the stream; later calls end immediately.
    #[allow(
        clippy::unused_async,
        reason = "async makes the bridge run it inside its tokio runtime, which tokio::spawn needs"
    )]
    pub async fn subscribe(&self, events: StreamSink<RsServerEvent>) {
        let receiver = self
            .pending_events
            .lock()
            .map_or(None, |mut slot| slot.take());
        let Some(mut receiver) = receiver else {
            return;
        };
        tokio::spawn(async move {
            while let Some(event) = receiver.recv().await {
                if events.add(to_wire(&event)).is_err() {
                    // Dart stopped listening: keep draining so the server never blocks on us.
                    tracing::debug!("server event stream closed on the Dart side");
                }
            }
        });
    }

    /// Closes sockets, stops the rooms (their files stay on disk) and waits. Calling it twice
    /// is harmless.
    pub async fn stop(&self) {
        let handle = self.inner.lock().await.take();
        if let Some(handle) = handle {
            handle.stop().await;
        }
    }
}

/// Starts the server and returns its handle. Call [`RsServerHandle::subscribe`] to watch it.
///
/// # Errors
/// [`RsServerError`] when the port or the data folder is unusable.
pub async fn start_server(config: RsServerConfig) -> Result<RsServerHandle, RsServerError> {
    let (tx, rx) = mpsc::channel::<ServerEvent>(EVENT_QUEUE);
    start_with_events(&config, tx, rx).await
}

/// The part of [`start_server`] that tests can drive without a Dart stream.
pub(crate) async fn start_with_events(
    config: &RsServerConfig,
    events: mpsc::Sender<ServerEvent>,
    receiver: mpsc::Receiver<ServerEvent>,
) -> Result<RsServerHandle, RsServerError> {
    let server = poker_server_core::start(to_core(config, events)).await?;
    Ok(RsServerHandle {
        port: server.local_addr().port(),
        inner: Mutex::new(Some(server)),
        pending_events: std::sync::Mutex::new(Some(receiver)),
    })
}

fn to_core(config: &RsServerConfig, events: mpsc::Sender<ServerEvent>) -> ServerConfig {
    let ip = if config.expose_on_lan {
        IpAddr::V4(Ipv4Addr::UNSPECIFIED)
    } else {
        IpAddr::V4(Ipv4Addr::LOCALHOST)
    };
    let data_dir = (!config.data_dir.trim().is_empty()).then(|| PathBuf::from(&config.data_dir));
    ServerConfig {
        bind: SocketAddr::new(ip, config.port),
        data_dir,
        limits: Limits::default(),
        timings: Timings::default(),
        mode: ServerMode::Host,
        server_name: config.server_name.clone(),
        events: Some(events),
    }
}

fn to_wire(event: &ServerEvent) -> RsServerEvent {
    let (kind, value) = match event {
        ServerEvent::Listening(addr) => (RsServerEventKind::Listening, u32::from(addr.port())),
        ServerEvent::RoomsRestored(count) => (
            RsServerEventKind::RoomsRestored,
            u32::try_from(*count).unwrap_or(u32::MAX),
        ),
        ServerEvent::Stopped => (RsServerEventKind::Stopped, 0),
    };
    RsServerEvent { kind, value }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config(expose: bool) -> RsServerConfig {
        RsServerConfig {
            port: 0,
            expose_on_lan: expose,
            data_dir: String::new(),
            server_name: "test".to_owned(),
        }
    }

    #[test]
    fn lan_flag_picks_the_bind_address() {
        let (tx, _rx) = mpsc::channel(1);
        assert!(
            to_core(&config(true), tx.clone())
                .bind
                .ip()
                .is_unspecified()
        );
        assert!(to_core(&config(false), tx).bind.ip().is_loopback());
    }

    #[test]
    fn empty_data_dir_means_memory_only() {
        let (tx, _rx) = mpsc::channel(1);
        assert!(to_core(&config(false), tx).data_dir.is_none());
    }

    #[tokio::test]
    async fn start_reports_events_and_stop_is_idempotent() {
        let (tx, rx) = mpsc::channel(8);
        let handle = start_with_events(&config(false), tx, rx)
            .await
            .expect("starts");
        let mut rx = handle
            .pending_events
            .lock()
            .expect("lock")
            .take()
            .expect("receiver");
        assert_ne!(handle.port(), 0);
        assert!(handle.is_running().await);
        let listening = rx.recv().await.map(|e| to_wire(&e));
        assert_eq!(
            listening,
            Some(RsServerEvent {
                kind: RsServerEventKind::Listening,
                value: u32::from(handle.port()),
            })
        );
        handle.stop().await;
        handle.stop().await;
        assert!(!handle.is_running().await);
        let stopped = rx.recv().await.map(|e| to_wire(&e)).map(|e| e.kind);
        assert_eq!(stopped, Some(RsServerEventKind::Stopped));
    }

    #[tokio::test]
    async fn a_busy_port_is_a_typed_error() {
        let (tx, rx) = mpsc::channel(8);
        let first = start_with_events(&config(false), tx.clone(), rx)
            .await
            .expect("starts");
        let busy = RsServerConfig {
            port: first.port(),
            ..config(false)
        };
        let (_unused_tx, unused_rx) = mpsc::channel(1);
        let error = start_with_events(&busy, tx, unused_rx).await.err();
        assert_eq!(error.map(|e| e.kind), Some(RsServerErrorKind::Bind));
        first.stop().await;
    }
}
