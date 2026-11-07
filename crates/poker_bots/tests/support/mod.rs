//! Helpers shared by the bot tests.
#![allow(
    dead_code,
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

pub mod sim;

use poker_bots::BotRng;
use poker_engine::blinds::{Blinds, BlindsMode, CashGame};
use poker_engine::card::{Card, Rank, Suit};
use poker_engine::deck::Deck;
use poker_engine::{Chips, Command, GameState, PlayerId, SeatIndex, apply};

pub fn chips(n: u64) -> Chips {
    Chips::new(n).unwrap()
}

pub fn seat(n: u8) -> SeatIndex {
    SeatIndex::new(n).unwrap()
}

pub fn pid(n: usize) -> PlayerId {
    PlayerId::new(format!("p{n}"))
}

pub fn card(text: &str) -> Card {
    text.parse().unwrap()
}

pub fn cards(text: &str) -> Vec<Card> {
    text.split_whitespace().map(card).collect()
}

/// A uniformly shuffled 52-card deck from the bot generator (tests only).
pub fn shuffled(rng: &mut BotRng) -> Deck {
    let mut all: Vec<Card> = Vec::new();
    for rank in Rank::ALL {
        for suit in Suit::ALL {
            all.push(Card::new(rank, suit));
        }
    }
    for end in (1..all.len()).rev() {
        let pick = rng.below(u32::try_from(end + 1).unwrap()) as usize;
        all.swap(end, pick);
    }
    Deck::new(all).unwrap()
}

pub fn blinds_mode(small: u64, big: u64) -> BlindsMode {
    BlindsMode::Cash(CashGame {
        blinds: Blinds {
            small_blind: chips(small),
            big_blind: chips(big),
            ante: chips(0),
        },
    })
}

/// A table of `players` seats, each with `stack`, with a hand dealt from `deck`.
pub fn dealt_with(players: usize, stack: u64, deck: Deck) -> GameState {
    let mut state = GameState::new(blinds_mode(10, 20)).unwrap();
    for i in 0..players {
        state = apply(
            &state,
            Command::AddPlayer {
                player_id: pid(i),
                seat: seat(u8::try_from(i).unwrap()),
                chips: chips(stack),
            },
        )
        .unwrap()
        .state;
    }
    apply(
        &state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(deck),
        },
    )
    .unwrap()
    .state
}

pub fn dealt(players: usize, stack: u64, seed: u64) -> GameState {
    let mut rng = BotRng::from_seed(seed);
    dealt_with(players, stack, shuffled(&mut rng))
}
