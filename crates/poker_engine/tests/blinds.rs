//! Blind strategies: cash game, tournament levels, validation.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::blinds::{Blinds, BlindsMode, BlindsStrategy, CashGame, Tournament};
use poker_engine::{Command, GameState, Phase, PokerError};
use support::{cash, chips, pid, seat, step, try_step};

fn level(small: u64, big: u64, ante: u64) -> Blinds {
    Blinds {
        small_blind: chips(small),
        big_blind: chips(big),
        ante: chips(ante),
    }
}

fn tournament() -> Tournament {
    Tournament {
        levels: vec![level(10, 20, 0), level(15, 30, 0), level(25, 50, 5)],
        level_ms: 900_000,
    }
}

#[test]
fn cash_game_blinds_never_change() {
    let strategy = CashGame {
        blinds: level(10, 20, 0),
    };
    assert_eq!(strategy.blinds(1, 0), level(10, 20, 0));
    assert_eq!(strategy.blinds(500, 99_999_999), level(10, 20, 0));
}

#[test]
fn tournament_levels_follow_elapsed_time() {
    let strategy = tournament();
    assert_eq!(strategy.blinds(1, 0), level(10, 20, 0));
    assert_eq!(strategy.blinds(1, 899_999), level(10, 20, 0));
    assert_eq!(strategy.blinds(1, 900_000), level(15, 30, 0));
    assert_eq!(strategy.blinds(1, 1_800_000), level(25, 50, 5));
}

#[test]
fn the_last_level_repeats_forever() {
    assert_eq!(tournament().blinds(1, u64::MAX), level(25, 50, 5));
}

#[test]
fn unplayable_structures_are_rejected() {
    assert_eq!(level(0, 20, 0).validate(), Err(PokerError::InvalidAmount));
    assert_eq!(level(30, 20, 0).validate(), Err(PokerError::InvalidAmount));
    assert!(level(20, 20, 0).validate().is_ok());
    assert_eq!(
        Tournament {
            levels: vec![],
            level_ms: 1000
        }
        .validate(),
        Err(PokerError::InvalidAmount)
    );
    assert_eq!(
        Tournament {
            levels: vec![level(1, 2, 0)],
            level_ms: 0
        }
        .validate(),
        Err(PokerError::InvalidAmount)
    );
    assert_eq!(
        GameState::new(cash(0, 0, 0)),
        Err(PokerError::InvalidAmount)
    );
}

#[test]
fn tournament_time_comes_from_the_start_hand_command() {
    let mut state = GameState::new(BlindsMode::Tournament(tournament())).unwrap();
    for index in 0..3_u8 {
        step(
            &mut state,
            Command::AddPlayer {
                player_id: pid(usize::from(index)),
                seat: seat(index),
                chips: chips(1000),
            },
        );
    }
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 1_000_000,
        },
    );
    assert_eq!(state.table.hand_blinds, level(15, 30, 0));
    assert_eq!(state.table.current_bet, chips(30));
}

#[test]
fn host_can_change_blinds_between_hands_only() {
    let mut state = GameState::new(cash(10, 20, 0)).unwrap();
    for index in 0..3_u8 {
        step(
            &mut state,
            Command::AddPlayer {
                player_id: pid(usize::from(index)),
                seat: seat(index),
                chips: chips(1000),
            },
        );
    }
    step(
        &mut state,
        Command::Configure {
            blinds: cash(25, 50, 0),
        },
    );
    step(&mut state, Command::StartHand { elapsed_ms: 0 });
    assert_eq!(state.table.hand_blinds, level(25, 50, 0));
    assert_eq!(state.table.phase, Phase::PreFlop);
    assert_eq!(
        try_step(
            &mut state,
            Command::Configure {
                blinds: cash(1, 2, 0)
            }
        ),
        Err(PokerError::HandInProgress)
    );
    assert_eq!(
        try_step(
            &mut GameState::new(cash(10, 20, 0)).unwrap(),
            Command::Configure {
                blinds: cash(5, 1, 0)
            }
        ),
        Err(PokerError::InvalidAmount)
    );
}
