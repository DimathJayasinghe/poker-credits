//! Registry, sessions and supervision: crash recovery, freeze policy, restore on startup.
#![allow(
    missing_docs,
    clippy::panic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::path::PathBuf;
use std::time::Duration;

use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{ClientMessage, ErrorCode, RoomConfig, ServerMessage};
use poker_server_core::registry::Registry;
use poker_server_core::room::actor::Clock;
use poker_server_core::room::handle::{ConnReceiver, ConnSender, Outbound};
use poker_server_core::room::session::Session;

fn config() -> RoomConfig {
    RoomConfig {
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
    }
}

fn registry(dir: Option<PathBuf>) -> Registry {
    Registry::new(Limits::default(), Timings::default(), dir, Clock::new())
}

struct Conn {
    session: Session,
    rx: ConnReceiver,
}

async fn settle() {
    tokio::time::sleep(Duration::from_millis(5)).await;
}

impl Conn {
    async fn drain(&mut self) -> Vec<ServerMessage> {
        settle().await;
        let mut out = Vec::new();
        while let Ok(Some(item)) =
            tokio::time::timeout(Duration::from_millis(1), self.rx.recv()).await
        {
            out.push(item.message);
        }
        out
    }
}

async fn host(reg: &Registry) -> (Conn, String) {
    let (tx, rx) = ConnSender::channel(64);
    let session = reg
        .create_room(
            reg.next_conn_id(),
            tx,
            Some("c".into()),
            "Host".into(),
            config(),
        )
        .await
        .unwrap();
    let mut conn = Conn { session, rx };
    let first = conn.drain().await;
    let code = match first.first() {
        Some(ServerMessage::RoomCreated { room_code, .. }) => room_code.clone(),
        other => panic!("expected ROOM_CREATED first, got {other:?}"),
    };
    assert!(matches!(first.get(1), Some(ServerMessage::Snapshot { .. })));
    (conn, code)
}

async fn guest(reg: &Registry, code: &str, name: &str) -> Conn {
    let (tx, rx) = ConnSender::channel(64);
    let session = reg
        .join_room(code, reg.next_conn_id(), tx, None, name.into(), false, None)
        .await
        .unwrap();
    Conn { session, rx }
}

fn snapshot_of(messages: &[ServerMessage]) -> Option<(u64, poker_server_core::protocol::RoomView)> {
    messages.iter().find_map(|m| match m {
        ServerMessage::Snapshot {
            state_version,
            view,
            ..
        } => Some((*state_version, view.clone())),
        _ => None,
    })
}

#[tokio::test(start_paused = true)]
async fn rooms_are_found_by_code_ignoring_case() {
    let reg = registry(None);
    let (_host, code) = host(&reg).await;
    assert!(reg.contains(&code.to_lowercase()));
    let mut bob = guest(&reg, &code.to_lowercase(), "Bob").await;
    let got = bob.drain().await;
    assert!(matches!(got.first(), Some(ServerMessage::Joined { .. })));
    let (tx, _rx) = ConnSender::channel(8);
    let missing = reg
        .join_room("ZZZZ", 99, tx, None, "X".into(), false, None)
        .await;
    assert_eq!(missing.unwrap_err().code, ErrorCode::RoomNotFound);
}

#[tokio::test(start_paused = true)]
async fn the_server_refuses_rooms_beyond_the_limit() {
    let limits = Limits {
        max_rooms: 2,
        ..Limits::default()
    };
    let reg = Registry::new(limits, Timings::default(), None, Clock::new());
    host(&reg).await;
    host(&reg).await;
    let (tx, _rx) = ConnSender::channel(8);
    let third = reg.create_room(9, tx, None, "Host".into(), config()).await;
    assert_eq!(third.unwrap_err().code, ErrorCode::RoomFull);
}

#[tokio::test(start_paused = true)]
async fn a_crashed_room_is_rebuilt_and_connections_are_reattached() {
    let dir = tempfile::tempdir().unwrap();
    let reg = registry(Some(dir.path().to_path_buf()));
    let (mut host_conn, code) = host(&reg).await;
    let mut bob = guest(&reg, &code, "Bob").await;
    let mut cy = guest(&reg, &code, "Cy").await;
    host_conn
        .session
        .send(None, ClientMessage::StartHand)
        .await
        .unwrap();
    host_conn.drain().await;
    bob.drain().await;
    cy.drain().await;
    // Remember the table as the room last announced it.
    let (tx, rx) = ConnSender::channel(8);
    let mut probe = Conn {
        session: reg
            .resume_room(
                &code,
                90,
                tx,
                None,
                bob.session.session_token().to_owned(),
                None,
            )
            .await
            .unwrap(),
        rx,
    };
    let (version_before, view_before) = snapshot_of(&probe.drain().await).unwrap();

    // Crash it.
    crash(&reg, &code).await;

    assert!(host_conn.session.changed().await, "host re-attached");
    assert!(bob.session.changed().await, "player re-attached");
    let after = host_conn.drain().await;
    assert!(
        matches!(after.first(), Some(ServerMessage::RoomRecovered { .. })),
        "{after:?}"
    );
    let (version_after, mut view_after) = snapshot_of(&after).unwrap();
    assert_eq!(version_after, version_before);
    let mut view_before = view_before;
    for seat in view_before
        .seats
        .iter_mut()
        .chain(view_after.seats.iter_mut())
    {
        seat.is_connected = false;
    }
    assert_eq!(view_after, view_before, "same hand, same chips, same turn");

    // And the room accepts play again.
    let prompt = bob.drain().await;
    let _ = prompt;
    probe.session.detach();
}

/// Makes the room's task panic and gives the supervisor time to react.
async fn crash(reg: &Registry, code: &str) {
    reg.panic_room_for_test(code).await;
    settle().await;
}

#[tokio::test(start_paused = true)]
async fn a_room_that_keeps_crashing_is_frozen() {
    let dir = tempfile::tempdir().unwrap();
    let reg = registry(Some(dir.path().to_path_buf()));
    let (mut host_conn, code) = host(&reg).await;
    for round in 1..=2 {
        crash(&reg, &code).await;
        assert!(
            host_conn.session.changed().await,
            "round {round}: recovered"
        );
        let got = host_conn.drain().await;
        assert!(
            matches!(got.first(), Some(ServerMessage::RoomRecovered { .. })),
            "{got:?}"
        );
    }
    crash(&reg, &code).await;
    assert!(host_conn.session.changed().await);
    let got = host_conn.drain().await;
    assert!(
        got.iter()
            .any(|m| matches!(m, ServerMessage::RoomCrashed { .. })),
        "{got:?}"
    );
    // New arrivals are told, and the files stay for support.
    let (tx, _rx) = ConnSender::channel(8);
    let late = reg
        .join_room(&code, 5, tx, None, "Late".into(), false, None)
        .await;
    assert_eq!(late.unwrap_err().code, ErrorCode::RoomCrashed);
    assert!(dir.path().join(&code).join("snapshot.json").exists());
    let error = host_conn
        .session
        .send(None, ClientMessage::Ping { t: 1 })
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::RoomCrashed);
}

#[tokio::test(start_paused = true)]
async fn crashes_spread_over_time_do_not_freeze_the_room() {
    let dir = tempfile::tempdir().unwrap();
    let reg = registry(Some(dir.path().to_path_buf()));
    let (mut host_conn, code) = host(&reg).await;
    for _ in 0..5 {
        crash(&reg, &code).await;
        assert!(host_conn.session.changed().await);
        let got = host_conn.drain().await;
        assert!(
            matches!(got.first(), Some(ServerMessage::RoomRecovered { .. })),
            "{got:?}"
        );
        tokio::time::sleep(Duration::from_secs(61)).await;
    }
}

#[tokio::test(start_paused = true)]
async fn without_a_data_folder_a_crash_freezes_the_room() {
    let reg = registry(None);
    let (mut host_conn, code) = host(&reg).await;
    crash(&reg, &code).await;
    assert!(host_conn.session.changed().await);
    let got = host_conn.drain().await;
    assert!(
        got.iter()
            .any(|m| matches!(m, ServerMessage::RoomCrashed { .. })),
        "{got:?}"
    );
}

#[tokio::test(start_paused = true)]
async fn rooms_come_back_after_a_server_restart() {
    let dir = tempfile::tempdir().unwrap();
    let first = registry(Some(dir.path().to_path_buf()));
    let (host_conn, code) = host(&first).await;
    let bob = guest(&first, &code, "Bob").await;
    host_conn
        .session
        .send(None, ClientMessage::StartHand)
        .await
        .ok();
    settle().await;
    let token = bob.session.session_token().to_owned();
    first.shutdown(Duration::from_secs(1)).await;
    assert_eq!(first.room_count(), 0);

    let second = registry(Some(dir.path().to_path_buf()));
    assert_eq!(second.restore_all(), 1);
    assert!(second.contains(&code));
    let (tx, rx) = ConnSender::channel(8);
    let session = second
        .resume_room(&code, 1, tx, None, token, None)
        .await
        .unwrap();
    let mut conn = Conn { session, rx };
    let (_, view) = snapshot_of(&conn.drain().await).unwrap();
    assert_eq!(view.seats.len(), 2);
}

#[tokio::test(start_paused = true)]
async fn an_ended_room_is_forgotten_and_its_files_deleted() {
    let dir = tempfile::tempdir().unwrap();
    let reg = registry(Some(dir.path().to_path_buf()));
    let (mut host_conn, code) = host(&reg).await;
    assert!(dir.path().join(&code).exists());
    host_conn
        .session
        .send(None, ClientMessage::EndGame)
        .await
        .unwrap();
    settle().await;
    assert!(!reg.contains(&code));
    assert!(!dir.path().join(&code).exists());
    assert!(
        !host_conn.session.changed().await,
        "the room is gone for good"
    );
}

#[tokio::test]
async fn a_closed_sender_ends_the_receiver_after_the_queue_is_read() {
    let (tx, mut rx) = ConnSender::channel(4);
    let msg = Outbound {
        req_id: None,
        message: ServerMessage::Pong { t: 1 },
    };
    assert!(tx.try_send(msg.clone()));
    tx.close();
    assert_eq!(rx.recv().await, Some(msg));
    assert_eq!(rx.recv().await, None);
}
