//! The strategy: one function from a seat's view to an action and a thinking time.
//!
//! Every returned action is legal for the view (see [`legalize`]); a bot can never stall a hand.

use std::time::Duration;

use poker_engine::card::Card;
use poker_engine::hand_rank::{HandCategory, best_of};
use poker_engine::{ActionKind, PlayerAction};
use poker_engine::{HandStatus, Phase};

use crate::equity::equity;
use crate::notes::{Notes, Reads};
use crate::observe::num;
use crate::personality::Personality;
use crate::rng::BotRng;
use crate::skill::Skill;
use crate::strength::{preflop_adjust, preflop_strength};
use crate::tuning::{Tuning, idx};
use crate::view::BotView;
use crate::view::{PublicAction, Reveal};

/// Longest a single equity estimate may run by default (spec section 8).
pub const EQUITY_BUDGET: Duration = Duration::from_millis(8);

/// One bot's private state: who it is, how well it plays, its mood and its reads.
#[derive(Clone, Debug)]
pub struct BotMind {
    /// Its style.
    pub personality: Personality,
    /// Its level.
    pub skill: Skill,
    /// Tilt: positive after losses (plays looser and wilder), decays by itself.
    pub mood: f32,
    /// What it has noticed about the others.
    pub notes: Notes,
    /// Time limit for one equity estimate. `None` removes the limit, which makes decisions
    /// exactly repeatable (tests); the default keeps a decision under a few milliseconds.
    pub equity_budget: Option<Duration>,
    /// The numbers behind its judgement; the learned ones unless a test or the trainer says otherwise.
    pub tuning: Tuning,
}

impl BotMind {
    /// A bot with a clear head and no notes.
    #[must_use]
    pub fn new(personality: Personality, skill: Skill) -> BotMind {
        BotMind {
            personality,
            skill,
            mood: 0.0,
            notes: Notes::default(),
            equity_budget: Some(EQUITY_BUDGET),
            tuning: Tuning::LEARNED,
        }
    }
}

impl BotMind {
    /// A new hand was dealt to `dealt` (every seat that got cards).
    pub fn begin_hand(&mut self, dealt: &[poker_engine::SeatIndex]) {
        self.notes.begin_hand(dealt);
    }

    /// Everybody at the table saw this action.
    pub fn observe_action(&mut self, action: &PublicAction) {
        self.notes.observe_action(action);
    }

    /// Hands shown at showdown, with the public betting of the hand.
    pub fn observe_showdown(&mut self, reveals: &[Reveal], history: &[PublicAction]) {
        self.notes.observe_showdown(reveals, history);
    }

    /// The hand is over: update the mood from my result in big blinds and how many players I
    /// knocked out. Tilt builds after big losses, fades every hand, and a knockout calms it.
    pub fn observe_hand_end(
        &mut self,
        my_net: i64,
        big_blind: poker_engine::Chips,
        knockouts: u32,
    ) {
        #[allow(clippy::cast_precision_loss, reason = "a ratio of small chip counts")]
        let in_blinds = my_net as f32 / big_blind.get().max(1) as f32;
        let mut mood = self.mood * 0.85;
        if in_blinds <= -10.0 {
            mood += (-in_blinds / 60.0).min(0.6);
        }
        #[allow(clippy::cast_precision_loss, reason = "at most nine knockouts")]
        let calm = 0.3 * knockouts as f32;
        self.mood = (mood - calm).clamp(0.0, 1.0);
    }
}

/// What the bot does and how long it takes to decide.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Decision {
    /// The action, always legal for the view it was made from.
    pub action: PlayerAction,
    /// Milliseconds to wait before acting, so it feels like a person thinking.
    pub think_ms: u32,
}

/// Decides what to do. Reads only `view`; randomness comes from `rng`.
pub fn decide(view: &BotView, mind: &mut BotMind, rng: &mut BotRng) -> Decision {
    let (wanted, closeness) = choose(view, mind, rng);
    let wanted = mistake(wanted, view, mind, rng);
    let action = legalize(wanted, view);
    // Timing has its own generator, seeded by exactly one draw, so how long a bot takes can never
    // change which hands it plays (the number of draws timing needs differs by situation).
    let mut timing = BotRng::from_seed(rng.next_u64());
    Decision {
        action,
        think_ms: think_time(view, action, closeness, &mind.personality, &mut timing),
    }
}

fn to_chips(value: f32) -> u64 {
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "clamped to a non-negative chip count"
    )]
    {
        value.max(0.0) as u64
    }
}

/// 0.0 for the first to act after the button, 1.0 for the button.
fn late_position(view: &BotView) -> f32 {
    let live: Vec<u8> = view
        .seats
        .iter()
        .filter(|s| !s.sitting_out && matches!(s.status, HandStatus::Live | HandStatus::AllIn))
        .map(|s| s.index.get())
        .collect();
    if live.len() < 2 {
        return 0.5;
    }
    let button = view.button.map_or(0, poker_engine::SeatIndex::get);
    let order = |seat: u8| (i16::from(seat) - i16::from(button) - 1).rem_euclid(10);
    let mine = order(view.me.get());
    let before = live.iter().filter(|s| order(**s) < mine).count();
    #[allow(clippy::cast_precision_loss, reason = "at most ten seats")]
    {
        before as f32 / (live.len() - 1) as f32
    }
}

fn made_hand_tier(hole: [Card; 2], board: &[Card], opponents: usize) -> f32 {
    let mut cards = hole.to_vec();
    cards.extend_from_slice(board);
    let Ok(rank) = best_of(&cards) else {
        return 0.3;
    };
    let top_board = board.iter().map(|c| c.rank).max();
    let base: f32 = match rank.category() {
        HandCategory::HighCard => 0.24,
        HandCategory::Pair => {
            let paired_with_hole = hole.iter().any(|h| board.iter().any(|b| b.rank == h.rank))
                || hole[0].rank == hole[1].rank;
            let high = top_board.is_some_and(|top| hole.iter().any(|h| h.rank >= top));
            if paired_with_hole && high {
                0.68
            } else if paired_with_hole {
                0.52
            } else {
                0.30
            }
        }
        HandCategory::TwoPair => 0.72,
        HandCategory::ThreeOfAKind => 0.80,
        HandCategory::Straight => 0.86,
        HandCategory::Flush => 0.90,
        HandCategory::FullHouse => 0.95,
        HandCategory::FourOfAKind | HandCategory::StraightFlush => 0.99,
    };
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let extra = opponents.saturating_sub(1) as f32;
    base.powf(1.0 + 0.12 * extra)
}

/// Raise-to amount for the situation, as an action (an all-in when it reaches the stack).
fn sized_raise(
    view: &BotView,
    mind: &BotMind,
    rng: &mut BotRng,
    preflop: bool,
    scale: f32,
) -> PlayerAction {
    let p = &mind.personality;
    let scale = scale * mind.tuning.at(idx::BET_SIZE);
    let my_bet = view.my_seat().map_or(0.0, |s| num(s.street_bet));
    let current = my_bet + num(view.to_call);
    let big = num(view.blinds.big_blind).max(1.0);
    let wobble = rng.jitter(1.0, 0.15);
    let target = if preflop {
        if num(view.to_call) > big {
            current * (2.4 + 0.8 * p.size_habit) * wobble
        } else {
            current.max(big) + big * (1.5 + 1.5 * p.size_habit) * wobble * scale
        }
    } else {
        current + (num(view.pot_total) + num(view.to_call)) * p.size_habit * scale * wobble
    };
    let unit = num(view.blinds.small_blind).max(1.0);
    let rounded = (target / unit).round() * unit;
    let min = view.legal.min_raise_to.get();
    let max = view.legal.max_raise_to.get();
    let to = to_chips(rounded).clamp(min, max.max(min));
    // Committing most of the stack anyway: just shove.
    if to >= max
        || num(poker_engine::Chips::clamped(to)) >= 0.7 * num(poker_engine::Chips::clamped(max))
    {
        PlayerAction::AllIn
    } else {
        PlayerAction::Raise {
            to_amount: poker_engine::Chips::clamped(to),
        }
    }
}

/// The wanted action and how close the call was (0 clear, 1 agonising).
fn choose(view: &BotView, mind: &BotMind, rng: &mut BotRng) -> (PlayerAction, f32) {
    let skill = mind.skill;
    let p = mind.personality;
    let opponents = view.opponents_in_hand().max(1);
    let reads = mind.notes.reads(view, skill, &p);
    let noise = rng.jitter(0.0, skill.noise());
    let tilt = mind.mood * 0.10 * p.tilt;
    if view.board.is_empty() {
        preflop(view, mind, &p, reads, noise + tilt, opponents, rng)
    } else {
        postflop(view, mind, &p, reads, noise + tilt * 0.5, opponents, rng)
    }
}

fn pot_odds(view: &BotView) -> f32 {
    let owed = num(view.to_call);
    if owed <= 0.0 {
        0.0
    } else {
        owed / (num(view.pot_total) + owed).max(1.0)
    }
}

fn preflop(
    view: &BotView,
    mind: &BotMind,
    p: &Personality,
    reads: Reads,
    shift: f32,
    opponents: usize,
    rng: &mut BotRng,
) -> (PlayerAction, f32) {
    let t = &mind.tuning;
    let bluff_boost = reads.bluff_boost * t.at(idx::BLUFF_SCALE);
    let s = preflop_adjust(preflop_strength(view.hole), late_position(view), opponents)
        + shift
        + reads.strength_shift;
    let play = t.at(idx::PRE_PLAY) - t.at(idx::PRE_SLOPE) * p.looseness;
    let big = num(view.blinds.big_blind).max(1.0);
    let owed = num(view.to_call);
    let stack = num(view.my_chips());
    let facing_raise = owed > big * 1.01;
    let closeness = 1.0 - ((s - play).abs() * 4.0).min(1.0);
    let can_check = view.legal.can_check;
    let free = if can_check {
        PlayerAction::Check
    } else {
        PlayerAction::Fold
    };

    // Short stack: push or fold.
    if stack <= big * 10.0 {
        if s >= play + 0.03 || (owed <= stack * 0.15 && s >= play - 0.1 && !can_check) {
            return (
                if owed >= stack || !view.legal.can_raise {
                    PlayerAction::Call
                } else {
                    PlayerAction::AllIn
                },
                closeness,
            );
        }
        return (free, closeness);
    }
    if !facing_raise {
        if s >= play {
            return if rng.chance(
                t.at(idx::PRE_RAISE) + (1.0 - t.at(idx::PRE_RAISE)) * p.aggression * p.aggression,
            ) {
                (sized_raise(view, mind, rng, true, 1.0), closeness)
            } else if view.legal.can_call {
                (PlayerAction::Call, closeness)
            } else {
                (PlayerAction::Check, closeness)
            };
        }
        if can_check {
            if rng.chance(p.bluff * 0.25 * bluff_boost) {
                return (sized_raise(view, mind, rng, true, 0.8), closeness);
            }
            return (PlayerAction::Check, closeness);
        }
        if s >= play - 0.08 && rng.chance(p.looseness * 0.6) {
            return (PlayerAction::Call, closeness);
        }
        if late_position(view) > 0.8 && rng.chance(p.bluff * 0.5 * bluff_boost) {
            return (sized_raise(view, mind, rng, true, 1.0), closeness);
        }
        return (PlayerAction::Fold, closeness);
    }
    let heat = pot_odds(view);
    // Chips already in (the big blind, a call before a raise) are not a reason to fold: the
    // price of seeing a flop is what is left to put in.
    let invested = view.my_seat().map_or(0.0, |seat| num(seat.street_bet));
    let committed = invested / (invested + owed).max(1.0);
    let call_floor =
        play + 0.07 + 0.35 * heat * (1.0 - 0.5 * p.looseness) + reads.caution - 0.14 * committed;
    let raise_floor = 0.74 - 0.12 * p.aggression;
    if s >= raise_floor && rng.chance(0.5 + 0.5 * p.aggression) {
        (sized_raise(view, mind, rng, true, 1.0), closeness)
    } else if s >= call_floor {
        (PlayerAction::Call, closeness)
    } else if s >= 0.28 && rng.chance(p.bluff * 0.18 * bluff_boost) {
        (sized_raise(view, mind, rng, true, 1.0), closeness)
    } else {
        (PlayerAction::Fold, closeness)
    }
}

/// A seed that depends only on what the seat can see of the spot (its cards, the board and how
/// many opponents are in), so equity sampling is repeatable.
fn spot_seed(view: &BotView, opponents: usize) -> u64 {
    let mut hash: u64 = 0xCBF2_9CE4_8422_2325;
    let mut mix = |byte: u64| {
        hash ^= byte;
        hash = hash.wrapping_mul(0x0000_0100_0000_01B3);
    };
    for card in view.hole.iter().chain(view.board.iter()) {
        mix(card.rank as u64);
        mix(card.suit as u64 + 16);
    }
    mix(opponents as u64 + 64);
    hash
}

/// I made the last raise before the flop.
fn was_preflop_aggressor(view: &BotView) -> bool {
    view.history
        .iter()
        .rev()
        .find(|a| {
            a.street == Phase::PreFlop && matches!(a.kind, ActionKind::Raise | ActionKind::Bet)
        })
        .is_some_and(|a| a.seat == view.me)
}

fn postflop(
    view: &BotView,
    mind: &BotMind,
    p: &Personality,
    reads: Reads,
    shift: f32,
    opponents: usize,
    rng: &mut BotRng,
) -> (PlayerAction, f32) {
    let skill = mind.skill;
    let t = &mind.tuning;
    let bluff_boost = reads.bluff_boost * t.at(idx::BLUFF_SCALE);
    let raw = if skill.samples() == 0 {
        made_hand_tier(view.hole, &view.board, opponents)
    } else {
        // The estimate is a function of the spot alone: the same cards against the same number
        // of opponents always sample the same deals, so a bot does not flip between a call and a
        // fold because two runs of the same dice disagreed. One draw is still taken from `rng`
        // so the rest of the stream does not depend on whether equity was needed.
        let _ = rng.next_u64();
        let mut sampler = BotRng::from_seed(spot_seed(view, opponents));
        equity(
            view.hole,
            &view.board,
            opponents,
            skill.samples(),
            &mut sampler,
            mind.equity_budget,
        )
    };
    let e = raw + shift + reads.strength_shift;
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let many = (opponents - 1).min(5) as f32;
    let value = (t.at(idx::POST_VALUE) - t.at(idx::POST_MANY) * many - 0.08 * (p.aggression - 0.5))
        .max(0.33);
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let field = opponents as f32;
    let owed = num(view.to_call);
    if owed <= 0.0 {
        let closeness = 1.0 - ((e - value).abs() * 4.0).min(1.0);
        if e >= value {
            if e >= value + 0.18 && rng.chance(p.trap * 0.6) {
                return (PlayerAction::Check, closeness);
            }
            return if rng.chance(0.45 + 0.55 * p.aggression) {
                (sized_raise(view, mind, rng, false, 1.0), closeness)
            } else {
                (PlayerAction::Check, closeness)
            };
        }
        // The initiative: the last player to raise before the flop often bets it whatever it
        // holds, heads-up or against two, which is what keeps a player from only ever folding.
        if view.board.len() == 3
            && opponents <= 2
            && was_preflop_aggressor(view)
            && rng.chance(t.at(idx::CBET) + t.at(idx::CBET_AGGR) * p.aggression)
        {
            return (sized_raise(view, mind, rng, false, 0.6), closeness);
        }
        if e < 0.34 && rng.chance(p.bluff * 0.5 / field * bluff_boost) {
            return (sized_raise(view, mind, rng, false, 0.8), closeness);
        }
        if e >= value - 0.12 && rng.chance(0.2 + 0.4 * p.aggression) {
            return (sized_raise(view, mind, rng, false, 0.55), closeness);
        }
        return (PlayerAction::Check, closeness);
    }
    let odds = pot_odds(view);
    // What is left behind decides how much a call risks: a nearly committed stack should not
    // fold for a small premium, and a deep one can pay for a draw that may get paid later.
    let stack = num(view.my_chips());
    let left_after_call = (stack - owed).max(0.0);
    let pot_now = num(view.pot_total).max(1.0);
    let commit_bonus = if left_after_call < 0.5 * pot_now {
        t.at(idx::POST_COMMIT)
    } else if left_after_call > 3.0 * pot_now && view.board.len() < 5 {
        0.02
    } else {
        0.0
    };
    let margin = t.at(idx::POST_MARGIN) - 0.10 * (p.looseness - 0.5) + reads.caution - commit_bonus;
    let closeness =
        (1.0 - ((e - (odds + margin)).abs() * 4.0).min(1.0) + odds * 0.3).clamp(0.0, 1.0);
    if e >= value + t.at(idx::POST_RAISE_EDGE)
        && rng.chance(0.3 + 0.6 * p.aggression * (1.0 - p.trap))
    {
        (sized_raise(view, mind, rng, false, 1.0), closeness)
    } else if e >= odds + margin {
        (PlayerAction::Call, closeness)
    } else if e < 0.30 && rng.chance(p.bluff * 0.12 * bluff_boost) {
        (sized_raise(view, mind, rng, false, 1.0), closeness)
    } else {
        (PlayerAction::Fold, closeness)
    }
}

/// Typical errors of weaker play, with the level's error rate.
fn mistake(wanted: PlayerAction, view: &BotView, mind: &BotMind, rng: &mut BotRng) -> PlayerAction {
    if !rng.chance(mind.skill.error_rate()) {
        return wanted;
    }
    let stack = num(view.my_chips());
    match wanted {
        PlayerAction::Fold if view.legal.can_call && num(view.to_call) <= stack * 0.25 => {
            PlayerAction::Call
        }
        PlayerAction::Raise { .. } | PlayerAction::AllIn if view.legal.can_call => {
            PlayerAction::Call
        }
        PlayerAction::Raise { .. } | PlayerAction::AllIn => PlayerAction::Check,
        PlayerAction::Call if num(view.to_call) > stack * 0.5 => PlayerAction::Fold,
        other => other,
    }
}

/// Turns any wish into an action the engine accepts for this view.
#[must_use]
pub fn legalize(wanted: PlayerAction, view: &BotView) -> PlayerAction {
    let legal = &view.legal;
    let fallback = if legal.can_check {
        PlayerAction::Check
    } else if legal.can_call {
        PlayerAction::Call
    } else {
        PlayerAction::Fold
    };
    match wanted {
        PlayerAction::Fold | PlayerAction::Check => {
            if legal.can_check {
                PlayerAction::Check
            } else {
                PlayerAction::Fold
            }
        }
        PlayerAction::Call if legal.can_call => PlayerAction::Call,
        PlayerAction::AllIn if legal.can_raise => PlayerAction::AllIn,
        PlayerAction::Raise { to_amount } if legal.can_raise => {
            let to = to_amount
                .get()
                .clamp(legal.min_raise_to.get(), legal.max_raise_to.get());
            if to >= legal.max_raise_to.get() {
                PlayerAction::AllIn
            } else {
                PlayerAction::Raise {
                    to_amount: poker_engine::Chips::clamped(to),
                }
            }
        }
        PlayerAction::Call | PlayerAction::AllIn | PlayerAction::Raise { .. } => fallback,
    }
}

/// The shortest thinking time of any decision, and the longest.
pub const THINK_MIN_MS: u32 = 700;
/// See [`THINK_MIN_MS`].
pub const THINK_MAX_MS: u32 = 11_000;

/// Thinking time, so a bot seems to weigh its spot like a person: a check or an easy fold is
/// quick, a call or a bet takes a moment, a close decision takes longer, and a big bet against
/// it (or an all-in) sometimes makes it tank for several seconds. The river gets a little longer,
/// the bot's own speed shifts everything, and an occasional snap decision breaks the rhythm.
#[must_use]
pub fn think_time(
    view: &BotView,
    action: PlayerAction,
    closeness: f32,
    p: &Personality,
    rng: &mut BotRng,
) -> u32 {
    let closeness = closeness.clamp(0.0, 1.0);
    let owed = num(view.to_call);
    let stack = (num(view.my_chips()) + owed).max(1.0);
    let pressure = (owed / stack).clamp(0.0, 1.0);
    let preflop = view.board.is_empty();
    // The base: what the action itself asks of a person.
    let (low, high) = match action {
        PlayerAction::Fold if preflop && pressure < 0.15 => (700.0, 1_500.0),
        PlayerAction::Fold => (1_400.0, 3_000.0),
        PlayerAction::Check => (900.0, 2_000.0),
        PlayerAction::Call => (1_500.0, 3_200.0),
        PlayerAction::Raise { .. } => (1_800.0, 3_800.0),
        PlayerAction::AllIn => (2_200.0, 4_500.0),
    };
    let mut ms = low + (high - low) * rng.unit();
    // A close decision is a harder one.
    ms += closeness * (1_500.0 + 3_000.0 * rng.unit());
    // A lot of the stack on the line: now and then the bot really thinks it over.
    if pressure >= 0.3 || matches!(action, PlayerAction::AllIn) {
        let weight = 0.30 + 0.30 * pressure;
        if rng.chance(weight) {
            ms += 3_000.0 + 5_000.0 * rng.unit();
        }
    }
    if view.board.len() >= 5 {
        ms *= 1.2;
    }
    // Quick players are quick, slow ones slow (think_speed is 1.0 for the quickest).
    ms *= 0.75 + (1.0 - p.think_speed.clamp(0.0, 1.0)) * 0.6;
    // Sometimes it just acts.
    if rng.chance(0.08) {
        ms *= 0.5;
    }
    to_u32(ms.clamp(700.0, 11_000.0))
}

fn to_u32(value: f32) -> u32 {
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "a small non-negative millisecond count"
    )]
    {
        value.max(0.0) as u32
    }
}

/// True during betting rounds (used by drivers to know a decision is wanted).
#[must_use]
pub fn is_decision_phase(phase: Phase) -> bool {
    phase.is_betting()
}
