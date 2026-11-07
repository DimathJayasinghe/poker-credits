//! Shared helpers for the integration tests. Lives in `tests/support/` so Cargo does not build it
//! as a test crate of its own.
#![allow(
    dead_code,
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_engine::blinds::{Blinds, BlindsMode, CashGame};
use poker_engine::{
    Chips, Command, Event, GameState, PlayerAction, PlayerId, PokerError, SeatIndex, Transition,
    apply,
};

pub fn pid(index: usize) -> PlayerId {
    PlayerId::new(format!("p{index}"))
}

pub fn seat(index: u8) -> SeatIndex {
    SeatIndex::new(index).unwrap()
}

pub fn chips(amount: u64) -> Chips {
    Chips::new(amount).unwrap()
}

pub fn cash(small_blind: u64, big_blind: u64, ante: u64) -> BlindsMode {
    BlindsMode::Cash(CashGame {
        blinds: Blinds {
            small_blind: chips(small_blind),
            big_blind: chips(big_blind),
            ante: chips(ante),
        },
    })
}

/// A lobby with players `p0..` in seats `0..` holding `stacks`.
pub fn lobby(stacks: &[u64], small_blind: u64, big_blind: u64) -> GameState {
    let mut state = GameState::new(cash(small_blind, big_blind, 0)).unwrap();
    for (index, stack) in stacks.iter().enumerate() {
        let seat_index = u8::try_from(index).unwrap();
        step(
            &mut state,
            Command::AddPlayer {
                player_id: pid(index),
                seat: seat(seat_index),
                chips: chips(*stack),
            },
        );
    }
    state
}

/// A table with the first hand already dealt.
pub fn dealt(stacks: &[u64], small_blind: u64, big_blind: u64) -> GameState {
    let mut state = lobby(stacks, small_blind, big_blind);
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: None,
        },
    );
    state
}

pub fn try_step(state: &mut GameState, command: Command) -> Result<Vec<Event>, PokerError> {
    let Transition {
        state: next,
        events,
    } = apply(state, command)?;
    *state = next;
    Ok(events)
}

pub fn step(state: &mut GameState, command: Command) -> Vec<Event> {
    try_step(state, command).unwrap()
}

pub fn act(state: &mut GameState, player: usize, action: PlayerAction) -> Vec<Event> {
    step(
        state,
        Command::Action {
            player_id: pid(player),
            action,
        },
    )
}

pub fn try_act(
    state: &mut GameState,
    player: usize,
    action: PlayerAction,
) -> Result<Vec<Event>, PokerError> {
    try_step(
        state,
        Command::Action {
            player_id: pid(player),
            action,
        },
    )
}

pub fn raise_to(amount: u64) -> PlayerAction {
    PlayerAction::Raise {
        to_amount: chips(amount),
    }
}

pub fn stack(state: &GameState, player: usize) -> u64 {
    state.table.seat_of(&pid(player)).unwrap().chips.get()
}
