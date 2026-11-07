//! Who has no connection, and what that costs them.
//!
//! Connections are not part of [`RoomState`], so this lives next to the actor. It decides when
//! time makes an absence matter and returns the [`Op`] to journal; applying it is the actor's job.
//!
//! Rules (`docs/RESILIENCE_AND_CRASH_HANDLING.md` 4.3): the seat stays reserved; if it is the
//! absent player's turn they get a grace period (counted from the later of the disconnect and
//! the start of the turn) and are then checked or folded for; a seat without any connection for
//! ten minutes is sat out.

use std::collections::BTreeMap;

use poker_engine::Event;

use super::state::{Op, RoomState, engine_id};
use crate::config::Timings;

/// Disconnect times by player id, plus when the current turn began.
#[derive(Debug, Default)]
pub(super) struct Absence {
    since_ms: BTreeMap<String, u64>,
    turn_since_ms: u64,
    solo: bool,
}

impl Absence {
    /// Everybody seated starts out absent: after a restart nobody is connected yet. A solo game
    /// has no absence rules at all: the computer players never leave and the one person playing
    /// is not timed out or sat out, they simply pause (the app does that when it goes away).
    pub(super) fn new(state: &RoomState, now: u64) -> Self {
        if state.is_solo() {
            return Absence {
                solo: true,
                ..Absence::default()
            };
        }
        let since_ms = state
            .players
            .values()
            .filter(|p| p.seat.is_some())
            .map(|p| (p.id.clone(), now))
            .collect();
        Absence {
            since_ms,
            turn_since_ms: now,
            solo: false,
        }
    }

    /// The player lost their last connection.
    pub(super) fn gone(&mut self, id: &str, now: u64) {
        if self.solo {
            return;
        }
        self.since_ms.entry(id.to_owned()).or_insert(now);
    }

    /// The player has a connection again.
    pub(super) fn present(&mut self, id: &str) {
        self.since_ms.remove(id);
    }

    /// Forgets people who left the room.
    pub(super) fn prune(&mut self, state: &RoomState) {
        self.since_ms.retain(|id, _| state.is_seated(id));
    }

    /// A new turn started (or the pause ended): the grace period starts over.
    pub(super) fn note_events(&mut self, events: &[Event], now: u64) {
        let restarts = events.iter().any(|e| {
            matches!(
                e,
                Event::TurnStarted { .. } | Event::UndoApplied | Event::Resumed
            )
        });
        if restarts {
            self.turn_since_ms = now;
        }
    }

    fn grace_due_ms(&self, state: &RoomState, timings: &Timings) -> Option<(String, u64)> {
        let (seat, _) = state.game.legal_actions()?;
        let id = state
            .players
            .values()
            .find(|p| p.seat == Some(seat.get()))?
            .id
            .clone();
        let since = *self.since_ms.get(&id)?;
        Some((
            id,
            since
                .max(self.turn_since_ms)
                .saturating_add(timings.disconnect_grace_ms),
        ))
    }

    fn sit_out_due_ms(
        &self,
        state: &RoomState,
        timings: &Timings,
    ) -> impl Iterator<Item = (&str, u64)> {
        self.since_ms.iter().filter_map(move |(id, since)| {
            let seat = state.game.table.seat_of(&engine_id(id))?;
            (!seat.sitting_out)
                .then(|| (id.as_str(), since.saturating_add(timings.absent_sit_out_ms)))
        })
    }

    /// Earliest time an absence needs action.
    pub(super) fn next_due_ms(&self, state: &RoomState, timings: &Timings) -> Option<u64> {
        let grace = self.grace_due_ms(state, timings).map(|(_, at)| at);
        let sit_out = self.sit_out_due_ms(state, timings).map(|(_, at)| at).min();
        [grace, sit_out].into_iter().flatten().min()
    }

    /// The op to run now, if an absence has run out of patience.
    pub(super) fn due_op(&self, state: &RoomState, timings: &Timings, now: u64) -> Option<Op> {
        if let Some((player_id, at)) = self.grace_due_ms(state, timings)
            && now >= at
        {
            return Some(Op::DisconnectTimeout {
                player_id,
                at_ms: now,
            });
        }
        self.sit_out_due_ms(state, timings)
            .find(|(_, at)| now >= *at)
            .map(|(id, _)| Op::SetSittingOut {
                player_id: id.to_owned(),
                sitting_out: true,
                at_ms: now,
            })
    }
}
