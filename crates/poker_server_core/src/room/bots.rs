//! The computer players' turns. Not part of the persisted room: a restored room builds a new
//! driver from the saved profiles and plays on (the bots lose only their notes about the others).
//!
//! The driver never touches the state. It looks at it, works out what the bot to act would do and
//! when, and hands the actor an ordinary [`Op::Act`] to journal, exactly as if a client had sent
//! it. There is no polling: the actor sleeps until [`BotDriver::next_due_ms`].
//!
//! Fairness: the only thing a strategy ever receives is the `BotView` that
//! [`poker_bots::view_for_seat`] copies out of the table for that one seat.

use std::collections::BTreeMap;

use poker_bots::{BotMind, BotRng, Decision, PublicAction, Reveal, decide, view_for_seat};
use poker_engine::{Event, Phase, PlayerAction, SeatIndex, showdown};

use super::state::{Op, RoomState, engine_id};
use crate::config::Timings;

/// Added to a bot's seed on every restore so it does not replay the same dice from the start.
const RESTORE_SALT: u64 = 0x9E37_79B9_7F4A_7C15;

struct Bot {
    mind: BotMind,
    rng: BotRng,
}

/// The moment a decision was made for, so a stale one is never used.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Moment {
    hand: u32,
    phase: Phase,
    seat: SeatIndex,
    seen_actions: usize,
}

struct Pending {
    moment: Moment,
    player_id: String,
    action: PlayerAction,
    /// When it acts; `None` while the game is paused (`left_ms` is then what remains).
    act_at_ms: Option<u64>,
    left_ms: u64,
}

/// All computer players of one room.
pub(super) struct BotDriver {
    bots: BTreeMap<String, Bot>,
    /// Public betting of the hand being played.
    history: Vec<PublicAction>,
    pending: Option<Pending>,
    next_hand_at_ms: Option<u64>,
    /// The hand and the number of board cards the table last showed, and when the deal or the
    /// latest street appeared: nobody acts before it has been on show for `bot_look_ms`.
    seen: (u32, usize),
    scene_at_ms: u64,
    /// Time the app needs to show the streets of a run-out in this hand.
    runout_extra_ms: u64,
}

/// Streets on show with this many board cards (0 before the flop).
fn streets_shown(board_len: usize) -> u64 {
    match board_len {
        0..=2 => 0,
        3 => 1,
        4 => 2,
        _ => 3,
    }
}

fn to_ms(value: f32) -> u64 {
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "clamped to a non-negative duration"
    )]
    {
        value.max(0.0) as u64
    }
}

fn signed(value: u64) -> i64 {
    i64::try_from(value).unwrap_or(i64::MAX)
}

impl BotDriver {
    /// The computer players of `state` (none for an ordinary room).
    pub(super) fn new(state: &RoomState) -> Self {
        let salt = u64::from(state.game.table.hand_number).wrapping_mul(RESTORE_SALT);
        let bots = state
            .bots
            .iter()
            .map(|(id, profile)| {
                let bot = Bot {
                    mind: BotMind::new(profile.personality(), profile.skill),
                    rng: BotRng::from_seed(profile.seed ^ 0x5EED ^ salt),
                };
                (id.clone(), bot)
            })
            .collect();
        BotDriver {
            bots,
            history: Vec::new(),
            pending: None,
            next_hand_at_ms: None,
            seen: (0, 0),
            scene_at_ms: 0,
            runout_extra_ms: 0,
        }
    }

    /// Takes in what everybody at the table saw during one accepted op. `before` is the phase the
    /// table was in when the op began (it names the street an action happened on).
    pub(super) fn observe(&mut self, before: Phase, events: &[Event], state: &RoomState) {
        if self.bots.is_empty() {
            return;
        }
        let table = &state.game.table;
        for event in events {
            match event {
                Event::HandStarted { .. } => {
                    self.history.clear();
                    let dealt: Vec<SeatIndex> = table
                        .deal
                        .as_ref()
                        .map(|deal| {
                            deal.holes
                                .iter()
                                .filter_map(|(id, _)| table.seat_of(id).map(|s| s.index))
                                .collect()
                        })
                        .unwrap_or_default();
                    for bot in self.bots.values_mut() {
                        bot.mind.begin_hand(&dealt);
                    }
                }
                Event::ActionPerformed {
                    player_id,
                    action,
                    amount,
                    ..
                } => {
                    if let Some(seat) = table.seat_of(player_id) {
                        let seen = PublicAction {
                            seat: seat.index,
                            street: before,
                            kind: *action,
                            amount: *amount,
                        };
                        self.history.push(seen);
                        for bot in self.bots.values_mut() {
                            bot.mind.observe_action(&seen);
                        }
                    }
                }
                Event::HandEnded { .. } => self.observe_hand_end(state),
                _ => {}
            }
        }
    }

    fn observe_hand_end(&mut self, state: &RoomState) {
        let table = &state.game.table;
        let reveals: Vec<Reveal> = showdown::reveals(table)
            .into_iter()
            .filter_map(|reveal| {
                Some(Reveal {
                    seat: table.seat_of(&reveal.player_id)?.index,
                    hole: reveal.cards,
                    category: reveal.category,
                })
            })
            .collect();
        let big_blind = table.hand_blinds.big_blind;
        let knocked_out = state
            .hand_start_chips
            .iter()
            .filter(|(id, _)| {
                table
                    .seat_of(&engine_id(id))
                    .is_some_and(|s| s.chips.is_zero())
            })
            .count();
        let knocked_out = u32::try_from(knocked_out).unwrap_or(u32::MAX);
        for (id, bot) in &mut self.bots {
            let Some(seat) = table.seat_of(&engine_id(id)) else {
                continue;
            };
            let start = state.hand_start_chips.get(id).copied().unwrap_or(0);
            let net = signed(seat.chips.get()) - signed(start);
            bot.mind.observe_showdown(&reveals, &self.history);
            bot.mind
                .observe_hand_end(net, big_blind, if net > 0 { knocked_out } else { 0 });
        }
    }

    /// Looks at the table: decides for the bot to act (once per turn), keeps the clock honest
    /// across a pause, and starts the countdown to the next deal. Cheap when nothing changed.
    pub(super) fn plan(
        &mut self,
        state: &RoomState,
        now: u64,
        human_here: bool,
        timings: &Timings,
    ) {
        if self.bots.is_empty() {
            return;
        }
        let table = &state.game.table;
        let frozen = table.paused || state.ended;
        self.watch_scene(state, now, timings);
        let to_act = table
            .phase
            .is_betting()
            .then_some(table.active)
            .flatten()
            .and_then(|seat| {
                let id = state
                    .players
                    .values()
                    .find(|p| p.seat == Some(seat.get()))?
                    .id
                    .clone();
                state.is_bot(&id).then_some((seat, id))
            });
        match to_act {
            None => self.pending = None,
            Some((seat, id)) => {
                let moment = Moment {
                    hand: table.hand_number,
                    phase: table.phase,
                    seat,
                    seen_actions: self.history.len(),
                };
                if self.pending.as_ref().is_none_or(|p| p.moment != moment) {
                    self.pending = self.decide_for(state, moment, &id, now, timings);
                }
                if let Some(pending) = self.pending.as_mut() {
                    if frozen {
                        if let Some(at) = pending.act_at_ms.take() {
                            pending.left_ms = at.saturating_sub(now);
                        }
                    } else if pending.act_at_ms.is_none() {
                        pending.act_at_ms = Some(now.saturating_add(pending.left_ms));
                    }
                }
            }
        }
        if human_here && state.solo_ready_for_hand() {
            let showdown = if showdown::reveals(table).is_empty() {
                0
            } else {
                timings.bot_showdown_ms
            };
            let wait = timings
                .bot_next_hand_ms
                .saturating_add(showdown)
                .saturating_add(self.runout_extra_ms);
            self.next_hand_at_ms
                .get_or_insert_with(|| now.saturating_add(wait));
        } else {
            self.next_hand_at_ms = None;
        }
    }

    /// Notes when a new hand was dealt or a street appeared, and how many streets arrived at once
    /// (a run-out), which the app shows one after the other.
    fn watch_scene(&mut self, state: &RoomState, now: u64, timings: &Timings) {
        let table = &state.game.table;
        let board_len = table
            .deal
            .as_ref()
            .map_or(0, |deal| deal.visible_board().len());
        if self.seen.0 != table.hand_number {
            self.seen = (table.hand_number, 0);
            self.scene_at_ms = now;
            self.runout_extra_ms = 0;
        }
        if board_len > self.seen.1 {
            let arrived = streets_shown(board_len).saturating_sub(streets_shown(self.seen.1));
            self.runout_extra_ms = self.runout_extra_ms.saturating_add(
                arrived
                    .saturating_sub(1)
                    .saturating_mul(timings.bot_runout_step_ms),
            );
            self.seen.1 = board_len;
            self.scene_at_ms = now;
        }
    }

    fn decide_for(
        &mut self,
        state: &RoomState,
        moment: Moment,
        id: &str,
        now: u64,
        timings: &Timings,
    ) -> Option<Pending> {
        let bot = self.bots.get_mut(id)?;
        let decision = view_for_seat(&state.game.table, moment.seat, &self.history)
            .map(|view| decide(&view, &mut bot.mind, &mut bot.rng))
            .or_else(|| safe_decision(state));
        let Decision { action, think_ms } = decision?;
        #[allow(clippy::cast_precision_loss, reason = "a few thousand milliseconds")]
        let thought = to_ms(think_ms as f32 * timings.bot_think_scale);
        // Never before the cards of this deal or street have been on show for a moment.
        let on_show = self
            .scene_at_ms
            .saturating_add(timings.bot_look_ms)
            .saturating_sub(now);
        let wait = thought.max(on_show);
        Some(Pending {
            moment,
            player_id: id.to_owned(),
            action,
            act_at_ms: Some(now.saturating_add(wait)),
            left_ms: wait,
        })
    }

    /// The earliest moment the driver needs the actor to wake up.
    pub(super) fn next_due_ms(&self) -> Option<u64> {
        let act = self.pending.as_ref().and_then(|p| p.act_at_ms);
        [act, self.next_hand_at_ms].into_iter().flatten().min()
    }

    /// The action to journal now, if a bot's thinking time is up. A given decision is handed out
    /// once.
    pub(super) fn due_act(&mut self, state: &RoomState, now: u64) -> Option<Op> {
        let due = self
            .pending
            .as_ref()
            .and_then(|p| p.act_at_ms)
            .is_some_and(|at| now >= at);
        if !due || state.game.table.paused {
            return None;
        }
        let pending = self.pending.take()?;
        let action_seq = state
            .players
            .get(&pending.player_id)
            .map_or(0, |p| p.next_action_seq);
        Some(Op::Act {
            player_id: pending.player_id,
            action_seq,
            action: pending.action,
            at_ms: now,
        })
    }

    /// The next hand is due to be dealt.
    pub(super) fn hand_due(&self, now: u64) -> bool {
        self.next_hand_at_ms.is_some_and(|at| now >= at)
    }

    /// The deal was attempted (it worked or it did not): count down again from scratch.
    pub(super) fn hand_attempted(&mut self) {
        self.next_hand_at_ms = None;
    }

    /// What to do for the bot on turn if its chosen action was refused: check, else fold.
    pub(super) fn fallback_act(state: &RoomState, now: u64) -> Option<Op> {
        let decision = safe_decision(state)?;
        let (seat, _) = state.game.legal_actions()?;
        let player = state
            .players
            .values()
            .find(|p| p.seat == Some(seat.get()))?;
        state.is_bot(&player.id).then(|| Op::Act {
            player_id: player.id.clone(),
            action_seq: player.next_action_seq,
            action: decision.action,
            at_ms: now,
        })
    }
}

/// Check if it is free, otherwise fold: always legal for whoever is on turn.
fn safe_decision(state: &RoomState) -> Option<Decision> {
    let (_, legal) = state.game.legal_actions()?;
    Some(Decision {
        action: if legal.can_check {
            PlayerAction::Check
        } else {
            PlayerAction::Fold
        },
        think_ms: 0,
    })
}
