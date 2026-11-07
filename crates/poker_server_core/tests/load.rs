//! Ten rooms at once over real sockets: every room plays a series of hands with all clients
//! acting, and the run must finish with every action acknowledged inside a generous latency bound.
//! A smoke test for contention and queue sizing, not a benchmark.
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
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use poker_server_core::config::{Limits, Timings};
use poker_server_core::{ServerConfig, ServerMode};
use serde_json::{Value, json};
use ws_client::{WsClient, http_get};

const ROOMS: usize = 10;
const PLAYERS_PER_ROOM: usize = 4;
const HANDS: u64 = 20;
const HANDS_COUNT: usize = 20;
/// A local loopback server answers in milliseconds; a second means something is badly wrong.
const MAX_ACK: Duration = Duration::from_secs(1);

type Acks = Arc<Mutex<Vec<Duration>>>;

/// Plays one seat: calls or checks whenever prompted. The host also deals, picks winners and
/// ends the run after [`HANDS`] hands.
async fn play(mut ws: WsClient, me: String, host: bool, acks: Acks) {
    let mut sent_at: Option<Instant> = None;
    let mut last_seq: Option<u64> = None;
    let mut last_host_key = String::new();
    let mut idle_rounds = 0;
    loop {
        let message = match tokio::time::timeout(Duration::from_secs(15), ws.recv()).await {
            Ok(Some(message)) => message,
            other => panic!("{me}: no message ({other:?})"),
        };
        idle_rounds += 1;
        match message["type"].as_str().unwrap_or_default() {
            "ACK" => {
                if let Some(start) = sent_at.take() {
                    acks.lock().unwrap().push(start.elapsed());
                }
                idle_rounds = 0;
            }
            "ERROR" => panic!("{me}: {message}"),
            "TURN_PROMPT" if message["playerId"] == me.as_str() => {
                let seq = message["nextActionSeq"].as_u64().unwrap();
                if last_seq == Some(seq) {
                    continue;
                }
                last_seq = Some(seq);
                let kind = if message["legal"]["canCheck"] == true {
                    "CHECK"
                } else {
                    "CALL"
                };
                // Faster than any person, slower than the per-connection rate limit.
                tokio::time::sleep(Duration::from_millis(40)).await;
                sent_at = Some(Instant::now());
                ws.send(
                    json!({"v": 1, "reqId": format!("a{seq}"), "type": "GAME_ACTION",
                               "actionSeq": seq, "action": {"kind": kind}}),
                )
                .await;
            }
            "SNAPSHOT" | "STATE_UPDATE" if host => {
                let view = &message["view"];
                let phase = view["phase"].as_str().unwrap_or_default();
                let hand = view["handNumber"].as_u64().unwrap_or(0);
                let key = format!("{phase}/{hand}/{}", message["stateVersion"]);
                if key == last_host_key {
                    continue;
                }
                last_host_key.clone_from(&key);
                let seated = view["seats"].as_array().map_or(0, Vec::len);
                match phase {
                    "LOBBY" if seated == PLAYERS_PER_ROOM => {
                        ws.send(json!({"v": 1, "type": "START_HAND"})).await;
                    }
                    "NEXT_HAND_PREP" if hand >= HANDS => {
                        return;
                    }
                    "NEXT_HAND_PREP" => {
                        ws.send(json!({"v": 1, "type": "START_HAND"})).await;
                    }
                    "ALL_IN_RUNOUT" => {
                        ws.send(json!({"v": 1, "type": "BEGIN_SHOWDOWN"})).await;
                    }
                    "SHOWDOWN" => {
                        let allocations: Vec<Value> = view["pots"]
                            .as_array()
                            .unwrap()
                            .iter()
                            .enumerate()
                            .map(|(index, pot)| {
                                json!({"potIndex": index,
                                       "winnerPlayerIds": [pot["eligiblePlayerIds"][0].clone()]})
                            })
                            .collect();
                        ws.send(
                            json!({"v": 1, "type": "RESOLVE_SHOWDOWN", "allocations": allocations}),
                        )
                        .await;
                    }
                    _ => {}
                }
            }
            _ => {}
        }
        assert!(idle_rounds < 5000, "{me}: message storm without progress");
    }
}

async fn room(addr: SocketAddr, acks: Acks) {
    let config = json!({"startingChips": 100_000, "smallBlind": 5, "bigBlind": 10, "ante": 0,
        "isTournament": false, "blindLevelMinutes": 10, "turnTimeLimitSeconds": 30});
    let mut host = WsClient::connect(addr).await;
    host.send(
        json!({"v": 1, "reqId": "c", "type": "CREATE_ROOM", "hostName": "Host", "config": config}),
    )
    .await;
    let created = host.expect("ROOM_CREATED").await;
    let code = created["roomCode"].as_str().unwrap().to_owned();
    let host_id = created["playerId"].as_str().unwrap().to_owned();

    let mut tasks = Vec::new();
    for n in 1..PLAYERS_PER_ROOM {
        let mut ws = WsClient::connect(addr).await;
        ws.send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": format!("P{n}"), "spectator": false}))
            .await;
        let joined = ws.expect("JOINED").await;
        let id = joined["playerId"].as_str().unwrap().to_owned();
        tasks.push(tokio::spawn(play(ws, id, false, Arc::clone(&acks))));
    }
    play(host, host_id, true, acks).await;
    for task in tasks {
        task.abort();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn ten_rooms_play_twenty_hands_each() {
    let limits = Limits {
        // Every client is on 127.0.0.1, so the per-address limits must allow a whole venue.
        max_connections_per_ip: ROOMS * PLAYERS_PER_ROOM + 10,
        create_per_minute: 600,
        create_burst: 600,
        ..Limits::default()
    };
    let server = poker_server_core::start(ServerConfig {
        bind: "127.0.0.1:0".parse().unwrap(),
        data_dir: None,
        limits,
        timings: Timings::default(),
        mode: ServerMode::Cloud,
        server_name: "Load".into(),
        events: None,
        tls: None,
    })
    .await
    .unwrap();
    let addr = server.local_addr();

    let started = Instant::now();
    let acks: Acks = Arc::default();
    let rooms: Vec<_> = (0..ROOMS)
        .map(|_| tokio::spawn(room(addr, Arc::clone(&acks))))
        .collect();
    tokio::time::sleep(Duration::from_secs(3)).await;
    let (_, health) = http_get(addr, "/health").await;
    let health: Value = serde_json::from_str(&health).unwrap();
    assert_eq!(
        health["activeRooms"], ROOMS,
        "all rooms live mid-run: {health}"
    );
    for handle in rooms {
        handle.await.unwrap();
    }
    let mut all = acks.lock().unwrap().clone();
    let elapsed = started.elapsed();
    all.sort();
    let p99 = all[all.len() * 99 / 100];
    let max = *all.last().unwrap();
    eprintln!(
        "{ROOMS} rooms x {HANDS} hands: {} acked actions in {elapsed:?}, ack p50 {:?} p99 {p99:?} max {max:?}",
        all.len(),
        all[all.len() / 2],
    );
    assert!(
        all.len() >= ROOMS * PLAYERS_PER_ROOM * HANDS_COUNT / 2,
        "every hand had actions from every seat"
    );
    assert!(max < MAX_ACK, "slowest ack {max:?}");
    server.stop().await;
}
