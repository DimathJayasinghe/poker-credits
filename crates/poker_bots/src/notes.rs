//! What a bot has noticed about the other players, from public information only: who put chips
//! in, who raised, who folded to a bet, and which hands were shown at showdown. A few counters per
//! seat, updated once per action (spec section 4.5). Nothing here can hold a card.

use poker_engine::hand_rank::HandCategory;
use poker_engine::{ActionKind, HandStatus, MAX_SEATS, Phase, SeatIndex};

use crate::personality::Personality;
use crate::skill::Skill;
use crate::view::{BotView, PublicAction, Reveal};

/// How the notes bend one decision.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Reads {
    /// Added to the bot's strength estimate (positive: bet and call more).
    pub strength_shift: f32,
    /// Multiplies the bot's bluff frequency (1.0 = unchanged).
    pub bluff_boost: f32,
    /// Added to the equity a call needs (positive: fold more).
    pub caution: f32,
}

impl Reads {
    /// No read: play the personality.
    pub const NEUTRAL: Reads = Reads {
        strength_shift: 0.0,
        bluff_boost: 1.0,
        caution: 0.0,
    };
}

/// Counters about one opponent. Plain small integers: there is no field that could hold a card.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct OppStats {
    /// Hands this opponent was dealt into.
    pub hands: u16,
    /// Hands in which they voluntarily put chips in preflop.
    pub vpip: u16,
    /// Hands in which they raised preflop.
    pub pfr: u16,
    /// Postflop bets and raises.
    pub post_bets: u16,
    /// Postflop calls.
    pub post_calls: u16,
    /// Times they faced a postflop bet.
    pub faced_bet: u16,
    /// Times they folded to a postflop bet.
    pub folded_to_bet: u16,
    /// Showdowns they reached with their cards shown.
    pub showdowns: u16,
    /// Of those, hands that were weak after they had bet or raised.
    pub weak_showdowns: u16,
}

/// Counts at or above this stop growing, so a very long game cannot overflow a counter.
const CAP: u16 = 60_000;

fn bump(counter: &mut u16) {
    *counter = counter.saturating_add(1).min(CAP);
}

/// A rate pulled toward `prior` when there are few observations (`weight` pseudo-observations).
fn smoothed(hits: u16, total: u16, prior: f32, weight: f32) -> f32 {
    (f32::from(hits) + prior * weight) / (f32::from(total) + weight)
}

/// Smoothed rates, pulled toward a typical player until there is enough to go on.
impl OppStats {
    /// The smoothed `fold_to_bet` rate.
    #[must_use]
    pub fn fold_to_bet(&self) -> f32 {
        smoothed(self.folded_to_bet, self.faced_bet, 0.45, 8.0)
    }

    /// The smoothed `aggression` rate.
    #[must_use]
    pub fn aggression(&self) -> f32 {
        smoothed(
            self.post_bets,
            self.post_bets.saturating_add(self.post_calls),
            0.35,
            8.0,
        )
    }

    /// The smoothed `vpip_rate` rate.
    #[must_use]
    pub fn vpip_rate(&self) -> f32 {
        smoothed(self.vpip, self.hands, 0.30, 8.0)
    }

    /// The smoothed `bluff_rate` rate.
    #[must_use]
    pub fn bluff_rate(&self) -> f32 {
        smoothed(self.weak_showdowns, self.showdowns, 0.20, 4.0)
    }
}

/// One bot's private notes on every seat.
#[derive(Clone, Debug)]
pub struct Notes {
    opp: [OppStats; MAX_SEATS as usize],
    street: Option<Phase>,
    facing_bet: bool,
    voluntary: [bool; MAX_SEATS as usize],
    raised: [bool; MAX_SEATS as usize],
}

impl Default for Notes {
    fn default() -> Self {
        Notes {
            opp: [OppStats::default(); MAX_SEATS as usize],
            street: None,
            facing_bet: false,
            voluntary: [false; MAX_SEATS as usize],
            raised: [false; MAX_SEATS as usize],
        }
    }
}

impl Notes {
    /// What is known about `seat`.
    #[must_use]
    pub fn stats(&self, seat: SeatIndex) -> OppStats {
        self.opp
            .get(usize::from(seat.get()))
            .copied()
            .unwrap_or_default()
    }

    /// A new hand was dealt to `dealt`: count it and forget this hand's flags.
    pub fn begin_hand(&mut self, dealt: &[SeatIndex]) {
        self.street = None;
        self.facing_bet = false;
        self.voluntary = [false; MAX_SEATS as usize];
        self.raised = [false; MAX_SEATS as usize];
        for seat in dealt {
            if let Some(stats) = self.opp.get_mut(usize::from(seat.get())) {
                bump(&mut stats.hands);
            }
        }
    }

    /// Everybody saw this action. O(1).
    pub fn observe_action(&mut self, action: &PublicAction) {
        let index = usize::from(action.seat.get());
        if self.street != Some(action.street) {
            self.street = Some(action.street);
            self.facing_bet = false;
        }
        let was_facing = self.facing_bet;
        let aggressive = matches!(action.kind, ActionKind::Bet | ActionKind::Raise);
        let voluntary = matches!(
            action.kind,
            ActionKind::Call | ActionKind::Bet | ActionKind::Raise
        );
        let first_vpip = voluntary && self.voluntary.get(index).copied() == Some(false);
        let first_pfr = aggressive && self.raised.get(index).copied() == Some(false);
        if let Some(stats) = self.opp.get_mut(index) {
            if action.street == Phase::PreFlop {
                if first_vpip {
                    bump(&mut stats.vpip);
                }
                if first_pfr {
                    bump(&mut stats.pfr);
                }
            } else {
                if was_facing {
                    bump(&mut stats.faced_bet);
                    if action.kind == ActionKind::Fold {
                        bump(&mut stats.folded_to_bet);
                    }
                }
                if aggressive {
                    bump(&mut stats.post_bets);
                } else if action.kind == ActionKind::Call {
                    bump(&mut stats.post_calls);
                }
            }
        }
        if action.street == Phase::PreFlop {
            if first_vpip && let Some(flag) = self.voluntary.get_mut(index) {
                *flag = true;
            }
            if first_pfr && let Some(flag) = self.raised.get_mut(index) {
                *flag = true;
            }
        }
        if aggressive {
            self.facing_bet = true;
        }
    }

    /// Hands shown at showdown. A shown hand that is weak after the player bet or raised this
    /// hand counts toward their bluff rate.
    pub fn observe_showdown(&mut self, reveals: &[Reveal], history: &[PublicAction]) {
        for reveal in reveals {
            let index = usize::from(reveal.seat.get());
            let was_aggressive = history.iter().any(|a| {
                a.seat == reveal.seat && matches!(a.kind, ActionKind::Bet | ActionKind::Raise)
            });
            if let Some(stats) = self.opp.get_mut(index) {
                bump(&mut stats.showdowns);
                if was_aggressive
                    && matches!(reveal.category, HandCategory::HighCard | HandCategory::Pair)
                {
                    bump(&mut stats.weak_showdowns);
                }
            }
        }
    }

    /// The adjustments for this decision. Neutral until the bot has seen enough hands of the
    /// opponents in the pot, and always neutral for a level that does not read (Easy).
    #[must_use]
    pub fn reads(&self, view: &BotView, skill: Skill, personality: &Personality) -> Reads {
        let trust = skill.read_gain() * personality.read_weight;
        if trust <= 0.0 {
            return Reads::NEUTRAL;
        }
        let known = |seat: SeatIndex| u32::from(self.stats(seat).hands) >= skill.read_threshold();
        let rivals: Vec<SeatIndex> = view
            .seats
            .iter()
            .filter(|s| {
                s.index != view.me && matches!(s.status, HandStatus::Live | HandStatus::AllIn)
            })
            .map(|s| s.index)
            .filter(|seat| known(*seat))
            .collect();
        if rivals.is_empty() {
            return Reads::NEUTRAL;
        }
        #[allow(clippy::cast_precision_loss, reason = "at most nine rivals")]
        let count = rivals.len() as f32;
        let mean = |f: &dyn Fn(&OppStats) -> f32| {
            rivals.iter().map(|s| f(&self.stats(*s))).sum::<f32>() / count
        };
        let fold = mean(&OppStats::fold_to_bet);
        let vpip = mean(&OppStats::vpip_rate);
        let bluff_boost = (1.0 + trust * 3.0 * (fold - 0.45)).clamp(0.3, 2.5);
        let strength_shift = if vpip > 0.5 {
            0.03 * trust
        } else if vpip < 0.18 {
            -0.03 * trust
        } else {
            0.0
        };
        // Facing a bet from someone we know: a bettor who bets often and shows weak hands is
        // called more lightly; one who bets rarely and shows strength is respected.
        let bettor = view
            .history
            .iter()
            .rev()
            .take_while(|a| a.street == view.phase)
            .find(|a| a.seat != view.me && matches!(a.kind, ActionKind::Bet | ActionKind::Raise));
        let caution = bettor.filter(|a| known(a.seat)).map_or(0.0, |a| {
            let stats = self.stats(a.seat);
            // Rarely bets or shows strength when betting: respect it. Bets a lot and has shown
            // weak hands: call it lighter.
            let signal = 0.5 * (0.35 - stats.aggression()) + (0.20 - stats.bluff_rate());
            (trust * 0.2 * signal).clamp(-0.08, 0.08)
        });
        Reads {
            strength_shift,
            bluff_boost,
            caution,
        }
    }
}
