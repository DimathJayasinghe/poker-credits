//! The server over real sockets: HTTP endpoints, the WebSocket protocol, limits, races,
//! restart and crash recovery.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic
)]

#[path = "support/ws_client.rs"]
mod ws_client;

use std::net::SocketAddr;
use std::path::PathBuf;
use std::time::Duration;

use poker_server_core::config::{Limits, Timings};
use poker_server_core::{ServerConfig, ServerHandle, ServerMode};
use serde_json::{Value, json};
use ws_client::{WsClient, http_get};

const QUIET: Duration = Duration::from_millis(150);

async fn boot_with(limits: Limits, data_dir: Option<PathBuf>) -> ServerHandle {
    poker_server_core::start(ServerConfig {
        bind: "127.0.0.1:0".parse().unwrap(),
        data_dir,
        limits,
        timings: Timings::default(),
        mode: ServerMode::Cloud,
        server_name: "Test Server".into(),
        events: None,
    })
    .await
    .unwrap()
}

async fn boot() -> ServerHandle {
    boot_with(Limits::default(), None).await
}

fn config_json() -> Value {
    json!({"startingChips": 1000, "smallBlind": 5, "bigBlind": 10, "ante": 0,
           "isTournament": false, "blindLevelMinutes": 10, "turnTimeLimitSeconds": 30})
}

struct Seat {
    ws: WsClient,
    player_id: String,
    token: String,
}

struct Host {
    ws: WsClient,
    code: String,
    /// Proof that this is the host (`hostToken`).
    proof: String,
    /// Session token.
    token: String,
}

async fn create(addr: SocketAddr) -> Host {
    let mut ws = WsClient::connect(addr).await;
    ws.send(json!({"v": 1, "reqId": "c", "type": "CREATE_ROOM", "hostName": "Host", "config": config_json()}))
        .await;
    let created = ws.expect("ROOM_CREATED").await;
    ws.expect("SNAPSHOT").await;
    Host {
        ws,
        code: created["roomCode"].as_str().unwrap().to_owned(),
        proof: created["hostToken"].as_str().unwrap().to_owned(),
        token: created["sessionToken"].as_str().unwrap().to_owned(),
    }
}

async fn join_as(addr: SocketAddr, code: &str, name: &str, seat: Option<u8>) -> Seat {
    let mut ws = WsClient::connect(addr).await;
    let mut message =
        json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": name, "spectator": false});
    if let Some(seat) = seat {
        message["seatIndex"] = json!(seat);
    }
    ws.send(message).await;
    let joined = ws.expect("JOINED").await;
    ws.expect("SNAPSHOT").await;
    Seat {
        ws,
        player_id: joined["playerId"].as_str().unwrap().to_owned(),
        token: joined["sessionToken"].as_str().unwrap().to_owned(),
    }
}

fn error_code(message: &Value) -> &str {
    assert_eq!(message["type"], "ERROR", "{message}");
    message["code"].as_str().unwrap()
}

// -------------------------------------------------------------------------------------------
// HTTP
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn http_endpoints_describe_the_server_and_rooms() {
    let server = boot().await;
    let addr = server.local_addr();

    let (status, body) = http_get(addr, "/health").await;
    let health: Value = serde_json::from_str(&body).unwrap();
    assert_eq!(status, 200);
    assert_eq!(
        (
            health["status"].as_str(),
            health["activeRooms"].as_u64(),
            health["protocol"].as_u64()
        ),
        (Some("healthy"), Some(0), Some(1))
    );

    let (_, body) = http_get(addr, "/v1/info").await;
    let info: Value = serde_json::from_str(&body).unwrap();
    assert_eq!(
        (info["mode"].as_str(), info["serverName"].as_str()),
        (Some("CLOUD"), Some("Test Server"))
    );

    let (_, body) = http_get(addr, "/v1/room/ZZZZ").await;
    let missing: Value = serde_json::from_str(&body).unwrap();
    assert_eq!(missing["exists"], false);

    let host = create(addr).await;
    let (_, body) = http_get(addr, &format!("/v1/room/{}", host.code.to_lowercase())).await;
    let found: Value = serde_json::from_str(&body).unwrap();
    assert_eq!(found["exists"], true);
    assert_eq!(
        (found["playerCount"].as_u64(), found["maxPlayers"].as_u64()),
        (Some(1), Some(10))
    );
    assert_eq!(
        (found["isFull"].clone(), found["inProgress"].clone()),
        (json!(false), json!(false))
    );
    assert!(
        !info.to_string().contains(&host.code),
        "room codes are never listed"
    );
    server.stop().await;
}

#[tokio::test]
async fn room_lookups_are_rate_limited_per_ip() {
    let limits = Limits {
        http_rate_per_second: 1,
        http_burst: 2,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    assert_eq!(http_get(addr, "/v1/room/AAAA").await.0, 200);
    assert_eq!(http_get(addr, "/v1/room/AAAB").await.0, 200);
    assert_eq!(http_get(addr, "/v1/room/AAAC").await.0, 429);
    assert_eq!(
        http_get(addr, "/health").await.0,
        200,
        "other endpoints are not affected"
    );
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Authentication and framing
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn the_first_message_must_create_join_or_resume() {
    let server = boot().await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    ws.send(json!({"v": 1, "type": "GAME_ACTION", "actionSeq": 0, "action": {"kind": "FOLD"}}))
        .await;
    let reply = ws.recv().await.unwrap();
    assert_eq!(error_code(&reply), "NOT_AUTHENTICATED");
    assert!(ws.closed().await);
    server.stop().await;
}

#[tokio::test]
async fn bad_frames_get_errors_and_a_version_mismatch_closes() {
    let server = boot().await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    ws.send_text("{not json").await;
    assert_eq!(error_code(&ws.recv().await.unwrap()), "BAD_REQUEST");
    ws.send(json!({"v": 1, "type": "NOPE"})).await;
    assert_eq!(error_code(&ws.recv().await.unwrap()), "NOT_AUTHENTICATED");
    server.stop().await;

    let server = boot().await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    ws.send(json!({"v": 2, "reqId": "x", "type": "PING", "t": 1}))
        .await;
    let reply = ws.recv().await.unwrap();
    assert_eq!(
        (error_code(&reply), reply["reqId"].as_str()),
        ("VERSION_MISMATCH", Some("x"))
    );
    assert!(ws.closed().await);
    server.stop().await;
}

#[tokio::test]
async fn an_oversized_frame_closes_the_connection() {
    let server = boot().await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    ws.send_text(&"x".repeat(20_000)).await;
    assert!(ws.closed().await);
    server.stop().await;
}

#[tokio::test]
async fn ping_works_before_joining() {
    let server = boot().await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    ws.send(json!({"v": 1, "reqId": "p", "type": "PING", "t": 77}))
        .await;
    let pong = ws.recv().await.unwrap();
    assert_eq!(
        (
            pong["type"].as_str(),
            pong["t"].as_u64(),
            pong["reqId"].as_str()
        ),
        (Some("PONG"), Some(77), Some("p"))
    );
    server.stop().await;
}

#[tokio::test]
async fn a_failed_join_can_be_retried_on_the_same_socket() {
    let server = boot().await;
    let addr = server.local_addr();
    let host = create(addr).await;
    let mut ws = WsClient::connect(addr).await;
    ws.send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": host.code, "name": "Host", "spectator": false})).await;
    assert_eq!(error_code(&ws.recv().await.unwrap()), "NAME_INVALID");
    ws.send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": host.code, "name": "Bob", "spectator": false})).await;
    ws.expect("JOINED").await;
    // An unknown room is final.
    let mut other = WsClient::connect(addr).await;
    other.send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": "ZZZZ", "name": "Bob", "spectator": false})).await;
    assert_eq!(error_code(&other.recv().await.unwrap()), "ROOM_NOT_FOUND");
    assert!(other.closed().await);
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Limits
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn silent_sockets_are_closed() {
    let limits = Limits {
        auth_timeout: Duration::from_millis(300),
        idle_timeout: Duration::from_millis(300),
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    let mut stranger = WsClient::connect(addr).await;
    assert!(stranger.closed().await, "no first message in time");
    let mut host = create(addr).await;
    assert!(host.ws.closed().await, "no frames for the idle timeout");
    server.stop().await;
}

#[tokio::test]
async fn any_inbound_frame_keeps_a_connection_alive() {
    let limits = Limits {
        idle_timeout: Duration::from_millis(400),
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let mut host = create(server.local_addr()).await;
    for t in 0..6 {
        tokio::time::sleep(Duration::from_millis(150)).await;
        host.ws.send(json!({"v": 1, "type": "PING", "t": t})).await;
        host.ws.expect("PONG").await;
    }
    server.stop().await;
}

#[tokio::test]
async fn flooding_gets_rate_limited_then_closed_after_three_strikes() {
    let limits = Limits {
        rate_per_second: 1,
        rate_burst: 3,
        rate_strikes: 3,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let mut host = create(server.local_addr()).await;
    for t in 0..15 {
        host.ws.send(json!({"v": 1, "type": "PING", "t": t})).await;
    }
    let mut limited = 0;
    while let Some(message) = host.ws.recv().await {
        if message["type"] == "ERROR" && message["code"] == "RATE_LIMITED" {
            limited += 1;
        }
    }
    assert_eq!(limited, 3, "three strikes, then the connection is closed");
    server.stop().await;
}

#[tokio::test]
async fn connections_per_ip_are_capped_and_released() {
    let limits = Limits {
        max_connections_per_ip: 2,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    let first = WsClient::connect(addr).await;
    let _second = WsClient::connect(addr).await;
    assert_eq!(WsClient::try_connect(addr).await.err(), Some(429));
    first.kill();
    let mut admitted = false;
    for _ in 0..40 {
        if WsClient::try_connect(addr).await.is_ok() {
            admitted = true;
            break;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    assert!(
        admitted,
        "the slot comes back once the first connection is gone"
    );
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Playing
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn a_hand_over_real_sockets() {
    let server = boot().await;
    let addr = server.local_addr();
    let mut host = create(addr).await;
    let mut bob = join_as(addr, &host.code, "Bob", None).await;
    let mut cy = join_as(addr, &host.code, "Cy", None).await;
    host.ws.drain(QUIET).await;
    bob.ws.drain(QUIET).await;
    cy.ws.drain(QUIET).await;

    host.ws
        .send(json!({"v": 1, "reqId": "s", "type": "START_HAND"}))
        .await;
    let mut turn: Option<(usize, Value)> = None;
    for (index, ws) in [&mut host.ws, &mut bob.ws, &mut cy.ws]
        .into_iter()
        .enumerate()
    {
        for message in ws.drain(QUIET).await {
            if message["type"] == "TURN_PROMPT" {
                turn = Some((index, message));
            }
        }
    }
    let (index, prompt) = turn.expect("one player is prompted");
    assert_eq!(prompt["legal"]["canCall"], true);
    let seq = prompt["nextActionSeq"].as_u64().unwrap();
    let ws = match index {
        0 => &mut host.ws,
        1 => &mut bob.ws,
        _ => &mut cy.ws,
    };
    let call = json!({"v": 1, "reqId": "a", "type": "GAME_ACTION", "actionSeq": seq, "action": {"kind": "CALL"}});
    ws.send(call.clone()).await;
    ws.send(call).await;
    let acks: Vec<Value> = ws
        .drain(QUIET)
        .await
        .into_iter()
        .filter(|m| m["type"] == "ACK")
        .collect();
    assert_eq!(acks.len(), 2, "{acks:?}");
    assert_eq!(
        (acks[0]["duplicate"].clone(), acks[1]["duplicate"].clone()),
        (json!(false), json!(true))
    );
    assert_eq!(acks[0]["nextActionSeq"].as_u64(), Some(seq + 1));
    assert_eq!(acks[0]["reqId"], "a");
    server.stop().await;
}

#[tokio::test]
async fn concurrent_joins_never_overfill_the_table_or_share_a_seat() {
    let server = boot().await;
    let addr = server.local_addr();
    let host = create(addr).await;
    let mut tasks = Vec::new();
    for n in 0..15 {
        let code = host.code.clone();
        tasks.push(tokio::spawn(async move {
            let mut ws = WsClient::connect(addr).await;
            ws.send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": format!("P{n}"), "spectator": false}))
                .await;
            let reply = ws.recv().await.unwrap();
            // Keep the socket open until the verdict is in so nobody is dropped early.
            (reply, ws)
        }));
    }
    let mut joined = 0;
    let mut full = 0;
    let mut sockets = Vec::new();
    for task in tasks {
        let (reply, ws) = task.await.unwrap();
        if reply["type"] == "JOINED" {
            joined += 1;
        } else {
            assert_eq!(error_code(&reply), "ROOM_FULL");
            full += 1;
        }
        sockets.push(ws);
    }
    assert_eq!((joined, full), (9, 6), "host holds one of the ten seats");
    let (_, body) = http_get(addr, &format!("/v1/room/{}", host.code)).await;
    let info: Value = serde_json::from_str(&body).unwrap();
    assert_eq!(info["playerCount"], 10);
    assert_eq!(info["isFull"], true);
    server.stop().await;
}

#[tokio::test]
async fn only_one_of_many_simultaneous_requests_for_a_seat_wins() {
    let server = boot().await;
    let addr = server.local_addr();
    let host = create(addr).await;
    let mut tasks = Vec::new();
    for n in 0..6 {
        let code = host.code.clone();
        tasks.push(tokio::spawn(async move {
            let mut ws = WsClient::connect(addr).await;
            ws.send(
                json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": format!("R{n}"),
                           "seatIndex": 4, "spectator": false}),
            )
            .await;
            (ws.recv().await.unwrap(), ws)
        }));
    }
    let mut winners = 0;
    let mut sockets = Vec::new();
    for task in tasks {
        let (reply, ws) = task.await.unwrap();
        if reply["type"] == "JOINED" {
            assert_eq!(reply["seatIndex"], 4);
            winners += 1;
        } else {
            assert_eq!(error_code(&reply), "SEAT_OCCUPIED");
        }
        sockets.push(ws);
    }
    assert_eq!(winners, 1);
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Reconnecting, replacing, removing
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn a_dropped_player_resumes_with_a_full_snapshot() {
    let server = boot().await;
    let addr = server.local_addr();
    let mut host = create(addr).await;
    let bob = join_as(addr, &host.code, "Bob", None).await;
    host.ws.drain(QUIET).await;

    let (id, token) = (bob.player_id.clone(), bob.token.clone());
    bob.ws.kill();
    let offline = host.ws.expect("PLAYER_CONNECTION").await;
    assert_eq!(
        (
            offline["playerId"].as_str(),
            offline["isConnected"].as_bool()
        ),
        (Some(id.as_str()), Some(false))
    );

    let mut again = WsClient::connect(addr).await;
    again
        .send(json!({"v": 1, "type": "RESUME", "roomCode": host.code, "sessionToken": token, "lastStateVersion": 1}))
        .await;
    let snapshot = again.expect("SNAPSHOT").await;
    assert_eq!(snapshot["view"]["seats"].as_array().unwrap().len(), 2);
    let online = host.ws.expect("PLAYER_CONNECTION").await;
    assert_eq!(online["isConnected"], true);
    server.stop().await;
}

#[tokio::test]
async fn a_wrong_token_is_refused_and_the_socket_closed() {
    let server = boot().await;
    let addr = server.local_addr();
    let host = create(addr).await;
    for resume in [
        json!({"v": 1, "type": "RESUME", "roomCode": host.code, "sessionToken": "nope"}),
        // The host needs the host token as well as the session token.
        json!({"v": 1, "type": "RESUME", "roomCode": host.code, "sessionToken": host.token}),
    ] {
        let mut ws = WsClient::connect(addr).await;
        ws.send(resume).await;
        assert_eq!(error_code(&ws.recv().await.unwrap()), "INVALID_SESSION");
        assert!(ws.closed().await);
    }
    let mut ok = WsClient::connect(addr).await;
    ok.send(json!({"v": 1, "type": "RESUME", "roomCode": host.code,
                   "sessionToken": host.token, "hostToken": host.proof}))
        .await;
    ok.expect("SNAPSHOT").await;
    server.stop().await;
}

#[tokio::test]
async fn a_newer_connection_replaces_the_older_one() {
    let server = boot().await;
    let addr = server.local_addr();
    let host = create(addr).await;
    let mut bob = join_as(addr, &host.code, "Bob", None).await;
    let mut newer = WsClient::connect(addr).await;
    newer
        .send(json!({"v": 1, "type": "RESUME", "roomCode": host.code, "sessionToken": bob.token}))
        .await;
    newer.expect("SNAPSHOT").await;
    let old = bob.ws.expect("ERROR").await;
    assert_eq!(error_code(&old), "SUPERSEDED");
    assert!(bob.ws.closed().await);
    server.stop().await;
}

#[tokio::test]
async fn a_kicked_player_loses_the_socket() {
    let server = boot().await;
    let addr = server.local_addr();
    let mut host = create(addr).await;
    let mut bob = join_as(addr, &host.code, "Bob", None).await;
    host.ws
        .send(json!({"v": 1, "type": "KICK", "playerId": bob.player_id}))
        .await;
    loop {
        let message = bob
            .ws
            .recv()
            .await
            .expect("closed before the error arrived");
        if message["type"] == "ERROR" {
            assert_eq!(error_code(&message), "INVALID_SESSION");
            break;
        }
    }
    assert!(bob.ws.closed().await);
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Restart and crash
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn rooms_survive_a_server_restart() {
    let dir = tempfile::tempdir().unwrap();
    let first = boot_with(Limits::default(), Some(dir.path().to_path_buf())).await;
    let mut host = create(first.local_addr()).await;
    let mut bob = join_as(first.local_addr(), &host.code, "Bob", None).await;
    let (code, token) = (host.code.clone(), bob.token.clone());
    first.stop().await;
    assert!(host.ws.closed().await, "stopping the server closes sockets");
    assert!(bob.ws.closed().await);

    let second = boot_with(Limits::default(), Some(dir.path().to_path_buf())).await;
    let mut again = WsClient::connect(second.local_addr()).await;
    again
        .send(json!({"v": 1, "type": "RESUME", "roomCode": code, "sessionToken": token}))
        .await;
    let snapshot = again.expect("SNAPSHOT").await;
    assert_eq!(snapshot["view"]["roomCode"], code.as_str());
    assert_eq!(snapshot["view"]["seats"].as_array().unwrap().len(), 2);
    second.stop().await;
}

#[tokio::test]
async fn a_crashed_room_recovers_under_connected_players() {
    let dir = tempfile::tempdir().unwrap();
    let server = boot_with(Limits::default(), Some(dir.path().to_path_buf())).await;
    let addr = server.local_addr();
    let mut host = create(addr).await;
    let mut bob = join_as(addr, &host.code, "Bob", None).await;
    host.ws.drain(QUIET).await;
    bob.ws.drain(QUIET).await;

    server.registry().panic_room_for_test(&host.code).await;
    host.ws.expect("ROOM_RECOVERED").await;
    let snapshot = host.ws.expect("SNAPSHOT").await;
    assert_eq!(snapshot["view"]["seats"].as_array().unwrap().len(), 2);
    bob.ws.expect("ROOM_RECOVERED").await;
    bob.ws.expect("SNAPSHOT").await;

    // Same sockets, same room: play continues.
    host.ws.send(json!({"v": 1, "type": "START_HAND"})).await;
    let update = loop {
        let message = host.ws.expect("STATE_UPDATE").await;
        if message["view"]["phase"] == "PRE_FLOP" {
            break message;
        }
    };
    assert_eq!(update["view"]["handNumber"], 1);
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// Abuse
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn scanning_for_rooms_is_stopped_across_reconnects() {
    let limits = Limits {
        join_failures: 4,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    let host = create(addr).await;
    // Every probe uses a brand new socket, so no per-connection budget can help.
    for n in 0..4 {
        let mut probe = WsClient::connect(addr).await;
        probe
            .send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": format!("AAA{n}"), "name": "X", "spectator": false}))
            .await;
        assert_eq!(error_code(&probe.recv().await.unwrap()), "ROOM_NOT_FOUND");
    }
    // The address is now blocked, even for a real room and for resumes.
    for message in [
        json!({"v": 1, "type": "JOIN_ROOM", "roomCode": host.code, "name": "Real", "spectator": false}),
        json!({"v": 1, "type": "RESUME", "roomCode": host.code, "sessionToken": "x"}),
    ] {
        let mut blocked = WsClient::connect(addr).await;
        blocked.send(message).await;
        assert_eq!(error_code(&blocked.recv().await.unwrap()), "RATE_LIMITED");
        assert!(blocked.closed().await);
    }
    server.stop().await;
}

#[tokio::test]
async fn successful_joins_do_not_count_against_the_failure_budget() {
    let limits = Limits {
        join_failures: 3,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    let host = create(addr).await;
    let mut seats = Vec::new();
    for n in 0..6 {
        seats.push(join_as(addr, &host.code, &format!("Guest{n}"), None).await);
    }
    server.stop().await;
}

#[tokio::test]
async fn room_creation_is_limited_per_ip() {
    let limits = Limits {
        create_per_minute: 1,
        create_burst: 2,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    let _a = create(addr).await;
    let _b = create(addr).await;
    let mut third = WsClient::connect(addr).await;
    third
        .send(json!({"v": 1, "type": "CREATE_ROOM", "hostName": "Host", "config": config_json()}))
        .await;
    assert_eq!(error_code(&third.recv().await.unwrap()), "RATE_LIMITED");
    assert!(third.closed().await);
    server.stop().await;
}

#[tokio::test]
async fn garbage_costs_as_much_as_requests() {
    let limits = Limits {
        rate_per_second: 1,
        rate_burst: 3,
        rate_strikes: 3,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let mut ws = WsClient::connect(server.local_addr()).await;
    for _ in 0..30 {
        ws.send_text("{garbage").await;
    }
    let mut replies = 0;
    while ws.recv().await.is_some() {
        replies += 1;
    }
    // Three free frames get a BAD_REQUEST, then three strikes, then the socket closes.
    assert!(replies <= 3 + 3, "the server answered {replies} frames");
    server.stop().await;
}

#[tokio::test]
async fn garbage_does_not_keep_an_idle_connection_alive() {
    let limits = Limits {
        idle_timeout: Duration::from_millis(400),
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let mut host = create(server.local_addr()).await;
    for _ in 0..8 {
        tokio::time::sleep(Duration::from_millis(100)).await;
        host.ws.send_text("{garbage").await;
    }
    assert!(host.ws.closed().await);
    server.stop().await;
}

// -------------------------------------------------------------------------------------------
// The last word
// -------------------------------------------------------------------------------------------

#[tokio::test]
async fn everyone_hears_room_expired_before_the_socket_closes() {
    let limits = Limits {
        create_per_minute: 600,
        create_burst: 100,
        ..Limits::default()
    };
    let server = boot_with(limits, None).await;
    let addr = server.local_addr();
    // The order in which the room's last message and its end are noticed varies, so repeat.
    for _ in 0..30 {
        let mut host = create(addr).await;
        let mut bob = join_as(addr, &host.code, "Bob", None).await;
        host.ws.send(json!({"v": 1, "type": "END_GAME"})).await;
        host.ws.expect("ROOM_EXPIRED").await;
        bob.ws.expect("ROOM_EXPIRED").await;
    }
    server.stop().await;
}
