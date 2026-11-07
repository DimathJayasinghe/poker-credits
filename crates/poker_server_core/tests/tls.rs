//! The encrypted transport (ADR-019): what a guest on the LAN can and cannot do.
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
use poker_server_core::{
    Fingerprint, Identity, ServerConfig, ServerHandle, ServerMode, StartError,
};
use serde_json::json;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use ws_client::{WsClient, tls_connect};

fn config(mode: ServerMode, bind: &str, limits: Limits, tls: Option<Identity>) -> ServerConfig {
    ServerConfig {
        bind: bind.parse().unwrap(),
        data_dir: None,
        limits,
        timings: Timings::default(),
        mode,
        server_name: "Test Host".into(),
        events: None,
        tls,
    }
}

/// A TLS server in cloud mode, where a socket may send `CREATE_ROOM` (a host-mode server's rooms
/// are made by the app itself, see [`a_pinned_guest_can_join_a_host_room_over_tls`]).
async fn boot_tls() -> (ServerHandle, Fingerprint) {
    boot_tls_with(Limits::default()).await
}

async fn boot_tls_with(limits: Limits) -> (ServerHandle, Fingerprint) {
    let identity = Identity::generate().unwrap();
    let pin = identity.fingerprint();
    let server = poker_server_core::start(config(
        ServerMode::Cloud,
        "127.0.0.1:0",
        limits,
        Some(identity),
    ))
    .await
    .unwrap();
    assert_eq!(server.fingerprint(), Some(pin));
    (server, pin)
}

fn room_config() -> serde_json::Value {
    json!({"startingChips": 1000, "smallBlind": 5, "bigBlind": 10, "ante": 0,
           "isTournament": false, "blindLevelMinutes": 10, "turnTimeLimitSeconds": 30})
}

fn create_room() -> serde_json::Value {
    json!({"v": 1, "reqId": "c", "type": "CREATE_ROOM", "hostName": "Host", "config": room_config()})
}

#[tokio::test]
async fn a_pinned_guest_can_join_a_host_room_over_tls() {
    let identity = Identity::generate().unwrap();
    let pin = identity.fingerprint();
    let server = poker_server_core::start(config(
        ServerMode::Host,
        "127.0.0.1:0",
        Limits::default(),
        Some(identity),
    ))
    .await
    .unwrap();
    let room = server
        .registry()
        .create_room_detached(
            "Dimath".into(),
            serde_json::from_value(room_config()).unwrap(),
        )
        .unwrap();
    let mut guest = WsClient::connect_tls(server.local_addr(), Some(pin)).await;
    guest
        .send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": room.room_code, "name": "Ana", "spectator": false}))
        .await;
    guest.expect("JOINED").await;
    server.stop().await;
}

#[tokio::test]
async fn a_pinned_guest_can_play_over_tls() {
    let (server, pin) = boot_tls().await;
    let addr = server.local_addr();

    let mut host = WsClient::connect_tls(addr, Some(pin)).await;
    host.send(create_room()).await;
    let created = host.expect("ROOM_CREATED").await;
    host.expect("SNAPSHOT").await;
    let code = created["roomCode"].as_str().unwrap().to_owned();

    let mut guest = WsClient::connect_tls(addr, Some(pin)).await;
    guest
        .send(json!({"v": 1, "type": "JOIN_ROOM", "roomCode": code, "name": "Ana", "spectator": false}))
        .await;
    guest.expect("JOINED").await;
    server.stop().await;
}

#[tokio::test]
async fn the_per_address_limits_still_see_the_guest_address() {
    // `ConnectInfo<SocketAddr>` must survive the TLS listener, or every limiter would go blind.
    let limits = Limits {
        max_connections_per_ip: 2,
        ..Limits::default()
    };
    let (server, pin) = boot_tls_with(limits).await;
    let addr = server.local_addr();
    let _first = WsClient::connect_tls(addr, Some(pin)).await;
    let _second = WsClient::connect_tls(addr, Some(pin)).await;
    let third = tls_connect(addr, Some(pin)).await.unwrap();
    let status = ws_upgrade_status(third, addr).await;
    assert_eq!(
        status, 429,
        "the third connection from one address is refused"
    );
    server.stop().await;
}

/// Sends a bare upgrade request on an open stream and returns the HTTP status.
async fn ws_upgrade_status(mut stream: Box<dyn ws_client::Conn>, addr: SocketAddr) -> u16 {
    let request = format!(
        "GET /v1/ws HTTP/1.1\r\nHost: {addr}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\
         Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    );
    stream.write_all(request.as_bytes()).await.unwrap();
    let mut raw = vec![0_u8; 512];
    let n = tokio::time::timeout(Duration::from_secs(5), stream.read(&mut raw))
        .await
        .unwrap()
        .unwrap();
    let text = String::from_utf8_lossy(&raw[..n]).into_owned();
    text.split_whitespace().nth(1).unwrap().parse().unwrap()
}

#[tokio::test]
async fn a_guest_with_the_wrong_pin_is_refused_before_any_message() {
    let (server, _pin) = boot_tls().await;
    let other = Identity::generate().unwrap().fingerprint();
    let refused = tls_connect(server.local_addr(), Some(other)).await;
    assert!(
        refused.is_err(),
        "a different certificate must not be accepted"
    );
    server.stop().await;
}

#[tokio::test]
async fn a_plaintext_client_gets_no_http_answer_from_a_tls_listener() {
    let (server, _pin) = boot_tls().await;
    let addr = server.local_addr();
    let mut tcp = TcpStream::connect(addr).await.unwrap();
    tcp.write_all(
        format!("GET /v1/info HTTP/1.1\r\nHost: {addr}\r\nConnection: close\r\n\r\n").as_bytes(),
    )
    .await
    .unwrap();
    let mut raw = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(5), tcp.read_to_end(&mut raw)).await;
    let text = String::from_utf8_lossy(&raw);
    assert!(!text.contains("HTTP/1.1"), "answered in the clear: {text}");
    assert!(
        !text.contains("Test Host"),
        "leaked the server name: {text}"
    );
    server.stop().await;
}

#[tokio::test]
async fn a_host_will_not_listen_on_the_network_without_tls() {
    for bind in ["0.0.0.0:0", "[::]:0"] {
        let refused =
            poker_server_core::start(config(ServerMode::Host, bind, Limits::default(), None)).await;
        assert!(
            matches!(refused, Err(StartError::PlaintextOnNetwork { .. })),
            "{bind}: {refused:?}"
        );
    }
    // Loopback (the solo game) and the cloud binary behind its proxy stay plain.
    for (mode, bind) in [
        (ServerMode::Host, "127.0.0.1:0"),
        (ServerMode::Cloud, "0.0.0.0:0"),
    ] {
        let server = poker_server_core::start(config(mode, bind, Limits::default(), None))
            .await
            .unwrap();
        assert_eq!(server.fingerprint(), None);
        server.stop().await;
    }
}

#[tokio::test]
async fn a_host_can_listen_on_the_network_with_tls() {
    let identity = Identity::generate().unwrap();
    let server = poker_server_core::start(config(
        ServerMode::Host,
        "0.0.0.0:0",
        Limits::default(),
        Some(identity),
    ))
    .await
    .unwrap();
    server.stop().await;
}

#[tokio::test]
async fn stopping_frees_the_port_for_the_next_host() {
    let probe = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = probe.local_addr().unwrap();
    drop(probe);
    let identity = Identity::generate().unwrap();
    for _ in 0..3 {
        let server = poker_server_core::start(config(
            ServerMode::Host,
            &addr.to_string(),
            Limits::default(),
            Some(identity.clone()),
        ))
        .await
        .expect("the port is free again after stop");
        assert_eq!(server.local_addr(), addr);
        server.stop().await;
    }
}

#[tokio::test]
async fn the_same_identity_gives_the_same_pin_after_a_restart() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("tls-identity.bin");
    let mut pins = Vec::new();
    for _ in 0..2 {
        let identity = Identity::load_or_create(&path).unwrap();
        let server = poker_server_core::start(config(
            ServerMode::Host,
            "127.0.0.1:0",
            Limits::default(),
            Some(identity),
        ))
        .await
        .unwrap();
        pins.push(server.fingerprint().unwrap());
        server.stop().await;
    }
    assert_eq!(pins[0], pins[1]);
}

#[tokio::test]
async fn silent_sockets_cannot_hold_up_a_real_guest() {
    // Several clients open a socket and say nothing. The handshake runs off the accept path, so
    // a guest from another address is not delayed; the idle ones are cut after the timeout.
    let (server, pin) = boot_tls().await;
    let addr = server.local_addr();
    let mut idle = Vec::new();
    for _ in 0..8 {
        idle.push(TcpStream::connect(addr).await.unwrap());
    }
    // The per-address cap is reached by now: one more from the same address is dropped at once.
    let mut ninth = TcpStream::connect(addr).await.unwrap();
    let mut byte = [0_u8; 1];
    let closed = tokio::time::timeout(Duration::from_secs(2), ninth.read(&mut byte)).await;
    assert!(
        matches!(closed, Ok(Ok(0) | Err(_))),
        "the ninth silent socket is dropped immediately: {closed:?}"
    );

    // The idle sockets are closed by the server once the handshake time is up.
    let started = Instant::now();
    for socket in &mut idle {
        let read = tokio::time::timeout(Duration::from_secs(10), socket.read(&mut byte)).await;
        assert!(matches!(read, Ok(Ok(0) | Err(_))), "{read:?}");
    }
    assert!(
        started.elapsed() < Duration::from_secs(9),
        "{:?}",
        started.elapsed()
    );

    // And the address is usable again.
    let mut guest = WsClient::connect_tls(addr, Some(pin)).await;
    guest.send(create_room()).await;
    guest.expect("ROOM_CREATED").await;
    server.stop().await;
}

/// A man in the middle that only records: what a sniffer on the Wi-Fi would see.
async fn recording_relay(server: SocketAddr) -> (SocketAddr, Arc<Mutex<Vec<u8>>>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let captured = Arc::new(Mutex::new(Vec::new()));
    let sink = Arc::clone(&captured);
    tokio::spawn(async move {
        while let Ok((mut client, _)) = listener.accept().await {
            let Ok(mut upstream) = TcpStream::connect(server).await else {
                continue;
            };
            let sink = Arc::clone(&sink);
            tokio::spawn(async move {
                let (mut cr, mut cw) = client.split();
                let (mut ur, mut uw) = upstream.split();
                let up = async {
                    let mut buf = [0_u8; 4096];
                    while let Ok(n) = cr.read(&mut buf).await {
                        if n == 0 {
                            break;
                        }
                        sink.lock().unwrap().extend_from_slice(&buf[..n]);
                        if uw.write_all(&buf[..n]).await.is_err() {
                            break;
                        }
                    }
                };
                let down = async {
                    let mut buf = [0_u8; 4096];
                    while let Ok(n) = ur.read(&mut buf).await {
                        if n == 0 {
                            break;
                        }
                        sink.lock().unwrap().extend_from_slice(&buf[..n]);
                        if cw.write_all(&buf[..n]).await.is_err() {
                            break;
                        }
                    }
                };
                tokio::select! { () = up => {}, () = down => {} }
            });
        }
    });
    (addr, captured)
}

fn contains(haystack: &[u8], needle: &str) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle.as_bytes())
}

#[tokio::test]
async fn a_sniffer_sees_tokens_in_the_clear_only_without_tls() {
    // Control: the relay really does capture plain traffic, so an empty result below means
    // something.
    let plain = poker_server_core::start(config(
        ServerMode::Cloud,
        "127.0.0.1:0",
        Limits::default(),
        None,
    ))
    .await
    .unwrap();
    let (relay, captured) = recording_relay(plain.local_addr()).await;
    let mut ws = WsClient::connect(relay).await;
    ws.send(create_room()).await;
    let created = ws.expect("ROOM_CREATED").await;
    let token = created["sessionToken"].as_str().unwrap().to_owned();
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert!(
        contains(&captured.lock().unwrap(), &token),
        "the control run must see the token"
    );
    plain.stop().await;

    let (secure, pin) = boot_tls().await;
    let (relay, captured) = recording_relay(secure.local_addr()).await;
    let mut ws = WsClient::connect_tls(relay, Some(pin)).await;
    ws.send(create_room()).await;
    let created = ws.expect("ROOM_CREATED").await;
    let token = created["sessionToken"].as_str().unwrap().to_owned();
    let host_token = created["hostToken"].as_str().unwrap().to_owned();
    ws.expect("SNAPSHOT").await;
    tokio::time::sleep(Duration::from_millis(100)).await;
    let wire = captured.lock().unwrap().clone();
    assert!(
        wire.len() > 500,
        "the relay saw the handshake and the frames"
    );
    for secret in [
        token.as_str(),
        host_token.as_str(),
        "ROOM_CREATED",
        "CREATE_ROOM",
        "Host",
    ] {
        assert!(!contains(&wire, secret), "{secret} was visible on the wire");
    }
    secure.stop().await;
}

#[tokio::test]
async fn tls_works_with_http_routes_too() {
    let (server, pin) = boot_tls().await;
    let addr = server.local_addr();
    let mut stream = tls_connect(addr, Some(pin)).await.unwrap();
    stream
        .write_all(
            format!("GET /v1/info HTTP/1.1\r\nHost: {addr}\r\nConnection: close\r\n\r\n")
                .as_bytes(),
        )
        .await
        .unwrap();
    let mut raw = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(5), stream.read_to_end(&mut raw)).await;
    let text = String::from_utf8_lossy(&raw);
    assert!(text.starts_with("HTTP/1.1 200"), "{text}");
    assert!(text.contains("Test Host"), "{text}");
    server.stop().await;
}
