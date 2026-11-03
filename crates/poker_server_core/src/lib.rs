//! Authoritative poker server core, shared by the cloud binary and the app's embedded host mode.
//!
//! Implementation starts in Phase 2; see `docs/AGENT_CODING_GUIDE.md`.

pub mod config;
pub mod event;
pub mod net;
pub mod protocol;
pub mod registry;
pub mod room;
pub mod store;
mod supervisor;
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

use config::{Limits, Timings};
use event::ServerEvent;
use net::NetState;
pub use net::ServerMode;
use net::guards::{FailureLimiter, IpLimiter, KeyedRateLimiter};
use registry::Registry;
use room::actor::Clock;

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
}

/// A running server.
#[derive(Debug)]
pub struct ServerHandle {
    local_addr: SocketAddr,
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
        limits: config.limits,
        mode: config.mode,
        server_name: config.server_name,
        shutdown: shutdown_rx,
    });
    let app = net::router(state).into_make_service_with_connect_info::<SocketAddr>();
    let (stop_listener, stop_rx) = oneshot::channel::<()>();
    let task = tokio::spawn(async move {
        let served = axum::serve(listener, app)
            .with_graceful_shutdown(async {
                let _ = stop_rx.await;
            })
            .await;
        if let Err(error) = served {
            tracing::error!(%error, "listener failed");
        }
    });
    if let Some(events) = &config.events {
        let _queued = events.try_send(ServerEvent::Listening(local_addr));
        if restored > 0 {
            let _queued = events.try_send(ServerEvent::RoomsRestored(restored));
        }
    }
    tracing::info!(%local_addr, restored, "server listening");
    Ok(ServerHandle {
        local_addr,
        registry,
        shutdown,
        stop_listener,
        task,
        events: config.events,
    })
}
