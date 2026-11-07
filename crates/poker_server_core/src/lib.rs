//! Authoritative poker server core, shared by the cloud binary and the app's embedded host mode.
//!
//! Implementation starts in Phase 2; see `docs/AGENT_CODING_GUIDE.md`.

pub mod cards;
pub mod config;
pub mod event;
pub mod net;
pub mod protocol;
pub mod registry;
pub mod room;
pub mod store;
mod supervisor;
pub mod tls;
pub mod util;

/// Wire protocol version spoken by this build (`v` field of every message).
pub const PROTOCOL_VERSION: u16 = 1;

#[cfg(test)]
mod tests {
    use super::PROTOCOL_VERSION;

    #[test]
    fn protocol_version_starts_at_one() {
        assert_eq!(PROTOCOL_VERSION, 1);
    }
}

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use tokio::sync::{mpsc, oneshot, watch};
use tokio::task::JoinHandle;

use axum::serve::ListenerExt as _;
use config::{Limits, Timings};
use event::ServerEvent;
use net::NetState;
pub use net::ServerMode;
use net::guards::{FailureLimiter, IpLimiter, KeyedRateLimiter};
use registry::Registry;
use room::actor::Clock;
use tls::TlsListener;
pub use tls::{Fingerprint, Identity, TlsError};

/// How long [`ServerHandle::stop`] waits for rooms and sockets to wind down.
const STOP_GRACE: Duration = Duration::from_secs(5);

/// Settings for [`start`].
#[derive(Debug)]
pub struct ServerConfig {
    /// Address to listen on; port 0 picks a free one.
    pub bind: SocketAddr,
    /// Where rooms are persisted (`<dir>/<ROOM>/`). `None` keeps everything in memory.
    pub data_dir: Option<PathBuf>,
    /// Connection and room limits.
    pub limits: Limits,
    /// Timings for inactive players.
    pub timings: Timings,
    /// Reported by `GET /v1/info`.
    pub mode: ServerMode,
    /// Reported by `GET /v1/info`.
    pub server_name: String,
    /// Optional event feed. Bounded; events are dropped when it is full.
    pub events: Option<mpsc::Sender<ServerEvent>>,
    /// The certificate to serve (TLS 1.3 only). `None` serves plain HTTP, which is only for the
    /// cloud binary behind a proxy and for loopback: a host server that listens on the network
    /// without TLS refuses to start ([`StartError::PlaintextOnNetwork`]).
    pub tls: Option<Identity>,
}

impl ServerConfig {
    /// A server only this device can reach, for a single-player game: it listens on
    /// `127.0.0.1` with a free port, so no one on the network can connect to it.
    #[must_use]
    pub fn loopback_only(data_dir: Option<PathBuf>) -> Self {
        ServerConfig {
            bind: SocketAddr::from(([127, 0, 0, 1], 0)),
            data_dir,
            limits: Limits::default(),
            timings: Timings::default(),
            mode: ServerMode::Host,
            server_name: "Poker Credits".to_owned(),
            events: None,
            tls: None,
        }
    }
}

/// Why [`start`] failed.
#[derive(Debug, thiserror::Error)]
pub enum StartError {
    /// The address could not be bound.
    #[error("cannot listen on {addr}: {source}")]
    Bind {
        /// Requested address.
        addr: SocketAddr,
        /// Cause.
        source: std::io::Error,
    },
    /// The data folder could not be created.
    #[error("cannot create the data folder {path}: {source}")]
    DataDir {
        /// Folder.
        path: PathBuf,
        /// Cause.
        source: std::io::Error,
    },
    /// A host server was asked to listen on the network without encryption.
    #[error("refusing to host on {addr} without TLS")]
    PlaintextOnNetwork {
        /// The requested address.
        addr: SocketAddr,
    },
    /// The certificate was not accepted.
    #[error(transparent)]
    Tls(#[from] TlsError),
}

/// A running server.
#[derive(Debug)]
pub struct ServerHandle {
    local_addr: SocketAddr,
    fingerprint: Option<Fingerprint>,
    registry: Registry,
    shutdown: watch::Sender<bool>,
    stop_listener: oneshot::Sender<()>,
    task: JoinHandle<()>,
    events: Option<mpsc::Sender<ServerEvent>>,
}

impl ServerHandle {
    /// The address actually bound (useful with port 0).
    #[must_use]
    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    /// The pin guests need, when the server speaks TLS.
    #[must_use]
    pub fn fingerprint(&self) -> Option<Fingerprint> {
        self.fingerprint
    }

    /// Access to the rooms, for the embedding app.
    #[must_use]
    pub fn registry(&self) -> &Registry {
        &self.registry
    }

    /// Stops accepting, closes sockets, stops rooms (their files stay on disk) and waits.
    pub async fn stop(self) {
        let _ = self.shutdown.send(true);
        self.registry.shutdown(STOP_GRACE).await;
        let _ = self.stop_listener.send(());
        let mut task = self.task;
        if tokio::time::timeout(STOP_GRACE, &mut task).await.is_err() {
            task.abort();
        }
        if let Some(events) = &self.events {
            let _queued = events.try_send(ServerEvent::Stopped);
        }
    }
}

/// Starts the server: restores rooms from the data folder and begins listening.
///
/// # Errors
/// [`StartError`] when the data folder or the address is unusable.
pub async fn start(config: ServerConfig) -> Result<ServerHandle, StartError> {
    if config.tls.is_none() && config.mode == ServerMode::Host && !config.bind.ip().is_loopback() {
        return Err(StartError::PlaintextOnNetwork { addr: config.bind });
    }
    if let Some(dir) = &config.data_dir {
        std::fs::create_dir_all(dir).map_err(|source| StartError::DataDir {
            path: dir.clone(),
            source,
        })?;
    }
    let listener = tokio::net::TcpListener::bind(config.bind)
        .await
        .map_err(|source| StartError::Bind {
            addr: config.bind,
            source,
        })?;
    let local_addr = listener.local_addr().map_err(|source| StartError::Bind {
        addr: config.bind,
        source,
    })?;
    let registry = Registry::new(
        config.limits.clone(),
        config.timings,
        config.data_dir,
        Clock::new(),
    );
    let restored = registry.restore_all();
    let (shutdown, shutdown_rx) = watch::channel(false);
    let state = Arc::new(NetState {
        registry: registry.clone(),
        ip_limiter: IpLimiter::new(config.limits.max_connections_per_ip),
        http_limiter: KeyedRateLimiter::new(
            config.limits.http_rate_per_second.saturating_mul(60),
            config.limits.http_burst,
        ),
        join_failures: FailureLimiter::new(
            config.limits.join_failures,
            config.limits.join_failure_window,
            config.limits.join_block,
        ),
        create_limiter: KeyedRateLimiter::new(
            config.limits.create_per_minute,
            config.limits.create_burst,
        ),
        limits: config.limits.clone(),
        mode: config.mode,
        server_name: config.server_name,
        shutdown: shutdown_rx,
    });
    let app = net::router(state).into_make_service_with_connect_info::<SocketAddr>();
    let (stop_listener, stop_rx) = oneshot::channel::<()>();
    let fingerprint = config.tls.as_ref().map(Identity::fingerprint);
    // The two listener types are different types, so each arm serves on its own.
    macro_rules! serve {
        ($listener:expr) => {
            tokio::spawn(async move {
                let served = axum::serve($listener, app)
                    .with_graceful_shutdown(async {
                        let _ = stop_rx.await;
                    })
                    .await;
                if let Err(error) = served {
                    tracing::error!(%error, "listener failed");
                }
            })
        };
    }
    let task = match &config.tls {
        // The no-op tap makes this listener look like the plain one to axum, which is what gives
        // the handlers `ConnectInfo<SocketAddr>` (the per-address limits depend on it).
        Some(identity) => {
            let listener = TlsListener::new(listener, identity, &config.limits)?.tap_io(|_| {});
            serve!(listener)
        }
        None => serve!(listener),
    };
    if let Some(events) = &config.events {
        let _queued = events.try_send(ServerEvent::Listening(local_addr));
        if restored > 0 {
            let _queued = events.try_send(ServerEvent::RoomsRestored(restored));
        }
    }
    tracing::info!(%local_addr, restored, "server listening");
    Ok(ServerHandle {
        local_addr,
        fingerprint,
        registry,
        shutdown,
        stop_listener,
        task,
        events: config.events,
    })
}
