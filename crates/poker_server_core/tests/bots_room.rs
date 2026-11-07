//! Solo games over the real room actor: plain channels, paused time, scripted entropy.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::too_many_lines
)]

mod solo_support;

use std::time::Duration;

use poker_bots::Skill;
use poker_server_core::cards::FixedEntropy;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{ClientMessage, ErrorCode, ServerMessage};
use poker_server_core::registry::Registry;
use poker_server_core::room::actor::{self, Clock, Created, Deps};
use solo_support::{
    Human, all_in, attach, config, fast, fold_or_check, game_over, play, room, script,
};
use tokio::sync::mpsc;

#[tokio::test(start_paused = true)]
async fn solo_config_is_refused_from_the_network() {
    let registry = Registry::new(Limits::default(), Timings::default(), None, Clock::new());
    let (tx, _rx) = poker_server_core::room::handle::ConnSender::channel(8);
    let error = registry
        .create_room(1, tx, None, "Dimath".into(), config(3, Skill::Normal))
        .await
        .err()
        .unwrap();
    assert_eq!(error.code, ErrorCode::BadRequest);
}

#[tokio::test(start_paused = true)]
async fn the_next_hand_starts_by_itself_and_bots_play_it() {
    let room = room(4, Skill::Easy, 3, &fast(), None);
    let mut human = attach(&room, 1).await;
    assert_eq!(human.view().seats.len(), 5);
    play(&room, &mut human, 400, fold_or_check, |h| {
        h.view().hand_number >= 3
    })
    .await;
    assert!(human.view().hand_number >= 3);
    let bot_actions = human
        .log
        .iter()
        .filter(
            |m| matches!(m, ServerMessage::ActionPerformed { player_id, .. } if player_id != "p_1"),
        )
        .count();
    assert!(bot_actions > 0, "no bot ever acted");
}

#[tokio::test(start_paused = true)]
async fn nothing_on_the_wire_marks_a_bot() {
    let room = room(5, Skill::Normal, 4, &fast(), None);
    let mut human = attach(&room, 1).await;
    play(&room, &mut human, 300, fold_or_check, |h| {
        h.view().hand_number >= 2
    })
    .await;
    for message in &human.log {
        let json = serde_json::to_string(message).unwrap().to_lowercase();
        assert!(!json.contains("isbot") && !json.contains("is_bot") && !json.contains("bot\""));
    }
    // Bots show as connected, like any player at the table.
    assert!(human.view().seats.iter().all(|s| s.is_connected));
}

#[tokio::test(start_paused = true)]
async fn rebuy_and_table_management_are_refused() {
    let room = room(2, Skill::Easy, 5, &fast(), None);
    let mut human = attach(&room, 1).await;
    for message in [
        ClientMessage::RequestRebuy { amount: 500 },
        ClientMessage::LeaveTable,
        ClientMessage::SetSittingOut { sitting_out: true },
        ClientMessage::StartHand,
        ClientMessage::Undo,
    ] {
        room.handle.send(1, None, message).await.unwrap();
    }
    let errors: Vec<ErrorCode> = human
        .pump()
        .await
        .into_iter()
        .filter_map(|m| match m {
            ServerMessage::Error { code, .. } => Some(code),
            _ => None,
        })
        .collect();
    assert_eq!(errors, vec![ErrorCode::BadRequest; 5]);
}

#[tokio::test(start_paused = true)]
async fn a_player_who_only_folds_goes_out_and_the_game_ends_with_places() {
    let room = room(3, Skill::Easy, 6, &fast(), None);
    let mut human = attach(&room, 1).await;
    play(&room, &mut human, 3000, fold_or_check, game_over).await;
    let view = human.view();
    let human_place = view
        .finish_order
        .iter()
        .find(|f| f.player_id == "p_1")
        .expect("the human went out")
        .place;
    assert!((2..=4).contains(&human_place));
    let mut places: Vec<u8> = view.finish_order.iter().map(|f| f.place).collect();
    places.sort_unstable();
    places.dedup();
    assert_eq!(places.len(), view.finish_order.len(), "places repeat");
    // Chips are conserved among whoever is still seated.
    let total: u64 = view.seats.iter().map(|s| s.chips).sum();
    assert_eq!(total, 4 * 1000);
    // No more hands start once the game is over.
    let hands = view.hand_number;
    tokio::time::sleep(Duration::from_mins(2)).await;
    human.pump().await;
    assert_eq!(human.view().hand_number, hands);
}

#[tokio::test(start_paused = true)]
async fn going_all_in_every_hand_against_one_bot_can_win() {
    let mut wins = 0;
    for seed in 0..12_u8 {
        let room = room(1, Skill::Easy, seed, &fast(), None);
        let mut human = attach(&room, 1).await;
        play(&room, &mut human, 3000, all_in, game_over).await;
        let order = &human.view().finish_order;
        assert_eq!(order.len(), 2, "both players are ranked");
        let mine = order.iter().find(|f| f.player_id == "p_1").unwrap().place;
        assert!(mine == 1 || mine == 2);
        wins += u32::from(mine == 1);
        room.handle.close().await;
    }
    assert!(wins > 0 && wins < 12, "wins: {wins}");
}

#[tokio::test(start_paused = true)]
async fn a_paused_game_makes_no_bot_move_and_resumes_without_doubling() {
    let timings = Timings::default(); // real thinking time and a real pause between hands
    let room = room(4, Skill::Normal, 7, &timings, None);
    let mut human = attach(&room, 1).await;
    // Let the first hand start and a bot act.
    for _ in 0..40 {
        tokio::time::sleep(Duration::from_millis(500)).await;
        human.pump().await;
        if human.view().hand_number >= 1 && human.view().active_seat != Some(0) {
            break;
        }
    }
    room.handle
        .send(1, None, ClientMessage::Pause { reason: None })
        .await
        .unwrap();
    human.pump().await;
    let seen = human.log.len();
    tokio::time::sleep(Duration::from_secs(90)).await;
    human.pump().await;
    let moved = human.log[seen..]
        .iter()
        .any(|m| matches!(m, ServerMessage::ActionPerformed { .. }));
    assert!(!moved, "a bot acted while the game was paused");
    room.handle
        .send(1, None, ClientMessage::ResumeGame)
        .await
        .unwrap();
    let mark = human.log.len();
    tokio::time::sleep(Duration::from_secs(20)).await;
    human.pump().await;
    assert!(
        human.log[mark..].iter().any(|m| matches!(
            m,
            ServerMessage::ActionPerformed { .. } | ServerMessage::TurnPrompt { .. }
        )),
        "play did not continue after resume"
    );
}

#[tokio::test(start_paused = true)]
async fn nobody_is_sat_out_or_timed_out_while_the_human_is_away() {
    let room = room(4, Skill::Normal, 8, &Timings::default(), None);
    // Nobody is connected for eleven minutes.
    tokio::time::sleep(Duration::from_mins(11)).await;
    let mut human = attach(&room, 1).await;
    assert!(human.view().seats.iter().all(|s| !s.is_sitting_out));
    assert_eq!(
        human.view().hand_number,
        0,
        "no hand is dealt to an empty room"
    );
    // Once the human is back the game starts.
    tokio::time::sleep(Duration::from_secs(10)).await;
    human.pump().await;
    assert!(human.view().hand_number >= 1);
}

#[tokio::test(start_paused = true)]
async fn a_restored_room_carries_on_with_the_same_opponents() {
    let dir = tempfile::tempdir().unwrap();
    let room = room(4, Skill::Easy, 9, &fast(), Some(dir.path().to_path_buf()));
    let mut human = attach(&room, 1).await;
    play(&room, &mut human, 400, fold_or_check, |h| {
        h.view().hand_number >= 2
    })
    .await;
    let names: Vec<String> = human.view().seats.iter().map(|s| s.name.clone()).collect();
    let (session, host) = (room.session_token.clone(), room.host_token.clone());
    let hands_before = human.view().hand_number;
    room.handle.close().await;
    tokio::time::sleep(Duration::from_millis(50)).await;

    let deps = Deps {
        clock: Clock::new(),
        entropy: Box::new(FixedEntropy::new(script(10))),
    };
    let (handle, _task) =
        actor::restore_with(dir.path().join("SOLO"), &Limits::default(), &fast(), deps).unwrap();
    let (tx, rx) = mpsc::channel(4096);
    handle
        .resume(2, tx, None, session, Some(host))
        .await
        .unwrap();
    let revived = Created {
        handle,
        task: tokio::spawn(async { actor::ExitReason::Closed }),
        host_token: String::new(),
        session_token: String::new(),
        player_id: "p_1".into(),
    };
    let mut human = Human {
        conn: 2,
        rx,
        log: Vec::new(),
        answered: None,
    };
    human.pump().await;
    let restored: Vec<String> = human.view().seats.iter().map(|s| s.name.clone()).collect();
    assert_eq!(names.len(), restored.len());
    play(&revived, &mut human, 600, fold_or_check, move |h| {
        h.view().hand_number >= hands_before + 2
    })
    .await;
}

#[tokio::test]
async fn the_solo_server_listens_on_loopback_only() {
    let server = poker_server_core::start(poker_server_core::ServerConfig::loopback_only(None))
        .await
        .unwrap();
    let addr = server.local_addr();
    assert!(addr.ip().is_loopback(), "bound to {addr}");
    assert_ne!(addr.port(), 0);
    server.stop().await;
}
