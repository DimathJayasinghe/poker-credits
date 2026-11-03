//! Plain HTTP endpoints: health, server info and room lookup.

use std::net::SocketAddr;
use std::sync::Arc;

use axum::Json;
use axum::extract::{ConnectInfo, Path, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;

use super::NetState;
use crate::PROTOCOL_VERSION;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Health {
    status: &'static str,
    active_rooms: usize,
    version: &'static str,
    protocol: u16,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Info {
    protocol: u16,
    mode: &'static str,
    server_name: String,
    room_count: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct RoomLookup {
    exists: bool,
    player_count: usize,
    max_players: usize,
    is_full: bool,
    in_progress: bool,
}

/// `GET /health`
pub(crate) async fn health(State(net): State<Arc<NetState>>) -> Json<Health> {
    Json(Health {
        status: "healthy",
        active_rooms: net.registry.room_count(),
        version: env!("CARGO_PKG_VERSION"),
        protocol: PROTOCOL_VERSION,
    })
}

/// `GET /v1/info`. Room codes are never listed.
pub(crate) async fn info(State(net): State<Arc<NetState>>) -> Json<Info> {
    Json(Info {
        protocol: PROTOCOL_VERSION,
        mode: net.mode.as_wire(),
        server_name: net.server_name.clone(),
        room_count: net.registry.room_count(),
    })
}

/// `GET /v1/room/{code}`. Rate limited per IP because codes are guessable.
pub(crate) async fn room(
    State(net): State<Arc<NetState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Path(code): Path<String>,
) -> Response {
    if !net.http_limiter.check(addr.ip()) {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    }
    let lookup = match net.registry.room_info(&code).await {
        Some(info) => RoomLookup {
            exists: true,
            player_count: info.player_count,
            max_players: info.max_players,
            is_full: info.player_count >= info.max_players,
            in_progress: info.in_progress,
        },
        None => RoomLookup {
            exists: false,
            player_count: 0,
            max_players: 0,
            is_full: false,
            in_progress: false,
        },
    };
    Json(lookup).into_response()
}
