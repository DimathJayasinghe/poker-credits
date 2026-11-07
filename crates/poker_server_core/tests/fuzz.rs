//! Hostile input: mutated protocol messages, malformed and abusive WebSocket frames, raw TCP junk
//! and odd HTTP requests thrown at a running server.
//!
//! The server must never panic, must keep answering, and must not let any of it touch a second,
//! innocent room that is mid-hand on the same server. Deterministic for a given seed; set
//! `FUZZ_SEED` and `FUZZ_ITERS` for a longer or different run.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic
)]

#[path = "support/ws_client.rs"]
mod ws_client;

use std::fmt::Write as _;
use std::net::SocketAddr;
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::time::Duration;

use poker_server_core::config::{Limits, Timings};
use poker_server_core::{ServerConfig, ServerMode};
use serde_json::{Map, Value, json};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use ws_client::{WsClient, http_get};

/// Panics seen anywhere in the process: test thread, connection tasks and room actors alike.
static PANICS: AtomicUsize = AtomicUsize::new(0);

/// Whether the rooms the attacker creates deal virtual cards (the victim's room is set apart).
static ATTACKER_VIRTUAL: AtomicBool = AtomicBool::new(false);

/// Everything the attacker's sockets were sent, as text. In a run where the victim's room deals
/// cards and the attacker's does not, none of the victim's hole cards may ever show up here.
static HEARD: Mutex<String> = Mutex::new(String::new());

const QUIET: Duration = Duration::from_millis(150);
const PUMP: Duration = Duration::from_millis(3);

/// xorshift64*: small, deterministic, good enough to pick mutations.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: usize) -> usize {
        usize::try_from(self.next() % u64::try_from(n).unwrap()).unwrap()
    }

    fn pick<'a, T>(&mut self, items: &'a [T]) -> &'a T {
        &items[self.below(items.len())]
    }

    /// Between 1 and `max` random bytes.
    fn bytes(&mut self, max: usize) -> Vec<u8> {
        let len = self.below(max) + 1;
        (0..len)
            .map(|_| u8::try_from(self.next() & 0xff).unwrap())
            .collect()
    }
}

fn config_json() -> Value {
    let mut config = json!({"startingChips": 1000, "smallBlind": 5, "bigBlind": 10, "ante": 0,
           "isTournament": false, "blindLevelMinutes": 10, "turnTimeLimitSeconds": 30});
    if ATTACKER_VIRTUAL.load(Ordering::SeqCst) {
        config["cardMode"] = json!("VIRTUAL");
    }
    config
}

/// Limits loose enough that the fuzzer reaches the message handlers instead of being cut off by
/// the rate limiter (which has its own tests).
fn loose_limits() -> Limits {
    Limits {
        max_rooms: 10_000,
        max_connections_per_ip: 100_000,
        rate_per_second: 1_000_000,
        rate_burst: 1_000_000,
        rate_strikes: 1_000_000,
        http_rate_per_second: 1_000_000,
        http_burst: 1_000_000,
        join_failures: 1_000_000,
        create_per_minute: 1_000_000,
        create_burst: 1_000_000,
        ..Limits::default()
    }
}

/// Reads whatever arrives within a few milliseconds. The flag says the server closed the socket.
async fn pump(ws: &mut WsClient) -> (Vec<Value>, bool) {
    let mut messages = Vec::new();
    loop {
        match tokio::time::timeout(PUMP, ws.recv_frame()).await {
            Err(_) => return (messages, false),
            Ok(None | Some(ws_client::Frame::Close)) => return (messages, true),
            Ok(Some(ws_client::Frame::Text(text))) => {
                if let Ok(mut heard) = HEARD.lock() {
                    heard.push_str(&text);
                }
                messages.push(serde_json::from_str(&text).expect("the server only sends JSON"));
            }
            Ok(Some(ws_client::Frame::Ping)) => {}
        }
    }
}

struct Room {
    host: WsClient,
    code: String,
    proof: String,
    token: String,
}

async fn create(addr: SocketAddr) -> Room {
    create_with(addr, config_json()).await
}

async fn create_with(addr: SocketAddr, config: Value) -> Room {
    let mut ws = WsClient::connect(addr).await;
    ws.send(
        json!({"v": 1, "reqId": "c", "type": "CREATE_ROOM", "hostName": "Host", "config": config}),
    )
    .await;
    let created = ws.expect("ROOM_CREATED").await;
    ws.expect("SNAPSHOT").await;
    Room {
        host: ws,
        code: created["roomCode"].as_str().unwrap().to_owned(),
        proof: created["hostToken"].as_str().unwrap().to_owned(),
        token: created["sessionToken"].as_str().unwrap().to_owned(),
    }
}

struct Seat {
    ws: WsClient,
    player_id: String,
    token: String,
}

async fn join(addr: SocketAddr, code: &str, name: &str) -> Seat {
    let mut ws = WsClient::connect(addr).await;
    ws.send(
        json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": name, "spectator": false,
               "features": ["VIRTUAL_CARDS"]}),
    )
    .await;
    let joined = ws.expect("JOINED").await;
    ws.expect("SNAPSHOT").await;
    Seat {
        ws,
        player_id: joined["playerId"].as_str().unwrap().to_owned(),
        token: joined["sessionToken"].as_str().unwrap().to_owned(),
    }
}

/// The innocent room: three seats and a hand in progress.
struct Victim {
    room: Room,
    bob: Seat,
    cy: Seat,
    /// Hole cards dealt to the victim's players (empty when the room deals nothing).
    secret_cards: Vec<String>,
}

impl Victim {
    async fn new(addr: SocketAddr, virtual_cards: bool) -> Victim {
        // A long turn clock: a soak must not see the room change because a timer ran out.
        let mut config = config_json();
        config["turnTimeLimitSeconds"] = json!(300);
        config["cardMode"] = json!(if virtual_cards { "VIRTUAL" } else { "PHYSICAL" });
        let mut room = create_with(addr, config).await;
        let mut bob = join(addr, &room.code, "Bob").await;
        let mut cy = join(addr, &room.code, "Cy").await;
        room.host
            .send(json!({"v": 1, "reqId": "s", "type": "START_HAND"}))
            .await;
        room.host.drain(QUIET).await;
        let mut secret_cards = Vec::new();
        for seat in [&mut room.host, &mut bob.ws, &mut cy.ws] {
            for message in seat.drain(QUIET).await {
                if message["type"] == "HOLE_CARDS" {
                    secret_cards.extend(
                        message["cards"]
                            .as_array()
                            .into_iter()
                            .flatten()
                            .filter_map(|c| c.as_str().map(str::to_owned)),
                    );
                }
            }
        }
        Victim {
            room,
            bob,
            cy,
            secret_cards,
        }
    }

    fn ids(&self) -> Vec<String> {
        vec![self.bob.player_id.clone(), self.cy.player_id.clone()]
    }

    /// What a client sees on resuming as `bob`.
    async fn snapshot(&self, addr: SocketAddr) -> Value {
        let mut ws = WsClient::connect(addr).await;
        ws.send(json!({"v": 1, "type": "RESUME", "roomCode": self.room.code,
                       "sessionToken": self.bob.token, "features": ["VIRTUAL_CARDS"]}))
            .await;
        let mut snapshot = ws.expect("SNAPSHOT").await;
        // The server's clock moves on its own; everything else must stay put.
        snapshot.as_object_mut().unwrap().remove("serverTime");
        ws.kill();
        snapshot
    }
}

// -------------------------------------------------------------------------------------------
// Message mutation
// -------------------------------------------------------------------------------------------

fn nested(depth: usize) -> Value {
    let mut value = json!(1);
    for _ in 0..depth {
        value = Value::Array(vec![value]);
    }
    value
}

fn hostile(rng: &mut Rng) -> Value {
    match rng.below(16) {
        0 => Value::Null,
        1 => json!(-1),
        2 => json!(u64::MAX),
        3 => json!(i64::MIN),
        4 => json!(1.0e308),
        5 => json!(0.5),
        6 => json!(""),
        7 => json!("x".repeat(3000)),
        8 => json!("\u{0}\u{202e}\u{1f0cf}\u{fffd}"),
        9 => json!([]),
        10 => json!({}),
        11 => nested(rng.below(140) + 1),
        12 => json!(true),
        13 => json!(u64::from(u32::MAX) + 1),
        14 => json!(255),
        _ => json!("A".repeat(rng.below(40))),
    }
}

fn mutate(rng: &mut Rng, value: &mut Value, types: &[&str]) {
    match value {
        Value::Object(map) => {
            let keys: Vec<String> = map.keys().cloned().collect();
            if keys.is_empty() {
                map.insert("x".into(), hostile(rng));
                return;
            }
            let key = rng.pick(&keys).clone();
            match rng.below(7) {
                0 => {
                    map.remove(&key);
                }
                1 => {
                    map.insert("extra".into(), hostile(rng));
                }
                2 if key == "type" => {
                    // Another real message type, with this message's fields.
                    map.insert(key, json!(*rng.pick(types)));
                }
                3 | 4 => {
                    if let Some(child) = map.get_mut(&key) {
                        mutate(rng, child, types);
                    }
                }
                _ => {
                    map.insert(key, hostile(rng));
                }
            }
        }
        Value::Array(items) => match rng.below(3) {
            0 if !items.is_empty() => {
                let at = rng.below(items.len());
                items[at] = hostile(rng);
            }
            1 => items.push(hostile(rng)),
            _ => items.clear(),
        },
        other => *other = hostile(rng),
    }
}

/// One valid-looking message per type, wired to identities from another room where it matters.
fn templates(
    own_code: &str,
    victim_code: &str,
    ids: &[String],
    token: &str,
    proof: &str,
) -> Vec<Value> {
    let pid = ids[0].as_str();
    vec![
        json!({"v": 1, "reqId": "f", "type": "CREATE_ROOM", "hostName": "Mal", "config": config_json()}),
        json!({"v": 1, "reqId": "f", "type": "JOIN_ROOM", "roomCode": own_code, "name": "Eve",
               "seatIndex": 3, "spectator": false}),
        json!({"v": 1, "reqId": "f", "type": "RESUME", "roomCode": victim_code, "sessionToken": token,
               "lastStateVersion": 1, "hostToken": proof}),
        json!({"v": 1, "reqId": "f", "type": "START_HAND"}),
        json!({"v": 1, "reqId": "f", "type": "GAME_ACTION", "actionSeq": 1,
               "action": {"kind": "RAISE", "toAmount": 40}}),
        json!({"v": 1, "reqId": "f", "type": "GAME_ACTION", "actionSeq": 0, "action": {"kind": "ALL_IN"}}),
        json!({"v": 1, "reqId": "f", "type": "BEGIN_SHOWDOWN"}),
        json!({"v": 1, "reqId": "f", "type": "RESOLVE_SHOWDOWN",
               "allocations": [{"potIndex": 0, "winnerPlayerIds": [pid]}]}),
        json!({"v": 1, "reqId": "f", "type": "UNDO"}),
        json!({"v": 1, "reqId": "f", "type": "PAUSE", "reason": "fuzz"}),
        json!({"v": 1, "reqId": "f", "type": "RESUME_GAME"}),
        json!({"v": 1, "reqId": "f", "type": "APPROVE_REBUY", "playerId": pid, "amount": 500}),
        json!({"v": 1, "reqId": "f", "type": "KICK", "playerId": pid}),
        json!({"v": 1, "reqId": "f", "type": "ROOM_CONFIGURE", "config": config_json()}),
        json!({"v": 1, "reqId": "f", "type": "END_GAME"}),
        json!({"v": 1, "reqId": "f", "type": "REQUEST_REBUY", "amount": 500}),
        json!({"v": 1, "reqId": "f", "type": "SET_SITTING_OUT", "sittingOut": true}),
        json!({"v": 1, "reqId": "f", "type": "LEAVE_TABLE"}),
        json!({"v": 1, "reqId": "f", "type": "PRESENCE_VOTE", "playerId": pid, "stillPlaying": false}),
        json!({"v": 1, "reqId": "f", "type": "PRESENCE_ACK"}),
        json!({"v": 1, "reqId": "f", "type": "PING", "t": 1}),
    ]
}

/// Types a mutation may switch to. `JOIN_ROOM` is left out on purpose: a join with the victim's
/// code is a legitimate way to change that room, not an attack on it.
const TYPES: &[&str] = &[
    "CREATE_ROOM",
    "RESUME",
    "START_HAND",
    "GAME_ACTION",
    "BEGIN_SHOWDOWN",
    "RESOLVE_SHOWDOWN",
    "UNDO",
    "PAUSE",
    "RESUME_GAME",
    "APPROVE_REBUY",
    "KICK",
    "ROOM_CONFIGURE",
    "END_GAME",
    "REQUEST_REBUY",
    "SET_SITTING_OUT",
    "LEAVE_TABLE",
    "PRESENCE_VOTE",
    "PRESENCE_ACK",
    "PING",
    "NOT_A_TYPE",
];

/// Text for one frame: mostly mutated messages, sometimes plain garbage.
fn hostile_text(rng: &mut Rng, pool: &[Value]) -> String {
    match rng.below(10) {
        0 => String::from_utf8_lossy(&rng.bytes(200)).into_owned(),
        1 => "{".repeat(rng.below(300)),
        2 => {
            // A valid message with random bytes flipped in the serialised text.
            let mut bytes = rng.pick(pool).to_string().into_bytes();
            for _ in 0..=rng.below(4) {
                let at = rng.below(bytes.len());
                bytes[at] = u8::try_from(rng.next() & 0x7f).unwrap();
            }
            String::from_utf8_lossy(&bytes).into_owned()
        }
        3 => {
            // Duplicate keys, which JSON parsers handle differently.
            r#"{"v":1,"type":"PING","t":1,"type":"END_GAME","t":"x"}"#.to_owned()
        }
        _ => {
            let mut value = rng.pick(pool).clone();
            for _ in 0..=rng.below(3) {
                mutate(rng, &mut value, TYPES);
            }
            value.to_string()
        }
    }
}

// -------------------------------------------------------------------------------------------
// Frame and connection abuse
// -------------------------------------------------------------------------------------------

async fn abuse_frames(rng: &mut Rng, addr: SocketAddr, pool: &[Value]) {
    let mut ws = WsClient::connect(addr).await;
    for _ in 0..=rng.below(5) {
        let json = rng.pick(pool).to_string().into_bytes();
        match rng.below(14) {
            0 => ws.send_frame(0x82, &json, true, None).await, // binary frame
            1 => {
                ws.send_frame(0x81, &[0xff, 0xfe, 0xfd, b'{'], true, None)
                    .await; // invalid UTF-8
            }
            2 => ws.send_frame(0x80, &json, true, None).await, // continuation with nothing to continue
            3 => {
                ws.send_frame(0x01, &json[..json.len() / 2], true, None)
                    .await; // fragmented text
                ws.send_frame(0x80, &json[json.len() / 2..], true, None)
                    .await;
            }
            4 => ws.send_frame(0x81 | 0x40, &json, true, None).await, // reserved bit set
            5 => {
                let opcode = *rng.pick(&[0x03_u8, 0x04, 0x07, 0x0b, 0x0f]);
                ws.send_frame(0x80 | opcode, &json, true, None).await;
            }
            6 => ws.send_frame(0x89, &[b'p'; 200], true, None).await, // oversized control frame
            7 => ws.send_frame(0x81, &json, false, None).await,       // unmasked
            8 => ws.send_frame(0x81, &json, true, Some(u64::MAX)).await, // lying length
            9 => ws.send_frame(0x81, &json, true, Some(1 << 30)).await, // promises a gigabyte
            10 => ws.send_frame(0x88, &[0x03, 0xe8, b'x'], true, None).await, // close with a reason
            11 => ws.send_frame(0x81, &[], true, None).await,         // empty text
            12 => {
                for _ in 0..20 {
                    ws.send_frame(0x89, b"hi", true, None).await; // ping flood
                }
            }
            _ => {
                let junk = rng.bytes(64);
                ws.send_raw(&junk).await;
            }
        }
        if pump(&mut ws).await.1 {
            return;
        }
    }
    ws.kill();
}

async fn raw_tcp_junk(rng: &mut Rng, addr: SocketAddr) {
    let Ok(mut stream) = TcpStream::connect(addr).await else {
        panic!("the server stopped accepting connections");
    };
    let payload: Vec<u8> = match rng.below(8) {
        0 => rng.bytes(2000),
        1 => b"GET /v1/ws HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\n".to_vec(), // never finished
        2 => {
            let mut request = b"GET /health HTTP/1.1\r\nHost: x\r\n".to_vec();
            request.extend_from_slice(format!("X-Big: {}\r\n\r\n", "a".repeat(200_000)).as_bytes());
            request
        }
        3 => b"CONNECT example.com:443 HTTP/1.1\r\nHost: x\r\n\r\n".to_vec(),
        4 => b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".to_vec(), // HTTP/2 preface
        5 => b"GET /v1/ws HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 99\r\n\r\n".to_vec(),
        6 => b"GET /v1/ws HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n".to_vec(), // no key
        _ => b"POST /v1/ws HTTP/1.1\r\nHost: x\r\nContent-Length: 99999999\r\n\r\nabc".to_vec(),
    };
    let _ = tokio::time::timeout(Duration::from_millis(500), stream.write_all(&payload)).await;
    let mut sink = [0_u8; 512];
    let _ = tokio::time::timeout(Duration::from_millis(20), stream.read(&mut sink)).await;
}

async fn odd_http(rng: &mut Rng, addr: SocketAddr) {
    let mut path = String::from("/v1/room/");
    for _ in 0..rng.below(24) {
        match rng.below(3) {
            0 => {
                let _ = write!(path, "%{:02X}", rng.below(256));
            }
            1 => path.push_str(rng.pick(&["..", "/", "?", "%00", "%2e%2e", "ÄÖ"])),
            _ => path.push(char::from(b'A' + u8::try_from(rng.below(26)).unwrap())),
        }
    }
    let path = if rng.below(3) == 0 {
        rng.pick(&["/health", "/v1/info", "/", "/v1/ws/x", "/v1/room/", "/%"])
            .to_string()
    } else {
        path.replace(' ', "%20")
            .replace('Ä', "%C3%84")
            .replace('Ö', "%C3%96")
    };
    let (status, _) = http_get(addr, &path).await;
    assert!((200..600).contains(&status), "{path} gave {status}");
}

// -------------------------------------------------------------------------------------------
// The test
// -------------------------------------------------------------------------------------------

#[allow(
    clippy::too_many_lines,
    reason = "one scripted scenario, clearer unbroken"
)]
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn hostile_input_never_panics_or_reaches_another_room() {
    let previous = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        PANICS.fetch_add(1, Ordering::SeqCst);
        previous(info);
    }));
    // Real cards; then a virtual victim among real-card attackers (so every card the attacker
    // hears is a leak); then virtual on both sides (the card paths under hostile frames).
    for (victim_virtual, attacker_virtual) in [(false, false), (true, false), (true, true)] {
        ATTACKER_VIRTUAL.store(attacker_virtual, Ordering::SeqCst);
        if let Ok(mut heard) = HEARD.lock() {
            heard.clear();
        }
        run_fuzz(victim_virtual, attacker_virtual).await;
    }
}

#[allow(clippy::too_many_lines, reason = "one linear scenario")]
async fn run_fuzz(victim_virtual: bool, attacker_virtual: bool) {
    let seed: u64 = std::env::var("FUZZ_SEED")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(0x9E37_79B9_7F4A_7C15);
    let iterations: usize = std::env::var("FUZZ_ITERS")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(400);
    eprintln!("fuzz seed {seed}, {iterations} iterations");
    let mut rng = Rng(seed | 1);

    let server = poker_server_core::start(ServerConfig {
        bind: "127.0.0.1:0".parse().unwrap(),
        data_dir: None,
        limits: loose_limits(),
        timings: Timings::default(),
        mode: ServerMode::Cloud,
        server_name: "Fuzz".into(),
        events: None,
        tls: None,
    })
    .await
    .unwrap();
    let addr = server.local_addr();

    let mut victim = Victim::new(addr, victim_virtual).await;
    let before = victim.snapshot(addr).await;
    // A second look settles whether merely looking changes anything.
    assert_eq!(
        victim.snapshot(addr).await,
        before,
        "resuming must not change the room"
    );
    victim.room.host.drain(QUIET).await;
    victim.bob.ws.drain(QUIET).await;
    victim.cy.ws.drain(QUIET).await;

    // The attacker's own room: a host and a seated player, both free to misbehave inside it.
    let mut own = create(addr).await;
    let mut eve = join(addr, &own.code, "Eve").await;
    let ids = victim.ids();
    let make_pool = |own: &Room, eve: &Seat, victim: &Victim, ids: &[String]| {
        // Own tokens against the victim's code: the strongest thing a stranger can try.
        let mut pool = templates(&own.code, &victim.room.code, ids, &eve.token, &own.proof);
        pool.extend(templates(
            &own.code,
            &victim.room.code,
            ids,
            &own.token,
            &own.proof,
        ));
        pool
    };
    let mut pool = make_pool(&own, &eve, &victim, &ids);

    for round in 0..iterations {
        match rng.below(12) {
            0..=2 => {
                // A stranger on a fresh socket.
                let mut ws = WsClient::connect(addr).await;
                for _ in 0..=rng.below(5) {
                    let text = hostile_text(&mut rng, &pool);
                    ws.send_text(&text).await;
                    if pump(&mut ws).await.1 {
                        break;
                    }
                }
                ws.kill();
            }
            3..=5 => {
                // The attacker's host, inside their own room.
                for _ in 0..=rng.below(4) {
                    let text = hostile_text(&mut rng, &pool);
                    own.host.send_text(&text).await;
                }
                if pump(&mut own.host).await.1 {
                    own = create(addr).await;
                    eve = join(addr, &own.code, "Eve").await;
                    pool = make_pool(&own, &eve, &victim, &ids);
                }
            }
            6..=7 => {
                // The attacker's seated player.
                for _ in 0..=rng.below(4) {
                    let text = hostile_text(&mut rng, &pool);
                    eve.ws.send_text(&text).await;
                }
                if pump(&mut eve.ws).await.1 {
                    // The room may be gone (an `END_GAME` got through in her own room): rebuild.
                    own = create(addr).await;
                    eve = join(addr, &own.code, "Eve").await;
                    pool = make_pool(&own, &eve, &victim, &ids);
                }
            }
            8..=9 => abuse_frames(&mut rng, addr, &pool).await,
            10 => raw_tcp_junk(&mut rng, addr).await,
            _ => odd_http(&mut rng, addr).await,
        }
        if round % 50 == 49 {
            let (status, _) = http_get(addr, "/health").await;
            assert_eq!(status, 200, "the server stopped answering at round {round}");
        }
    }

    // The server still works for a brand-new room.
    let (status, _) = http_get(addr, "/health").await;
    assert_eq!(status, 200);
    let mut fresh = create(addr).await;
    fresh
        .host
        .send(json!({"v": 1, "reqId": "z", "type": "PING", "t": 5}))
        .await;
    assert_eq!(fresh.host.expect("PONG").await["t"], 5);

    // The innocent room did not notice anything.
    // Looking at the room (the snapshot below) announces a reconnect, so listen first. Bob's own
    // socket is not a sentinel: the snapshots replace it.
    for (name, ws) in [("host", &mut victim.room.host), ("cy", &mut victim.cy.ws)] {
        let heard: Vec<Value> = ws
            .drain(QUIET)
            .await
            .into_iter()
            .filter(|m| m["type"] != "PRESENCE_CHECK")
            .collect();
        assert!(
            heard.is_empty(),
            "{name} heard something from outside: {heard:?}"
        );
    }
    assert_eq!(
        victim.snapshot(addr).await,
        before,
        "the victim room changed"
    );
    if victim_virtual && !attacker_virtual {
        assert!(
            !victim.secret_cards.is_empty(),
            "the victim's players were dealt cards"
        );
        let heard = HEARD.lock().unwrap().clone();
        for card in &victim.secret_cards {
            assert!(
                !heard.contains(&format!("\"{card}\"")),
                "the attacker heard the victim's hole card {card}"
            );
        }
    }
    let mut map = Map::new();
    map.insert("panics".into(), json!(PANICS.load(Ordering::SeqCst)));
    assert_eq!(PANICS.load(Ordering::SeqCst), 0, "panics happened: {map:?}");
    server.stop().await;
}
