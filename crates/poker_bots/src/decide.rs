//! The strategy: one function from a seat's view to an action and a thinking time.
//!
//! Every returned action is legal for the view (see [`legalize`]); a bot can never stall a hand.

use std::time::Duration;

use poker_engine::PlayerAction;
use poker_engine::card::Card;
use poker_engine::hand_rank::{HandCategory, best_of};
use poker_engine::{HandStatus, Phase};

use crate::equity::equity;
use crate::notes::{Notes, Reads};
use crate::observe::num;
use crate::personality::Personality;
use crate::rng::BotRng;
use crate::skill::Skill;
use crate::strength::{preflop_adjust, preflop_strength};
use crate::view::BotView;

/// Longest a single equity estimate may run (spec section 8).
const EQUITY_BUDGET: Duration = Duration::from_millis(8);

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
        }
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
    Decision {
        action,
        think_ms: think_time(closeness, &mind.personality, rng),
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
        HandCategory::HighCard => 0.22,
        HandCategory::Pair => {
            let paired_with_hole = hole.iter().any(|h| board.iter().any(|b| b.rank == h.rank))
                || hole[0].rank == hole[1].rank;
            let high = top_board.is_some_and(|top| hole.iter().any(|h| h.rank >= top));
            if paired_with_hole && high {
                0.62
            } else if paired_with_hole {
                0.46
            } else {
                0.28
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
    base.powf(1.0 + 0.2 * extra)
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
    let s = preflop_adjust(preflop_strength(view.hole), late_position(view), opponents)
        + shift
        + reads.strength_shift;
    let play = 0.60 - 0.32 * p.looseness;
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
            return if rng.chance(0.35 + 0.65 * p.aggression) {
                (sized_raise(view, mind, rng, true, 1.0), closeness)
            } else if view.legal.can_call {
                (PlayerAction::Call, closeness)
            } else {
                (PlayerAction::Check, closeness)
            };
        }
        if can_check {
            if rng.chance(p.bluff * 0.25 * reads.bluff_boost) {
                return (sized_raise(view, mind, rng, true, 0.8), closeness);
            }
            return (PlayerAction::Check, closeness);
        }
        if s >= play - 0.08 && rng.chance(p.looseness * 0.6) {
            return (PlayerAction::Call, closeness);
        }
        if late_position(view) > 0.8 && rng.chance(p.bluff * 0.5 * reads.bluff_boost) {
            return (sized_raise(view, mind, rng, true, 1.0), closeness);
        }
        return (PlayerAction::Fold, closeness);
    }
    let heat = pot_odds(view);
    let call_floor = play + 0.07 + 0.35 * heat * (1.0 - 0.5 * p.looseness) + reads.caution;
    let raise_floor = 0.74 - 0.12 * p.aggression;
    if s >= raise_floor && rng.chance(0.5 + 0.5 * p.aggression) {
        (sized_raise(view, mind, rng, true, 1.0), closeness)
    } else if s >= call_floor {
        (PlayerAction::Call, closeness)
    } else if s >= 0.28 && rng.chance(p.bluff * 0.18 * reads.bluff_boost) {
        (sized_raise(view, mind, rng, true, 1.0), closeness)
    } else {
        (PlayerAction::Fold, closeness)
    }
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
    let raw = if skill.samples() == 0 {
        made_hand_tier(view.hole, &view.board, opponents)
    } else {
        equity(
            view.hole,
            &view.board,
            opponents,
            skill.samples(),
            rng,
            Some(EQUITY_BUDGET),
        )
    };
    let e = raw + shift + reads.strength_shift;
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let many = (opponents - 1).min(5) as f32;
    let value = (0.60 - 0.045 * many - 0.08 * (p.aggression - 0.5)).max(0.33);
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
        if e < 0.34 && rng.chance(p.bluff * 0.5 / field * reads.bluff_boost) {
            return (sized_raise(view, mind, rng, false, 0.8), closeness);
        }
        if e >= value - 0.12 && rng.chance(0.2 + 0.4 * p.aggression) {
            return (sized_raise(view, mind, rng, false, 0.55), closeness);
        }
        return (PlayerAction::Check, closeness);
    }
    let odds = pot_odds(view);
    let margin = 0.05 - 0.10 * (p.looseness - 0.5) + reads.caution;
    let closeness =
        (1.0 - ((e - (odds + margin)).abs() * 4.0).min(1.0) + odds * 0.3).clamp(0.0, 1.0);
    if e >= value + 0.14 && rng.chance(0.3 + 0.6 * p.aggression * (1.0 - p.trap)) {
        (sized_raise(view, mind, rng, false, 1.0), closeness)
    } else if e >= odds + margin {
        (PlayerAction::Call, closeness)
    } else if e < 0.30 && rng.chance(p.bluff * 0.12 * reads.bluff_boost) {
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

/// Thinking time: quick for clear spots, slow for close ones, scaled by the bot's own speed, with
/// an occasional snap decision.
fn think_time(closeness: f32, p: &Personality, rng: &mut BotRng) -> u32 {
    let factor = 1.5 - p.think_speed;
    if rng.chance(0.10) {
        return to_u32(f32::from(u16::try_from(400 + rng.below(200)).unwrap_or(400)) * factor);
    }
    let clear = 400.0 + f32::from(u16::try_from(rng.below(500)).unwrap_or(0));
    let close = 1200.0 + f32::from(u16::try_from(rng.below(2300)).unwrap_or(0));
    to_u32((clear + (close - clear) * closeness.clamp(0.0, 1.0)) * factor)
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
