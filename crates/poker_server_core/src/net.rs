//! HTTP and WebSocket front end (`docs/API_AND_EVENTS.md` sections 1 and 7).

pub mod guards;
pub mod http;
pub mod ws;

use std::sync::Arc;

use axum::Router;
use axum::routing::get;
use tokio::sync::watch;

use crate::config::Limits;
use crate::registry::Registry;
use guards::{FailureLimiter, IpLimiter, KeyedRateLimiter};

/// How this server describes itself in `GET /v1/info`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ServerMode {
    /// Embedded in the host's app (LAN).
    Host,
    /// The standalone cloud binary.
    Cloud,
}

impl ServerMode {
    pub(crate) fn as_wire(self) -> &'static str {
        match self {
            ServerMode::Host => "HOST",
            ServerMode::Cloud => "CLOUD",
        }
    }
}

/// Everything the handlers share.
pub(crate) struct NetState {
    pub(crate) registry: Registry,
    pub(crate) limits: Limits,
    pub(crate) ip_limiter: IpLimiter,
    pub(crate) http_limiter: KeyedRateLimiter,
    /// Wrong room codes and tokens: stops scanning for rooms.
    pub(crate) join_failures: FailureLimiter,
    /// Room creation per IP: stops one client from filling the server.
    pub(crate) create_limiter: KeyedRateLimiter,
    pub(crate) mode: ServerMode,
    pub(crate) server_name: String,
    /// Flips to `true` when the server is stopping; sockets then close.
    pub(crate) shutdown: watch::Receiver<bool>,
}

/// The router with every route.
pub(crate) fn router(state: Arc<NetState>) -> Router {
    Router::new()
        .route("/v1/ws", get(ws::upgrade))
        .route("/health", get(http::health))
        .route("/v1/info", get(http::info))
        .route("/v1/room/{code}", get(http::room))
        .with_state(state)
}
