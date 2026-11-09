//! What a bot has noticed about the other players, from public information only: who put chips
//! in, who raised, who folded to a bet, and which hands were shown at showdown. A few counters per
//! seat, updated once per action (spec section 4.5). Nothing here can hold a card.

use poker_engine::hand_rank::HandCategory;
use poker_engine::{ActionKind, HandStatus, MAX_SEATS, Phase, SeatIndex};

use crate::personality::Personality;
use crate::range::RangeProfile;
use crate::skill::Skill;
use crate::strength::{push_fraction, top_fraction_threshold};
use crate::view::{BotView, PublicAction, Reveal, SeatView};

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
    /// Times they faced a raise before the flop.
    pub faced_raise: u16,
    /// Of those, times they raised again.
    pub three_bet: u16,
}

/// Counts at or above this stop growing, so a very long game cannot overflow a counter.
const CAP: u16 = 60_000;

/// Once a player has been seen in this many hands every counter is halved, so the notes follow
/// what they do now: a habit from sixty hands ago counts for half, one from a hundred and
/// twenty for a quarter.
const WINDOW: u16 = 80;

/// What a typical player does before there is anything to go on.
const PRIOR_PFR: f32 = 0.14;
const PRIOR_VPIP: f32 = 0.30;
const PRIOR_BLUFF: f32 = 0.18;

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

    /// The smoothed share of hands in which they raise before the flop.
    #[must_use]
    pub fn pfr_rate(&self) -> f32 {
        smoothed(self.pfr, self.hands, PRIOR_PFR, 8.0)
    }

    /// The smoothed share of raises they face that they raise again.
    #[must_use]
    pub fn three_bet_rate(&self) -> f32 {
        smoothed(self.three_bet, self.faced_raise, 0.10, 6.0)
    }

    /// Every counter halved (the notes forget slowly).
    fn halve(&mut self) {
        for counter in [
            &mut self.hands,
            &mut self.vpip,
            &mut self.pfr,
            &mut self.post_bets,
            &mut self.post_calls,
            &mut self.faced_bet,
            &mut self.folded_to_bet,
            &mut self.showdowns,
            &mut self.weak_showdowns,
            &mut self.faced_raise,
            &mut self.three_bet,
        ] {
            *counter /= 2;
        }
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
                if stats.hands > WINDOW {
                    stats.halve();
                }
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
                if was_facing {
                    bump(&mut stats.faced_raise);
                    if aggressive {
                        bump(&mut stats.three_bet);
                    }
                }
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
                // A bet that turns out to be nothing, or a low pair, was a bluff or a weak bet;
                // a pair with a high card in hand is most often a value bet.
                let top_card = reveal
                    .hole
                    .iter()
                    .map(|c| c.rank.value())
                    .max()
                    .unwrap_or(2);
                let weak = match reveal.category {
                    HandCategory::HighCard => true,
                    HandCategory::Pair => top_card < 10,
                    _ => false,
                };
                if was_aggressive && weak {
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
        let vpip = rivals
            .iter()
            .map(|s| self.stats(*s).vpip_rate())
            .sum::<f32>()
            / count;
        // A bluff works only if everybody folds, so one caller spoils it: the geometric mean of
        // each rival's fold rate against a typical table (a single caller drags it below one).
        let everyone_folds: f32 = rivals
            .iter()
            .map(|s| self.stats(*s).fold_to_bet() / 0.45)
            .product::<f32>()
            .powf(1.0 / count);
        let bluff_boost = everyone_folds.powf(trust * 1.2).clamp(0.3, 2.5);
        // Against loose callers a wider range of hands makes money; against a table of tight
        // players it does not.
        let strength_shift = ((vpip - 0.30) * 0.20).clamp(-0.03, 0.04) * trust;
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
            if view.phase == Phase::PreFlop {
                // A raise from a player who rarely raises is a strong hand; from one who raises
                // all the time it is not.
                return (trust * 0.5 * (PRIOR_PFR - stats.pfr_rate())).clamp(-0.06, 0.06);
            }
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

    /// A range for each rival still in the hand, in seat order: how wide a hand they play from
    /// the way they entered the pot (a limp, a call, a raise, a re-raise), narrowed by every street
    /// they bet or called on, and shaped by what the notes say about them. The level decides how
    /// much of the notes is believed (Easy not at all, Normal half once it has seen enough hands,
    /// Hard fully).
    #[must_use]
    pub fn profiles(&self, view: &BotView, skill: Skill) -> Vec<RangeProfile> {
        self.profiles_for(view, skill, |_| true)
    }

    /// Like [`Notes::profiles`] for the rivals still in the hand that pass `include`.
    #[must_use]
    pub fn profiles_for(
        &self,
        view: &BotView,
        skill: Skill,
        include: impl Fn(&SeatView) -> bool,
    ) -> Vec<RangeProfile> {
        let in_hand = |s: &&SeatView| {
            s.index != view.me && matches!(s.status, HandStatus::Live | HandStatus::AllIn)
        };
        let live = view.seats.iter().filter(in_hand).count();
        view.seats
            .iter()
            .filter(in_hand)
            .filter(|s| include(s))
            .map(|rival| self.profile_for(rival, view, skill, live))
            .collect()
    }

    fn profile_for(
        &self,
        rival: &SeatView,
        view: &BotView,
        skill: Skill,
        live: usize,
    ) -> RangeProfile {
        if skill.samples() == 0 {
            return RangeProfile::ANY;
        }
        let stats = self.stats(rival.index);
        let gain = if u32::from(stats.hands) >= skill.read_threshold() {
            skill.read_gain()
        } else {
            0.0
        };
        let blend = |prior: f32, seen: f32| prior + gain * (seen - prior);

        // How they came into the pot.
        let mut raises = 0_u8;
        let mut level = 0_u8;
        for action in view.history.iter().filter(|a| a.street == Phase::PreFlop) {
            let aggressive = matches!(action.kind, ActionKind::Bet | ActionKind::Raise);
            if action.seat == rival.index {
                if aggressive {
                    level = level.max(if raises >= 1 { 3 } else { 2 });
                } else if action.kind == ActionKind::Call && raises >= 1 {
                    level = level.max(1);
                }
            }
            if aggressive {
                raises = raises.saturating_add(1);
            }
        }
        let fraction = match level {
            0 => None,
            1 => Some(blend(PRIOR_VPIP, stats.vpip_rate()).clamp(0.10, 0.75)),
            2 => Some(blend(PRIOR_PFR, stats.pfr_rate()).clamp(0.04, 0.50)),
            _ => Some((0.5 * blend(0.10, stats.three_bet_rate()) + 0.02).clamp(0.03, 0.25)),
        };
        // Short stacks shove and raise far wider than the tight ranges above.
        let big = view.blinds.big_blind.get().max(1);
        let stack = rival.chips.get() + rival.hand_contrib.get();
        #[allow(clippy::cast_precision_loss, reason = "chip counts are small")]
        let stack_bb = stack as f32 / big as f32;
        #[allow(clippy::cast_precision_loss, reason = "at most nine rivals")]
        let fraction = fraction.map(|f| {
            if level >= 2 && stack_bb <= 12.0 {
                f.max(push_fraction(stack_bb, 0.5, live))
            } else {
                f
            }
        });

        // What they did after the flop.
        let mut aggressive_streets = 0_u8;
        let mut called_bets = 0_u8;
        for street in [Phase::Flop, Phase::Turn, Phase::River] {
            let mine = |kinds: &[ActionKind]| {
                view.history
                    .iter()
                    .any(|a| a.seat == rival.index && a.street == street && kinds.contains(&a.kind))
            };
            if mine(&[ActionKind::Bet, ActionKind::Raise]) {
                aggressive_streets += 1;
            }
            if mine(&[ActionKind::Call]) {
                called_bets += 1;
            }
        }
        let seen_bluff = (0.08 + 0.5 * stats.bluff_rate() + 0.35 * (stats.aggression() - 0.35))
            .clamp(0.05, 0.65);
        RangeProfile {
            pre_min: fraction.map_or(0.0, top_fraction_threshold),
            pre_soft: if skill == Skill::Hard { 0.05 } else { 0.07 },
            aggressive_streets,
            called_bets,
            bluff: blend(PRIOR_BLUFF, seen_bluff),
        }
    }
}
