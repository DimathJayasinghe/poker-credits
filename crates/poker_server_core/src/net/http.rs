//! Plain HTTP endpoints: health, server info and room lookup.

use std::net::SocketAddr;
use std::sync::Arc;

use axum::Json;
use axum::extract::{ConnectInfo, Path, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;

use super::{NetState, ServerMode};
use crate::PROTOCOL_VERSION;
use crate::protocol::CardMode;

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
    card_mode: CardMode,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Lobby {
    room_code: String,
    host_name: String,
    player_count: usize,
    max_players: usize,
    card_mode: CardMode,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Lobbies {
    lobbies: Vec<Lobby>,
}

/// `GET /v1/lobbies`: the open lobbies of a host-embedded server, for the join screen on the same
/// Wi-Fi. Only rooms still in their lobby with a free seat are listed, and only by a server
/// running in `HOST` mode: a cloud server never lists its rooms (codes stay secrets there).
pub(crate) async fn lobbies(
    State(net): State<Arc<NetState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> Response {
    if !net.http_limiter.check(addr.ip()) {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    }
    if net.mode != ServerMode::Host {
        return Json(Lobbies {
            lobbies: Vec::new(),
        })
        .into_response();
    }
    let lobbies = net
        .registry
        .open_lobbies()
        .await
        .into_iter()
        .map(|(room_code, info)| Lobby {
            room_code,
            host_name: info.host_name,
            player_count: info.player_count,
            max_players: info.max_players,
            card_mode: info.card_mode,
        })
        .collect();
    Json(Lobbies { lobbies }).into_response()
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
///
/// On a cloud server a lookup of a code that does not exist also counts as a failed join, so
/// probing for rooms spends the same budget as probing over the WebSocket and a scanner is
/// blocked after the same number of misses. A host-embedded (LAN) server does not count: its
/// guests legitimately ask for codes that are not there (a typo, the wrong Wi-Fi).
pub(crate) async fn room(
    State(net): State<Arc<NetState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Path(code): Path<String>,
) -> Response {
    if !net.http_limiter.check(addr.ip()) {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    }
    let counts_misses = net.mode == ServerMode::Cloud;
    if counts_misses && !net.join_failures.allowed(addr.ip()) {
        return StatusCode::TOO_MANY_REQUESTS.into_response();
    }
    let lookup = if let Some(info) = net.registry.room_info(&code).await {
        RoomLookup {
            exists: true,
            player_count: info.player_count,
            max_players: info.max_players,
            is_full: info.player_count >= info.max_players,
            in_progress: info.in_progress,
            card_mode: info.card_mode,
        }
    } else {
        if counts_misses {
            net.join_failures.record_failure(addr.ip());
        }
        RoomLookup {
            exists: false,
            player_count: 0,
            max_players: 0,
            is_full: false,
            in_progress: false,
            card_mode: CardMode::Physical,
        }
    };
    Json(lookup).into_response()
}
