//! Solo games (ADR-018): seating the computer players, and the rules of a freeze-out where
//! nobody buys back in. Everything here is a pure function of [`RoomState`]; the decisions of
//! the computer players themselves live in `bots.rs`, outside the persisted state.

use poker_bots::names::pick_names;
use poker_bots::personality::pick_archetypes;
use poker_bots::{Archetype, BotRng};
use poker_engine::{Command, MAX_SEATS, Phase};

use super::state::{BotProfile, FinishEntry, Op, Outcome, RoomError, RoomState, engine_id};
use crate::protocol::{ErrorCode, Role};

type Done = Result<(), RoomError>;

/// How many rivals a table of `bots` computer players has (spec 10.3).
fn rival_count(bots: usize) -> usize {
    match bots {
        0..=2 => 0,
        3..=5 => 1,
        _ => 2,
    }
}

/// Seat of the `k`-th of `total` players, spread over the ten seats; the human (k = 0) is seat 0.
fn spread_seat(k: usize, total: usize) -> u8 {
    let seat = k * usize::from(MAX_SEATS) / total.max(1);
    u8::try_from(seat).unwrap_or(MAX_SEATS - 1)
}

impl RoomState {
    /// Whether this id is a computer player.
    #[must_use]
    pub fn is_bot(&self, id: &str) -> bool {
        self.bots.contains_key(id)
    }

    /// Whether this is a single-player game.
    #[must_use]
    pub fn is_solo(&self) -> bool {
        self.config.solo.is_some()
    }

    /// Seats the computer players of a new solo game. `seed` is the only randomness: the same
    /// seed always gives the same table. A room that is not solo is left alone.
    ///
    /// # Errors
    /// A [`RoomError`] if a seat cannot be taken (it should never happen on a fresh room).
    pub fn seat_bots(&mut self, seed: u64) -> Done {
        let Some(solo) = self.config.solo else {
            return Ok(());
        };
        let count = usize::from(solo.bots);
        let mut rng = BotRng::from_seed(seed);
        let archetypes = pick_archetypes(count, &mut rng);
        let human = self
            .players
            .get(&self.host_id)
            .map(|p| p.name.clone())
            .unwrap_or_default();
        let names = pick_names(count, &[human.as_str()], &mut rng);
        let rivals = rival_count(count);
        // Rivals are the most distinctive styles at the table, or else simply the first ones.
        let mut order: Vec<usize> = (0..archetypes.len()).collect();
        order.sort_by_key(|i| {
            archetypes.get(*i).map_or(1, |a| {
                u8::from(!matches!(a, Archetype::Lag | Archetype::NitTrapper))
            })
        });
        let rival_indexes: Vec<usize> = order.into_iter().take(rivals).collect();
        for (i, (archetype, name)) in archetypes.into_iter().zip(names).enumerate() {
            let id = self.peek_id(false);
            self.seat_player(
                &id,
                name,
                Role::Player,
                Some(spread_seat(i + 1, count + 1)),
                String::new(),
            )?;
            self.reserve_id(&id);
            self.bots.insert(
                id,
                BotProfile {
                    archetype,
                    skill: solo.skill,
                    rival: rival_indexes.contains(&i),
                    seed: rng.next_u64(),
                },
            );
        }
        Ok(())
    }

    /// Everyone but the human has gone out, or the human has: nothing is left to play.
    #[must_use]
    pub fn solo_over(&self) -> bool {
        self.is_solo()
            && self
                .finish_order
                .iter()
                .any(|entry| entry.player_id == self.host_id)
    }

    fn between_hands(&self) -> bool {
        matches!(self.game.table.phase, Phase::Lobby | Phase::NextHandPrep)
    }

    fn funded(&self) -> usize {
        self.game
            .table
            .seats
            .iter()
            .filter(|s| !s.chips.is_zero())
            .count()
    }

    fn finished(&self, id: &str) -> bool {
        self.finish_order.iter().any(|entry| entry.player_id == id)
    }

    /// Ids that went out in the hand just played and have no place yet.
    fn newly_busted(&self) -> Vec<(String, u64)> {
        let mut busted: Vec<(String, u64)> = self
            .game
            .table
            .seats
            .iter()
            .filter(|s| s.chips.is_zero())
            .map(|s| s.player_id.to_string())
            .filter(|id| !self.finished(id))
            .filter_map(|id| {
                let start = self.hand_start_chips.get(&id).copied().unwrap_or(0);
                (start > 0).then_some((id, start))
            })
            .collect();
        // The smaller stack at the start of the hand finishes lower; ties fall back to the id so
        // the order is always the same.
        busted.sort_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)));
        busted
    }

    /// A solo hand is over and somebody has to be ranked, or the winner named.
    #[must_use]
    pub fn needs_solo_sweep(&self) -> bool {
        self.is_solo()
            && !self.ended
            && !self.solo_over()
            && self.between_hands()
            && !self.hand_start_chips.is_empty()
            && (!self.newly_busted().is_empty() || self.funded() <= 1)
    }

    /// The next hand should be dealt: solo, nobody ranked or pending, two players with chips.
    #[must_use]
    pub fn solo_ready_for_hand(&self) -> bool {
        self.is_solo()
            && !self.ended
            && !self.game.table.paused
            && self.between_hands()
            && !self.solo_over()
            && !self.needs_solo_sweep()
            && self.funded() >= 2
    }

    /// The journaled op that ranks knocked-out players, if one is due.
    #[must_use]
    pub fn solo_sweep_op(&self, at_ms: u64) -> Option<Op> {
        self.needs_solo_sweep().then_some(Op::SoloSweep { at_ms })
    }

    /// Records each funded player's stack as the hand is dealt.
    pub(super) fn note_hand_start(&mut self) {
        if !self.is_solo() {
            return;
        }
        self.hand_start_chips = self
            .game
            .table
            .seats
            .iter()
            .filter(|s| !s.chips.is_zero())
            .map(|s| (s.player_id.to_string(), s.chips.get()))
            .collect();
    }

    pub(super) fn op_solo_sweep(&mut self, at_ms: u64, out: &mut Outcome) -> Done {
        if !self.needs_solo_sweep() {
            return Err(RoomError::new(
                ErrorCode::IllegalState,
                "no one is waiting to be ranked",
            ));
        }
        let alive = self.hand_start_chips.len();
        let busted = self.newly_busted();
        for (i, (id, _)) in busted.iter().enumerate() {
            let place = u8::try_from(alive.saturating_sub(i)).unwrap_or(u8::MAX);
            let name = self
                .players
                .get(id)
                .map(|p| p.name.clone())
                .unwrap_or_default();
            self.finish_order.push(FinishEntry {
                player_id: id.clone(),
                name,
                place,
            });
        }
        for (id, _) in &busted {
            // The human keeps the seat (their table stays on screen behind the result); a
            // computer player simply leaves.
            if self.is_bot(id) {
                self.engine_step(
                    Command::RemovePlayer {
                        player_id: engine_id(id),
                    },
                    at_ms,
                    out,
                )?;
            }
        }
        let standing: Vec<String> = self
            .game
            .table
            .seats
            .iter()
            .filter(|s| !s.chips.is_zero())
            .map(|s| s.player_id.to_string())
            .collect();
        if let [winner] = standing.as_slice()
            && !self.finished(winner)
        {
            let name = self
                .players
                .get(winner)
                .map(|p| p.name.clone())
                .unwrap_or_default();
            self.finish_order.push(FinishEntry {
                player_id: winner.clone(),
                name,
                place: 1,
            });
        }
        out.changed = true;
        self.finish(at_ms, out);
        Ok(())
    }
}
