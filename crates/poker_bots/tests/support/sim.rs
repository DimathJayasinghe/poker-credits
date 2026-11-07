//! A headless driver: bots at every seat play real hands through the real engine.
#![allow(
    dead_code,
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::too_many_lines
)]

use poker_bots::{BotMind, BotRng, PublicAction, decide, view_for_seat};
use poker_engine::validator::resolve;
use poker_engine::{Command, Event, GameState, Phase, apply, showdown};

use super::{blinds_mode, chips, pid, seat, shuffled};

pub struct Bot {
    pub mind: BotMind,
    pub rng: BotRng,
}

/// What happened to the seats in one hand.
pub struct HandLog {
    pub net: Vec<i64>,
    pub actions: Vec<PublicAction>,
    pub saw_flop: Vec<bool>,
    pub raised_preflop: Vec<bool>,
}

pub fn table(stacks: &[u64], small: u64, big: u64) -> GameState {
    let mut state = GameState::new(blinds_mode(small, big)).unwrap();
    for (i, stack) in stacks.iter().enumerate() {
        state = apply(
            &state,
            Command::AddPlayer {
                player_id: pid(i),
                seat: seat(u8::try_from(i).unwrap()),
                chips: chips(*stack),
            },
        )
        .unwrap()
        .state;
    }
    state
}

fn total(state: &GameState, i: usize) -> i64 {
    i64::try_from(state.table.seat_of(&pid(i)).map_or(0, |s| s.chips.get())).unwrap()
}

/// Plays one hand to the end. Returns `Err` with a reason if a bot's action was illegal or the
/// hand could not finish; returns `Ok(None)` when fewer than two players have chips.
pub fn play_hand(
    state: &mut GameState,
    bots: &mut [Bot],
    deck_rng: &mut BotRng,
) -> Result<Option<HandLog>, String> {
    let n = bots.len();
    let funded = (0..n).filter(|i| total(state, *i) > 0).count();
    if funded < 2 {
        return Ok(None);
    }
    let before: Vec<i64> = (0..n).map(|i| total(state, i)).collect();
    *state = apply(
        state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(shuffled(deck_rng)),
        },
    )
    .map_err(|e| format!("start: {e:?}"))?
    .state;
    let mut history: Vec<PublicAction> = Vec::new();
    let mut saw_flop = vec![false; n];
    let mut raised_preflop = vec![false; n];
    let mut guard = 0;
    while state.table.phase.is_betting() {
        guard += 1;
        if guard > 500 {
            return Err("betting did not end".into());
        }
        let Some(active) = state.table.active else {
            return Err("no active seat".into());
        };
        let index = usize::from(active.get());
        let view =
            view_for_seat(&state.table, active, &history).ok_or("no view for the acting seat")?;
        let bot = &mut bots[index];
        let decision = decide(&view, &mut bot.mind, &mut bot.rng);
        let seat_ref = state.table.seat(active).unwrap();
        resolve(&state.table, seat_ref, decision.action).map_err(|e| {
            format!(
                "illegal {:?} for seat {index}: {e:?} (legal {:?})",
                decision.action, view.legal
            )
        })?;
        let street = state.table.phase;
        let transition = apply(
            state,
            Command::Action {
                player_id: pid(index),
                action: decision.action,
            },
        )
        .map_err(|e| format!("apply: {e:?}"))?;
        for event in &transition.events {
            if let Event::ActionPerformed {
                player_id,
                action,
                amount,
                ..
            } = event
            {
                let seat_no = state.table.seat_of(player_id).map(|s| s.index).unwrap();
                if street == Phase::PreFlop
                    && matches!(
                        action,
                        poker_engine::ActionKind::Raise | poker_engine::ActionKind::Bet
                    )
                {
                    raised_preflop[usize::from(seat_no.get())] = true;
                }
                history.push(PublicAction {
                    seat: seat_no,
                    street,
                    kind: *action,
                    amount: *amount,
                });
            }
        }
        *state = transition.state;
        if state.table.phase == Phase::Flop {
            for s in &state.table.seats {
                if matches!(
                    s.status,
                    poker_engine::HandStatus::Live | poker_engine::HandStatus::AllIn
                ) {
                    saw_flop[usize::from(s.index.get())] = true;
                }
            }
        }
    }
    if state.table.phase == Phase::AllInRunout {
        *state = apply(state, Command::BeginShowdown)
            .map_err(|e| format!("begin showdown: {e:?}"))?
            .state;
    }
    if matches!(state.table.phase, Phase::Showdown) {
        let allocations =
            showdown::allocations(&state.table).map_err(|e| format!("allocations: {e:?}"))?;
        *state = apply(state, Command::ResolveShowdown { allocations })
            .map_err(|e| format!("resolve: {e:?}"))?
            .state;
    }
    let net = (0..n).map(|i| total(state, i) - before[i]).collect();
    Ok(Some(HandLog {
        net,
        actions: history,
        saw_flop,
        raised_preflop,
    }))
}
