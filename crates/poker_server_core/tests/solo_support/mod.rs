//! Shared harness for the solo-game tests: a scripted human on plain channels, paused time.
#![allow(
    dead_code,
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::too_many_lines
)]

use std::time::Duration;

use poker_bots::Skill;
use poker_engine::PlayerAction;
use poker_server_core::cards::FixedEntropy;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{
    CardMode, ClientMessage, RoomConfig, RoomView, ServerMessage, SoloConfig,
};
use poker_server_core::room::actor::{self, Clock, Created, Deps, NewRoom};
use poker_server_core::room::handle::{ConnId, Outbound};
use tokio::sync::mpsc;

pub fn config(bots: u8, skill: Skill) -> RoomConfig {
    RoomConfig {
        card_mode: CardMode::Virtual,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 0,
        solo: Some(SoloConfig {
            bots,
            skill,
            ladder_hands: 2,
        }),
    }
}

pub fn script(seed: u8) -> Vec<u8> {
    (0..=255_u8)
        .map(|i| i.wrapping_mul(37).wrapping_add(seed))
        .collect()
}

/// Bots think instantly and the next hand follows at once, so a game runs in virtual seconds.
pub fn fast() -> Timings {
    Timings {
        bot_think_scale: 0.0,
        bot_next_hand_ms: 0,
        ..Timings::default()
    }
}

pub fn room(
    bots: u8,
    skill: Skill,
    seed: u8,
    timings: &Timings,
    dir: Option<std::path::PathBuf>,
) -> Created {
    let new = NewRoom {
        code: "SOLO".into(),
        config: config(bots, skill),
        host_name: "Dimath".into(),
        data_dir: dir,
    };
    let deps = Deps {
        clock: Clock::new(),
        entropy: Box::new(FixedEntropy::new(script(seed))),
    };
    actor::create_with(new, &Limits::default(), timings, deps).unwrap()
}

pub struct Human {
    pub conn: ConnId,
    pub rx: mpsc::Receiver<Outbound>,
    pub log: Vec<ServerMessage>,
    /// `nextActionSeq` of the last prompt answered, so a prompt is answered once.
    pub answered: Option<u64>,
}

pub async fn settle() {
    tokio::time::sleep(Duration::from_millis(1)).await;
}

pub async fn attach(room: &Created, conn: ConnId) -> Human {
    let (tx, rx) = mpsc::channel(4096);
    room.handle
        .resume(
            conn,
            tx,
            None,
            room.session_token.clone(),
            Some(room.host_token.clone()),
        )
        .await
        .unwrap();
    let mut human = Human {
        conn,
        rx,
        log: Vec::new(),
        answered: None,
    };
    human.pump().await;
    human
}

impl Human {
    pub async fn pump(&mut self) -> Vec<ServerMessage> {
        settle().await;
        let mut fresh = Vec::new();
        while let Ok(item) = self.rx.try_recv() {
            fresh.push(item.message);
        }
        self.log.extend(fresh.iter().cloned());
        fresh
    }

    pub fn view(&self) -> &RoomView {
        self.log
            .iter()
            .rev()
            .find_map(|m| match m {
                ServerMessage::StateUpdate { view, .. } | ServerMessage::Snapshot { view, .. } => {
                    Some(view)
                }
                _ => None,
            })
            .unwrap()
    }
}

/// Plays the human's turns with `pick` until `done` says stop. Returns after `limit` rounds.
pub async fn play(
    room: &Created,
    human: &mut Human,
    limit: usize,
    pick: impl Fn(&poker_engine::LegalActions) -> PlayerAction,
    done: impl Fn(&Human) -> bool,
) {
    for _ in 0..limit {
        human.pump().await;
        if done(human) {
            return;
        }
        // The newest prompt, unless it was already answered (or a newer message ended the turn).
        let prompt = human.log.iter().rev().find_map(|m| match m {
            ServerMessage::TurnPrompt {
                next_action_seq,
                legal,
                ..
            } => Some((*next_action_seq, *legal)),
            _ => None,
        });
        if let Some((action_seq, legal)) = prompt
            && human.answered != Some(action_seq)
        {
            human.answered = Some(action_seq);
            room.handle
                .send(
                    human.conn,
                    None,
                    ClientMessage::GameAction {
                        action_seq,
                        action: pick(&legal),
                    },
                )
                .await
                .unwrap();
        }
    }
    let tail: Vec<String> = human
        .log
        .iter()
        .rev()
        .take(8)
        .map(|m| format!("{m:?}").chars().take(160).collect())
        .collect();
    panic!(
        "the game did not reach the expected point: hand {} phase {:?} active {:?}\n{}",
        human.view().hand_number,
        human.view().phase,
        human.view().active_seat,
        tail.join("\n")
    );
}

pub fn fold_or_check(legal: &poker_engine::LegalActions) -> PlayerAction {
    if legal.can_check {
        PlayerAction::Check
    } else {
        PlayerAction::Fold
    }
}

pub fn all_in(legal: &poker_engine::LegalActions) -> PlayerAction {
    if legal.can_raise {
        PlayerAction::AllIn
    } else {
        PlayerAction::Call
    }
}

pub fn game_over(human: &Human) -> bool {
    human
        .view()
        .finish_order
        .iter()
        .any(|f| f.place == 1 || f.player_id == "p_1")
}
