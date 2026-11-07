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
        hands_per_level: None,
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
            level_ms: 1000,
            hands_per_level: None
        }
        .validate(),
        Err(PokerError::InvalidAmount)
    );
    assert_eq!(
        Tournament {
            levels: vec![level(1, 2, 0)],
            level_ms: 0,
            hands_per_level: None
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
            deck: None,
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
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: None,
        },
    );
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

fn ladder(hands: u32) -> Tournament {
    Tournament {
        levels: vec![level(10, 20, 0), level(15, 30, 0), level(25, 50, 5)],
        level_ms: 0,
        hands_per_level: Some(hands),
    }
}

#[test]
fn hand_ladder_rises_every_n_hands() {
    let ladder = ladder(3);
    for hand in 1..=3 {
        assert_eq!(ladder.blinds(hand, 0), level(10, 20, 0), "hand {hand}");
    }
    for hand in 4..=6 {
        assert_eq!(ladder.blinds(hand, 0), level(15, 30, 0), "hand {hand}");
    }
    assert_eq!(ladder.blinds(7, 0), level(25, 50, 5));
    assert_eq!(
        ladder.blinds(100, 0),
        level(25, 50, 5),
        "the last level repeats"
    );
}

#[test]
fn hand_ladder_ignores_elapsed_time() {
    let ladder = ladder(3);
    assert_eq!(ladder.blinds(2, 0), ladder.blinds(2, 1_000_000_000));
}

#[test]
fn hand_zero_is_the_first_level() {
    assert_eq!(ladder(3).blinds(0, 0), level(10, 20, 0));
}

#[test]
fn old_tournament_json_loads_without_the_field() {
    let json = r#"{"levels":[{"smallBlind":10,"bigBlind":20,"ante":0}],"levelMs":900000}"#;
    let parsed: Tournament = serde_json::from_str(json).unwrap();
    assert_eq!(parsed.hands_per_level, None);
    let written = serde_json::to_string(&parsed).unwrap();
    assert!(
        !written.contains("handsPerLevel"),
        "None is not written: {written}"
    );
}

#[test]
fn hand_ladder_validates() {
    assert!(ladder(3).validate().is_ok());
    let mut broken = ladder(0);
    assert_eq!(broken.validate(), Err(PokerError::InvalidAmount));
    broken.level_ms = 1000;
    assert!(
        broken.validate().is_ok(),
        "a zero hand count falls back to the clock"
    );
    broken.levels.clear();
    assert_eq!(broken.validate(), Err(PokerError::InvalidAmount));
}
