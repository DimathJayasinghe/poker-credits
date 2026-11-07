//! Whole solo games with the real room actor: they must always finish, conserve chips and rank
//! everybody, whatever the table size, level and human play.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::too_many_lines
)]

mod solo_support;

use std::time::{Duration, Instant};

use poker_bots::Skill;
use poker_engine::PlayerAction;
use poker_server_core::config::Timings;
use poker_server_core::protocol::ServerMessage;
use solo_support::{Human, all_in, attach, fast, fold_or_check, game_over, play, room};

fn caller(legal: &poker_engine::LegalActions) -> PlayerAction {
    if legal.can_check {
        PlayerAction::Check
    } else {
        PlayerAction::Call
    }
}

/// The finished game: every place used once, chips conserved among those still seated.
fn check_finished(human: &Human, players: u64) {
    let view = human.view();
    let order = &view.finish_order;
    let mut places: Vec<u8> = order.iter().map(|f| f.place).collect();
    places.sort_unstable();
    places.dedup();
    assert_eq!(
        places.len(),
        order.len(),
        "a place is used twice: {order:?}"
    );
    assert!(
        order
            .iter()
            .all(|f| u64::from(f.place) <= players && f.place >= 1)
    );
    let total: u64 = view.seats.iter().map(|s| s.chips).sum();
    assert_eq!(total, players * 1000, "chips were created or lost");
    let human_entry = order.iter().find(|f| f.player_id == "p_1");
    assert!(
        human_entry.is_some(),
        "the game ended without ranking the human"
    );
    if human_entry.is_some_and(|f| f.place == 1) {
        // The human won: everybody else went out, so every place is taken.
        assert_eq!(order.len() as u64, players);
    }
}

#[tokio::test(start_paused = true)]
async fn nine_bot_game_runs_to_a_winner_or_a_bust() {
    for (seed, skill) in [(1_u8, Skill::Easy), (2, Skill::Normal), (3, Skill::Hard)] {
        let room = room(9, skill, seed, &fast(), None);
        let mut human = attach(&room, 1).await;
        play(&room, &mut human, 20_000, caller, game_over).await;
        check_finished(&human, 10);
        room.handle.close().await;
    }
}

#[tokio::test(start_paused = true)]
async fn a_busy_human_still_ends_every_game() {
    let room = room(5, Skill::Normal, 4, &fast(), None);
    let mut human = attach(&room, 1).await;
    play(&room, &mut human, 20_000, all_in, game_over).await;
    check_finished(&human, 6);
}

#[tokio::test(start_paused = true)]
async fn an_idle_human_turn_costs_nothing() {
    // The human is on turn and does not act: the room must sit still. Nothing is sent, nothing
    // moves, for as long as they like, and the room is still there afterwards.
    let room = room(4, Skill::Hard, 5, &Timings::default(), None);
    let mut human = attach(&room, 1).await;
    for _ in 0..40 {
        tokio::time::sleep(Duration::from_millis(500)).await;
        human.pump().await;
        if human.view().active_seat == Some(0) {
            break;
        }
    }
    assert_eq!(human.view().active_seat, Some(0), "never the human's turn");
    let mark = human.log.len();
    tokio::time::sleep(Duration::from_mins(30)).await;
    assert!(human.pump().await.is_empty(), "something moved on its own");
    assert_eq!(human.log.len(), mark);
    assert!(!room.task.is_finished());
}

#[tokio::test(start_paused = true)]
async fn soak_one_hundred_games_never_stall() {
    let started = Instant::now();
    for game in 0..100_u8 {
        let bots = 1 + game % 9;
        // Mostly cheap bots; a few thinking ones to cover the real decision path.
        let skill = match game % 10 {
            0 => Skill::Hard,
            1..=3 => Skill::Normal,
            _ => Skill::Easy,
        };
        let room = room(bots, skill, game, &fast(), None);
        let mut human = attach(&room, 1).await;
        if game % 2 == 0 {
            play(&room, &mut human, 20_000, fold_or_check, game_over).await;
        } else {
            play(&room, &mut human, 20_000, all_in, game_over).await;
        }
        check_finished(&human, u64::from(bots) + 1);
        let actions = human
            .log
            .iter()
            .filter(|m| matches!(m, ServerMessage::ActionPerformed { .. }))
            .count();
        assert!(actions > 0);
        room.handle.close().await;
    }
    assert!(
        started.elapsed() < Duration::from_mins(3),
        "100 games took {:?}",
        started.elapsed()
    );
}
