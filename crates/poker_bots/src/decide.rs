//! The strategy: one function from a seat's view to an action and a thinking time.
//!
//! Every returned action is legal for the view (see [`legalize`]); a bot can never stall a hand.

use std::time::Duration;

use poker_engine::{ActionKind, PlayerAction};
use poker_engine::{HandStatus, Phase};

use crate::equity::equity_against;
use crate::hand::{StraightDraw, blockers, draws, made_hand_tier, wetness};
use crate::notes::{Notes, Reads};
use crate::observe::num;
use crate::personality::Personality;
use crate::range::RangeProfile;
use crate::rng::BotRng;
use crate::skill::Skill;
use crate::strength::{preflop_adjust, preflop_strength, push_fraction, top_fraction_threshold};
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
            tuning: Tuning::for_skill(skill),
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

/// Why a bot bets: the size of a bet follows the intent for a weaker player (a tell a human can
/// read) and the board for a strong one (it gives nothing away).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Intent {
    Value,
    Cbet,
    Probe,
    Bluff,
}

/// Pot fraction multiplier for a bet.
fn bet_scale(
    skill: Skill,
    intent: Intent,
    preflop: bool,
    board: &[poker_engine::card::Card],
) -> f32 {
    if preflop {
        return if intent == Intent::Bluff { 0.8 } else { 1.0 };
    }
    match (skill, intent) {
        // One size for the board, whatever the hand: wet boards get bigger bets.
        (Skill::Hard, _) => 0.7 + 0.5 * wetness(board),
        (Skill::Normal, Intent::Value) => 1.0,
        (Skill::Normal | Skill::Easy, Intent::Cbet) => 0.6,
        (Skill::Normal, Intent::Probe) => 0.55,
        (Skill::Normal, Intent::Bluff) => 0.8,
        // A beginner's sizes say what it holds: big with a hand, small without.
        (Skill::Easy, Intent::Value) => 1.25,
        (Skill::Easy, Intent::Probe | Intent::Bluff) => 0.5,
    }
}

/// Raise-to amount for the situation, as an action (an all-in when it reaches the stack).
fn sized_raise(
    view: &BotView,
    mind: &BotMind,
    rng: &mut BotRng,
    preflop: bool,
    intent: Intent,
) -> PlayerAction {
    let p = &mind.personality;
    let scale = bet_scale(mind.skill, intent, preflop, &view.board) * mind.tuning.at(idx::BET_SIZE);
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

/// A beginner's habit: it keeps overvaluing or undervaluing its hands by the same amount (fixed for
/// this bot), so a player can learn it. Between -0.05 and +0.05 of equity.
fn easy_bias(p: &Personality) -> f32 {
    let mix = p.size_habit * 7.3 + p.tilt * 3.1 + p.think_speed * 5.7 + p.looseness * 2.3;
    (mix.fract() - 0.5) * 0.10
}

/// How willing a level is to bluff, as a multiplier (beginners hardly ever do).
fn bluff_taste(skill: Skill) -> f32 {
    match skill {
        Skill::Easy => 0.25,
        Skill::Normal | Skill::Hard => 1.0,
    }
}

/// Position as the bot understands it: a beginner does not know the button is worth anything.
fn position(view: &BotView, skill: Skill) -> f32 {
    if skill == Skill::Easy {
        0.5
    } else {
        late_position(view)
    }
}

/// The wanted action and how close the call was (0 clear, 1 agonising).
fn choose(view: &BotView, mind: &BotMind, rng: &mut BotRng) -> (PlayerAction, f32) {
    let skill = mind.skill;
    let p = mind.personality;
    let opponents = view.opponents_in_hand().max(1);
    let reads = mind.notes.reads(view, skill, &p);
    let mut noise = rng.jitter(0.0, skill.noise());
    if skill == Skill::Easy {
        noise += easy_bias(&p);
    }
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

/// Stacks this short (in big blinds) play push or fold.
const SHORT_STACK_BB: f32 = 12.0;

/// Facing a raise that puts a lot of chips at stake: the price against what the raiser holds.
/// Beginners go by the strength of their cards.
fn versus_raise(
    view: &BotView,
    mind: &BotMind,
    rng: &mut BotRng,
    raw: f32,
    shift: f32,
    reads: Reads,
) -> (PlayerAction, f32) {
    let t = &mind.tuning;
    let skill = mind.skill;
    let owed = num(view.to_call);
    let stack = num(view.my_chips());
    let big = num(view.blinds.big_blind).max(1.0);
    let odds = pot_odds(view);
    let all_in_call = owed >= stack || !view.legal.can_raise;
    if skill.samples() == 0 {
        let play = t.at(idx::PRE_PLAY) - t.at(idx::PRE_SLOPE) * mind.personality.looseness;
        let s = raw + shift;
        let closeness = 1.0 - ((s - play).abs() * 4.0).min(1.0);
        if s >= play + 0.03 || (owed <= stack * 0.15 && s >= play - 0.1) {
            let action = if all_in_call {
                PlayerAction::Call
            } else {
                PlayerAction::AllIn
            };
            return (action, closeness);
        }
        return (PlayerAction::Fold, closeness);
    }
    // Only players who put chips in matter: the ones yet to act may still fold.
    let ranges = mind
        .notes
        .profiles_for(view, skill, |seat| seat.hand_contrib.get() > 0);
    let ranges = if ranges.is_empty() {
        vec![RangeProfile::ANY]
    } else {
        ranges
    };
    let _ = rng.next_u64();
    let mut sampler = BotRng::from_seed(spot_seed(view, &ranges));
    let e = equity_against(
        view.hole,
        &[],
        &ranges,
        (skill.samples() / 2).max(60),
        &mut sampler,
        mind.equity_budget,
    ) + shift;
    let margin = if skill == Skill::Hard { 0.02 } else { 0.04 } + reads.caution;
    let closeness = (1.0 - ((e - (odds + margin)).abs() * 5.0).min(1.0)).clamp(0.0, 1.0);
    if e >= odds + margin + 0.14 && !all_in_call && owed < stack * 0.5 {
        let stack_bb = stack / big;
        return if stack_bb <= SHORT_STACK_BB {
            (PlayerAction::AllIn, closeness)
        } else {
            (sized_raise(view, mind, rng, true, Intent::Value), closeness)
        };
    }
    if e >= odds + margin {
        (PlayerAction::Call, closeness)
    } else {
        (PlayerAction::Fold, closeness)
    }
}

/// Push or fold: with a short stack the choice is all the chips or none, by position and the number
/// of players left to act.
fn short_stack(
    view: &BotView,
    mind: &BotMind,
    rng: &mut BotRng,
    raw: f32,
    shift: f32,
    reads: Reads,
    opponents: usize,
) -> (PlayerAction, f32) {
    let skill = mind.skill;
    let big = num(view.blinds.big_blind).max(1.0);
    let stack = num(view.my_chips());
    let owed = num(view.to_call);
    if owed > big * 1.01 {
        return versus_raise(view, mind, rng, raw, shift, reads);
    }
    let late = position(view, skill);
    let width = push_fraction(stack / big, late, opponents);
    let threshold = top_fraction_threshold(width);
    let s = raw + shift;
    let closeness = 1.0 - ((s - threshold).abs() * 5.0).min(1.0);
    if s >= threshold && !(view.legal.can_check && owed <= 0.0) {
        return if view.legal.can_raise {
            (PlayerAction::AllIn, closeness)
        } else {
            (PlayerAction::Call, closeness)
        };
    }
    if view.legal.can_check {
        return (PlayerAction::Check, closeness);
    }
    // A cheap completion of the blind is still worth a look with a playable hand.
    if owed <= stack * 0.1 && s >= threshold - 0.15 {
        return (PlayerAction::Call, closeness);
    }
    (PlayerAction::Fold, closeness)
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
    let bluff_boost = reads.bluff_boost * t.at(idx::BLUFF_SCALE) * bluff_taste(mind.skill);
    let raw = preflop_strength(view.hole);
    let late = position(view, mind.skill);
    let s = preflop_adjust(raw, late, opponents) + shift + reads.strength_shift;
    let play = t.at(idx::PRE_PLAY) - t.at(idx::PRE_SLOPE) * p.looseness;
    let big = num(view.blinds.big_blind).max(1.0);
    let owed = num(view.to_call);
    let stack = num(view.my_chips());
    let facing_raise = owed > big * 1.01;
    let closeness = 1.0 - ((s - play).abs() * 4.0).min(1.0);
    let can_check = view.legal.can_check;

    if stack <= big * SHORT_STACK_BB {
        return short_stack(
            view,
            mind,
            rng,
            raw,
            shift + reads.strength_shift,
            reads,
            opponents,
        );
    }
    // A raise that costs a third of the stack or more: weigh it against what the raiser holds.
    if facing_raise && owed >= stack * 0.3 && owed > big * 3.0 {
        return versus_raise(view, mind, rng, raw, shift + reads.strength_shift, reads);
    }
    if !facing_raise {
        if s >= play {
            return if rng.chance(
                t.at(idx::PRE_RAISE) + (1.0 - t.at(idx::PRE_RAISE)) * p.aggression * p.aggression,
            ) {
                (sized_raise(view, mind, rng, true, Intent::Value), closeness)
            } else if view.legal.can_call {
                (PlayerAction::Call, closeness)
            } else {
                (PlayerAction::Check, closeness)
            };
        }
        if can_check {
            if rng.chance(p.bluff * 0.25 * bluff_boost) {
                return (sized_raise(view, mind, rng, true, Intent::Bluff), closeness);
            }
            return (PlayerAction::Check, closeness);
        }
        if s >= play - 0.08 && rng.chance(p.looseness * 0.6) {
            return (PlayerAction::Call, closeness);
        }
        if late > 0.8 && rng.chance(p.bluff * 0.5 * bluff_boost) {
            return (sized_raise(view, mind, rng, true, Intent::Value), closeness);
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
        (sized_raise(view, mind, rng, true, Intent::Value), closeness)
    } else if s >= call_floor {
        (PlayerAction::Call, closeness)
    } else if s >= 0.28 && rng.chance(p.bluff * 0.18 * bluff_boost) {
        (sized_raise(view, mind, rng, true, Intent::Value), closeness)
    } else {
        (PlayerAction::Fold, closeness)
    }
}

/// A seed that depends only on what the seat can see of the spot (its cards, the board, and who
/// is in with what range), so equity sampling is repeatable.
fn spot_seed(view: &BotView, ranges: &[RangeProfile]) -> u64 {
    let mut hash: u64 = 0xCBF2_9CE4_8422_2325;
    let mut mix = |byte: u64| {
        hash ^= byte;
        hash = hash.wrapping_mul(0x0000_0100_0000_01B3);
    };
    for card in view.hole.iter().chain(view.board.iter()) {
        mix(card.rank as u64);
        mix(card.suit as u64 + 16);
    }
    mix(ranges.len() as u64 + 64);
    for range in ranges {
        mix(u64::from(range.pre_min.to_bits()));
        mix(u64::from(range.bluff.to_bits()));
        mix(u64::from(range.aggressive_streets) + 128);
        mix(u64::from(range.called_bets) + 192);
    }
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

/// What a beginner makes of a draw: it counts the outs as part of its hand.
fn draw_bonus(view: &BotView) -> f32 {
    if view.board.len() >= 5 {
        return 0.0;
    }
    let d = draws(view.hole, &view.board);
    let flush = if d.flush { 0.14 } else { 0.0 };
    let straight = match d.straight {
        StraightDraw::OpenEnded => 0.12,
        StraightDraw::Gutshot => 0.05,
        StraightDraw::None => 0.0,
    };
    flush + straight
}

#[allow(
    clippy::too_many_lines,
    reason = "one decision tree, read top to bottom"
)]
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
    let bluff_boost = reads.bluff_boost * t.at(idx::BLUFF_SCALE) * bluff_taste(skill);
    let my_draws = draws(view.hole, &view.board);
    // Cards that keep a rival from holding the best hand make a better bluff.
    let blocks = if skill == Skill::Hard {
        0.4 + 1.6 * blockers(view.hole, &view.board)
    } else {
        1.0
    };
    let raw = if skill.samples() == 0 {
        made_hand_tier(view.hole, &view.board, opponents) + draw_bonus(view)
    } else {
        // The estimate is a function of the spot alone: the same cards against the same rivals
        // always sample the same deals, so a bot does not flip between a call and a fold because
        // two runs of the same dice disagreed. One draw is still taken from `rng` so the rest of
        // the stream does not depend on whether equity was needed.
        let _ = rng.next_u64();
        let ranges = mind.notes.profiles(view, skill);
        let mut sampler = BotRng::from_seed(spot_seed(view, &ranges));
        equity_against(
            view.hole,
            &view.board,
            &ranges,
            skill.samples(),
            &mut sampler,
            mind.equity_budget,
        )
    };
    // The ranges already carry what the notes say about each rival, so only the bluff boost of
    // the reads is used after the flop.
    let e = raw + shift;
    // In position (+0.5) a bot can bet thinner and call lighter than out of position (-0.5).
    let ip = match skill {
        Skill::Hard => position(view, skill) - 0.5,
        Skill::Normal => 0.5 * (position(view, skill) - 0.5),
        Skill::Easy => 0.0,
    };
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let many = (opponents - 1).min(5) as f32;
    let value = (t.at(idx::POST_VALUE) - t.at(idx::POST_MANY) * many - 0.08 * (p.aggression - 0.5))
        .max(0.33);
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let field = opponents as f32;
    let owed = num(view.to_call);
    let river = view.board.len() >= 5;
    if owed <= 0.0 {
        let closeness = 1.0 - ((e - value).abs() * 4.0).min(1.0);
        // Against rivals who pay with worse hands a thinner value bet is profitable; against
        // rivals who fold, a bet needs more behind it (the reads are neutral until there is
        // enough to go on).
        let e = e + ((1.0 - reads.bluff_boost).clamp(-0.2, 0.5) * 0.10).max(-0.02);
        if e >= value {
            if e >= value + 0.18 && rng.chance(p.trap * 0.6) {
                return (PlayerAction::Check, closeness);
            }
            return if rng.chance(0.45 + 0.55 * p.aggression) {
                (
                    sized_raise(view, mind, rng, false, Intent::Value),
                    closeness,
                )
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
            return (sized_raise(view, mind, rng, false, Intent::Cbet), closeness);
        }
        // Checked to with nothing, against one or two players who fold too often: take it.
        if skill != Skill::Easy && opponents <= 2 && reads.bluff_boost > 1.15 && !river {
            let steal = ((reads.bluff_boost - 1.0) * 0.45).clamp(0.0, 0.6) / field.max(1.0);
            if rng.chance(steal) {
                return (
                    sized_raise(view, mind, rng, false, Intent::Bluff),
                    closeness,
                );
            }
        }
        // A semi-bluff: a hand that can still improve bets for two reasons.
        if skill != Skill::Easy && my_draws.any() && !river {
            let weight = if my_draws.strong() { 1.0 } else { 0.5 };
            let chance =
                (t.at(idx::SEMI_BLUFF) + 0.3 * p.aggression) * weight * bluff_boost.min(1.5);
            if rng.chance(chance) {
                return (
                    sized_raise(view, mind, rng, false, Intent::Bluff),
                    closeness,
                );
            }
        }
        let river_shy = if skill == Skill::Normal && river {
            0.7
        } else {
            1.0
        };
        if e < 0.34 && rng.chance(p.bluff * 0.5 / field * bluff_boost * blocks * river_shy) {
            return (
                sized_raise(view, mind, rng, false, Intent::Bluff),
                closeness,
            );
        }
        let thin = (0.2 + 0.4 * p.aggression + t.at(idx::THIN_IP) * 2.0 * ip).clamp(0.0, 1.0);
        if e >= value - 0.12 && rng.chance(thin) {
            return (
                sized_raise(view, mind, rng, false, Intent::Probe),
                closeness,
            );
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
    // Normal players over-fold to a big river bet: a hole a human can learn to use.
    let river_leak = if skill == Skill::Normal && river {
        0.025
    } else {
        0.0
    };
    let margin = t.at(idx::POST_MARGIN)
        - 0.10 * (p.looseness - 0.5)
        - commit_bonus
        - t.at(idx::POS_MARGIN) * 2.0 * ip
        + river_leak;
    let closeness =
        (1.0 - ((e - (odds + margin)).abs() * 4.0).min(1.0) + odds * 0.3).clamp(0.0, 1.0);
    if e >= value + t.at(idx::POST_RAISE_EDGE)
        && rng.chance(0.3 + 0.6 * p.aggression * (1.0 - p.trap))
    {
        (
            sized_raise(view, mind, rng, false, Intent::Value),
            closeness,
        )
    } else if skill == Skill::Hard
        && my_draws.strong()
        && !river
        && left_after_call > 2.0 * pot_now
        && rng.chance(0.5 * t.at(idx::SEMI_BLUFF) * (0.4 + p.aggression) * bluff_boost.min(1.5))
    {
        // Raising a draw: it wins when they fold and can still win when they call.
        (
            sized_raise(view, mind, rng, false, Intent::Bluff),
            closeness,
        )
    } else if e >= odds + margin {
        (PlayerAction::Call, closeness)
    } else if e < 0.30 && rng.chance(p.bluff * 0.12 * bluff_boost * blocks) {
        (
            sized_raise(view, mind, rng, false, Intent::Bluff),
            closeness,
        )
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
pub const THINK_MIN_MS: u32 = 350;
/// See [`THINK_MIN_MS`].
pub const THINK_MAX_MS: u32 = 10_000;

/// Thinking time, so a bot seems to weigh its spot like a person without making anyone wait: a
/// routine move (an easy fold, a check, a clear call) is quick, a call or a bet takes a moment, a
/// close decision takes longer, and a big bet against it (or an all-in) sometimes makes it tank
/// for a few seconds. Players differ in tempo (the quickest act in a third of the time of the
/// slowest), the same player varies from move to move, and some decisions are snap decisions, so
/// a table has no single rhythm.
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
        PlayerAction::Fold if preflop && pressure < 0.15 => (400.0, 1_100.0),
        PlayerAction::Fold | PlayerAction::Call => (900.0, 2_400.0),
        PlayerAction::Check => (500.0, 1_500.0),
        PlayerAction::Raise { .. } => (1_200.0, 3_000.0),
        PlayerAction::AllIn => (1_800.0, 3_800.0),
    };
    let mut ms = low + (high - low) * rng.unit();
    // A close decision is a harder one.
    ms += closeness * (1_000.0 + 2_500.0 * rng.unit());
    // A routine spot (nothing close, little at stake) is acted on quickly.
    if closeness < 0.3 && pressure < 0.15 {
        ms *= 0.65;
    }
    // A lot of the stack on the line: now and then the bot really thinks it over.
    if (pressure >= 0.3 || matches!(action, PlayerAction::AllIn))
        && rng.chance(0.20 + 0.25 * pressure)
    {
        ms += 2_500.0 + 3_500.0 * rng.unit();
    }
    if view.board.len() >= 5 {
        ms *= 1.15;
    }
    // Tempo: think_speed is 1.0 for the quickest player (x0.45) and 0.0 for the slowest (x1.55).
    ms *= 0.45 + (1.0 - p.think_speed.clamp(0.0, 1.0)) * 1.1;
    // The same player is not the same twice: most moves are a little quicker than the average
    // and a few much slower.
    let u = rng.unit();
    ms *= 0.55 + 1.1 * u * u;
    // Sometimes it just acts.
    if rng.chance(0.12) {
        ms *= 0.45;
    }
    to_u32(ms.clamp(350.0, 10_000.0))
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
