//! HTTP and WebSocket front end (`docs/API_AND_EVENTS.md` sections 1 and 7).

pub mod guards;
pub mod http;
pub mod ws;

use std::sync::Arc;

use axum::Router;
use axum::extract::{Request, State};
use axum::http::{HeaderValue, StatusCode, header};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
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
        .route("/v1/lobbies", get(http::lobbies))
        .layer(middleware::from_fn_with_state(
            Arc::clone(&state),
            require_address_host,
        ))
        .with_state(state)
}

/// A host server (the phone in the middle of a LAN game) only answers requests that name it by
/// address, never by somebody's domain: see [`guards::host_header_allowed`]. The cloud server sits
/// behind a proxy under its real name and is not restricted.
async fn require_address_host(
    State(state): State<Arc<NetState>>,
    request: Request,
    next: Next,
) -> Response {
    if state.mode == ServerMode::Host {
        let host = request
            .headers()
            .get(header::HOST)
            .and_then(|value: &HeaderValue| value.to_str().ok());
        if !guards::host_header_allowed(host) {
            tracing::warn!("request refused: Host header is not an address");
            return StatusCode::BAD_REQUEST.into_response();
        }
    }
    next.run(request).await
}
