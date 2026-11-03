//! The room actor over plain channels: no sockets. Time is paused, so deadlines are exact.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::time::Duration;

use poker_engine::PlayerAction;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{ClientMessage, ErrorCode, RoomConfig, ServerMessage, WirePhase};
use poker_server_core::room::actor::{self, Clock, Created, ExitReason, NewRoom};
use poker_server_core::room::handle::{ConnId, Outbound, RoomHandle};
use tokio::sync::mpsc;

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

fn new_room(data_dir: Option<std::path::PathBuf>) -> Created {
    let new = NewRoom {
        code: "ABCD".into(),
        config: config(),
        host_name: "Host".into(),
        data_dir,
    };
    actor::create(new, &Limits::default(), &Timings::default(), Clock::new()).unwrap()
}

/// One fake connection.
struct Client {
    conn: ConnId,
    rx: mpsc::Receiver<Outbound>,
    id: String,
    token: String,
}

async fn settle() {
    tokio::time::sleep(Duration::from_millis(1)).await;
}

impl Client {
    async fn drain(&mut self) -> Vec<ServerMessage> {
        settle().await;
        let mut out = Vec::new();
        while let Ok(item) = self.rx.try_recv() {
            out.push(item.message);
        }
        out
    }
}

async fn attach_host(room: &Created, conn: ConnId) -> Client {
    let (tx, rx) = mpsc::channel(64);
    let id = room
        .handle
        .resume(
            conn,
            tx,
            None,
            room.session_token.clone(),
            Some(room.host_token.clone()),
        )
        .await
        .unwrap();
    Client {
        conn,
        rx,
        id,
        token: room.session_token.clone(),
    }
}

async fn join(handle: &RoomHandle, conn: ConnId, name: &str) -> Client {
    let (tx, mut rx) = mpsc::channel(64);
    let id = handle
        .join(conn, tx, Some("j".into()), name.into(), false, None)
        .await
        .unwrap();
    settle().await;
    let mut token = String::new();
    while let Ok(item) = rx.try_recv() {
        if let ServerMessage::Joined { session_token, .. } = item.message {
            token = session_token;
        }
    }
    Client {
        conn,
        rx,
        id,
        token,
    }
}

fn last_state_phase(messages: &[ServerMessage]) -> Option<WirePhase> {
    messages.iter().rev().find_map(|m| match m {
        ServerMessage::StateUpdate { view, .. } => Some(view.phase),
        _ => None,
    })
}

#[tokio::test(start_paused = true)]
async fn host_resume_needs_both_tokens() {
    let room = new_room(None);
    let (tx, _rx) = mpsc::channel(8);
    let no_host_token = room
        .handle
        .resume(1, tx.clone(), None, room.session_token.clone(), None)
        .await
        .unwrap_err();
    assert_eq!(no_host_token.code, ErrorCode::InvalidSession);
    let wrong = room
        .handle
        .resume(1, tx, None, "nope".into(), Some(room.host_token.clone()))
        .await;
    assert_eq!(wrong.unwrap_err().code, ErrorCode::InvalidSession);
    let mut host = attach_host(&room, 1).await;
    let first = host.drain().await;
    assert!(
        matches!(first.first(), Some(ServerMessage::Snapshot { .. })),
        "{first:?}"
    );
}

#[tokio::test(start_paused = true)]
async fn join_sends_joined_then_snapshot_and_tells_the_others() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    host.drain().await;
    let (tx, mut rx) = mpsc::channel(64);
    let id = room
        .handle
        .join(2, tx, Some("r1".into()), "Bob".into(), false, None)
        .await
        .unwrap();
    assert_eq!(id, "p_2");
    settle().await;
    let first = rx.try_recv().unwrap();
    assert_eq!(first.req_id.as_deref(), Some("r1"));
    assert!(matches!(first.message, ServerMessage::Joined { .. }));
    assert!(matches!(
        rx.try_recv().unwrap().message,
        ServerMessage::Snapshot { .. }
    ));
    let seen = host.drain().await;
    assert!(
        seen.iter()
            .any(|m| matches!(m, ServerMessage::StateUpdate { .. }))
    );
    assert!(seen.iter().any(|m| matches!(
        m,
        ServerMessage::PlayerConnection { player_id, is_connected: true, .. } if player_id == "p_2"
    )));
}

#[tokio::test(start_paused = true)]
async fn a_hand_flows_with_prompts_acks_and_duplicate_detection() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    let mut cy = join(&room.handle, 3, "Cy").await;
    host.drain().await;
    bob.drain().await;
    cy.drain().await;

    room.handle
        .send(host.conn, Some("s".into()), ClientMessage::StartHand)
        .await
        .unwrap();
    let mut everyone = [&mut host, &mut bob, &mut cy];
    let mut actor_ix = None;
    for (index, client) in everyone.iter_mut().enumerate() {
        let messages = client.drain().await;
        assert_eq!(last_state_phase(&messages), Some(WirePhase::PreFlop));
        if messages
            .iter()
            .any(|m| matches!(m, ServerMessage::TurnPrompt { .. }))
        {
            actor_ix = Some(index);
        }
    }
    let actor_ix = actor_ix.expect("exactly one player is prompted");
    let conn = everyone[actor_ix].conn;
    let name = everyone[actor_ix].id.clone();

    let call = ClientMessage::GameAction {
        action_seq: 0,
        action: PlayerAction::Call,
    };
    room.handle
        .send(conn, Some("a1".into()), call.clone())
        .await
        .unwrap();
    room.handle
        .send(conn, Some("a1".into()), call)
        .await
        .unwrap();
    let replies = everyone[actor_ix].drain().await;
    let acks: Vec<_> = replies
        .iter()
        .filter_map(|m| match m {
            ServerMessage::Ack {
                next_action_seq,
                duplicate,
            } => Some((*next_action_seq, *duplicate)),
            _ => None,
        })
        .collect();
    assert_eq!(
        acks,
        vec![(1, false), (1, true)],
        "{name}: second send is a duplicate"
    );
}

#[tokio::test(start_paused = true)]
async fn a_player_cannot_use_host_commands() {
    let room = new_room(None);
    let _host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    bob.drain().await;
    room.handle
        .send(bob.conn, Some("x".into()), ClientMessage::StartHand)
        .await
        .unwrap();
    let got = bob.drain().await;
    assert!(got.iter().any(|m| matches!(
        m,
        ServerMessage::Error {
            code: ErrorCode::HostOnlyAction,
            ..
        }
    )));
}

#[tokio::test(start_paused = true)]
async fn turn_timeout_fires_on_its_own() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    let _bob = join(&room.handle, 2, "Bob").await;
    host.drain().await;
    room.handle
        .send(host.conn, None, ClientMessage::StartHand)
        .await
        .unwrap();
    host.drain().await;
    tokio::time::sleep(Duration::from_secs(31)).await;
    let got = host.drain().await;
    let auto = got
        .iter()
        .any(|m| matches!(m, ServerMessage::ActionPerformed { auto: true, .. }));
    assert!(
        auto,
        "the server acted for the player who ran out of time: {got:?}"
    );
}

#[tokio::test(start_paused = true)]
async fn closing_a_connection_is_announced_once() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    let bob = join(&room.handle, 2, "Bob").await;
    host.drain().await;
    room.handle.detach(bob.conn);
    let got = host.drain().await;
    let offline = got
        .iter()
        .filter(|m| {
            matches!(
                m,
                ServerMessage::PlayerConnection {
                    is_connected: false,
                    ..
                }
            )
        })
        .count();
    assert_eq!(offline, 1);
}

#[tokio::test(start_paused = true)]
async fn a_slow_consumer_is_dropped_without_blocking_the_room() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    // Room for `JOINED` and `SNAPSHOT` only; the next broadcast does not fit.
    let (tx, _never_read) = mpsc::channel(2);
    room.handle
        .join(2, tx, None, "Slow".into(), false, None)
        .await
        .unwrap();
    for n in 0..5 {
        room.handle
            .send(host.conn, None, ClientMessage::Ping { t: n })
            .await
            .unwrap();
    }
    room.handle
        .send(
            host.conn,
            None,
            ClientMessage::SetSittingOut { sitting_out: true },
        )
        .await
        .unwrap();
    room.handle
        .send(
            host.conn,
            None,
            ClientMessage::SetSittingOut { sitting_out: false },
        )
        .await
        .unwrap();
    let got = host.drain().await;
    assert!(got.iter().any(|m| matches!(
        m,
        ServerMessage::PlayerConnection { player_id, is_connected: false, .. } if player_id == "p_2"
    )), "{got:?}");
    assert!(!room.handle.is_closed());
}

#[tokio::test(start_paused = true)]
async fn the_room_survives_a_restart_from_disk() {
    let dir = tempfile::tempdir().unwrap();
    let room = new_room(Some(dir.path().to_path_buf()));
    let mut host = attach_host(&room, 1).await;
    let bob = join(&room.handle, 2, "Bob").await;
    let _cy = join(&room.handle, 3, "Cy").await;
    room.handle
        .send(host.conn, None, ClientMessage::StartHand)
        .await
        .unwrap();
    host.drain().await;
    let before = {
        room.handle
            .send(host.conn, None, ClientMessage::Ping { t: 1 })
            .await
            .unwrap();
        let (tx, mut rx) = mpsc::channel(8);
        room.handle
            .resume(9, tx, None, bob.token.clone(), None)
            .await
            .unwrap();
        settle().await;
        match rx.try_recv().unwrap().message {
            ServerMessage::Snapshot {
                view,
                state_version,
                ..
            } => (view, state_version),
            other => panic!("expected a snapshot, got {other:?}"),
        }
    };

    // Kill the first room (as a crash would) and bring it back from disk.
    room.task.abort();
    let _ = room.task.await;
    let (handle, _task) = actor::restore(
        dir.path().join("ABCD"),
        &Limits::default(),
        &Timings::default(),
        Clock::new(),
    )
    .unwrap();
    let (tx, mut rx) = mpsc::channel(8);
    handle
        .resume(1, tx, None, bob.token.clone(), None)
        .await
        .unwrap();
    settle().await;
    let ServerMessage::Snapshot {
        view,
        state_version,
        ..
    } = rx.try_recv().unwrap().message
    else {
        panic!("expected a snapshot");
    };
    assert_eq!(state_version, before.1);
    let mut expected = before.0;
    for seat in &mut expected.seats {
        seat.is_connected = false;
    }
    let mut got = view;
    for seat in &mut got.seats {
        seat.is_connected = false;
    }
    assert_eq!(got, expected);
}

#[tokio::test(start_paused = true)]
async fn an_idle_room_expires() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    host.drain().await;
    tokio::time::sleep(Duration::from_secs(3601)).await;
    assert_eq!(room.task.await.unwrap(), ExitReason::Expired);
    let got = host.drain().await;
    assert!(got.iter().any(|m| matches!(m, ServerMessage::RoomExpired)));
}

#[tokio::test(start_paused = true)]
async fn end_game_stops_the_room() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    host.drain().await;
    room.handle
        .send(host.conn, None, ClientMessage::EndGame)
        .await
        .unwrap();
    assert_eq!(room.task.await.unwrap(), ExitReason::Ended);
    assert!(
        host.drain()
            .await
            .iter()
            .any(|m| matches!(m, ServerMessage::RoomExpired))
    );
    let _ = host.token;
}

#[tokio::test(start_paused = true)]
async fn a_kicked_player_is_cut_off_and_cannot_resume() {
    let room = new_room(None);
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    host.drain().await;
    bob.drain().await;
    room.handle
        .send(
            host.conn,
            None,
            ClientMessage::Kick {
                player_id: bob.id.clone(),
            },
        )
        .await
        .unwrap();
    let to_bob = bob.drain().await;
    assert!(
        matches!(
            to_bob.as_slice(),
            [ServerMessage::Error {
                code: ErrorCode::InvalidSession,
                ..
            }]
        ),
        "kicked player gets one error and no state: {to_bob:?}"
    );
    // Anything Bob sends on the old connection is refused, and the token no longer works.
    room.handle
        .send(bob.conn, Some("x".into()), ClientMessage::Ping { t: 1 })
        .await
        .unwrap();
    assert!(bob.drain().await.is_empty());
    let (tx, _rx) = mpsc::channel(8);
    let again = room
        .handle
        .resume(5, tx, None, bob.token.clone(), None)
        .await;
    assert_eq!(again.unwrap_err().code, ErrorCode::InvalidSession);
    // The room keeps working for the others.
    assert!(
        host.drain()
            .await
            .iter()
            .any(|m| matches!(m, ServerMessage::StateUpdate { .. }))
    );
}
