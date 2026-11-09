//! From notes and the public betting to a range for each rival.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_bots::notes::Notes;
use poker_bots::range::RangeProfile;
use poker_bots::{Archetype, BotRng, Personality, PublicAction, Reveal, Skill, view_for_seat};
use poker_engine::hand_rank::HandCategory;
use poker_engine::{ActionKind, Chips, Phase, SeatIndex};
use support::{card, dealt, seat};

fn act(seat_no: SeatIndex, street: Phase, kind: ActionKind) -> PublicAction {
    PublicAction {
        seat: seat_no,
        street,
        kind,
        amount: Chips::ZERO,
    }
}

fn trusting() -> Personality {
    let mut p = Personality::sample(Archetype::Tag, &mut BotRng::from_seed(1));
    p.read_weight = 1.0;
    p
}

/// A flop view with three rivals still in, and their seats (in the order profiles come back).
fn flop_view() -> (poker_bots::BotView, Vec<SeatIndex>) {
    let mut state = dealt(4, 2000, 5);
    while state.table.phase == Phase::PreFlop {
        let active = state.table.active.unwrap();
        let owes = state.table.seat(active).unwrap().street_bet < state.table.current_bet;
        let action = if owes {
            poker_engine::PlayerAction::Call
        } else {
            poker_engine::PlayerAction::Check
        };
        state = poker_engine::apply(
            &state,
            poker_engine::Command::Action {
                player_id: support::pid(usize::from(active.get())),
                action,
            },
        )
        .unwrap()
        .state;
    }
    let active = state.table.active.unwrap();
    let view = view_for_seat(&state.table, active, &[]).unwrap();
    let rivals = view
        .seats
        .iter()
        .filter(|s| s.index != view.me)
        .map(|s| s.index)
        .collect();
    (view, rivals)
}

fn all_seats(n: u8) -> Vec<SeatIndex> {
    (0..n).map(seat).collect()
}

/// `hands` hands in which `who` raises preflop (or just calls) and everybody else folds.
fn feed_preflop(notes: &mut Notes, who: SeatIndex, hands: u32, raise_share: u32) {
    for h in 0..hands {
        notes.begin_hand(&all_seats(4));
        let kind = if h % 100 < raise_share {
            ActionKind::Raise
        } else {
            ActionKind::Fold
        };
        notes.observe_action(&act(who, Phase::PreFlop, kind));
    }
}

#[test]
fn a_profile_follows_each_rivals_line() {
    let (mut view, rivals) = flop_view();
    let [a, b, c] = [rivals[0], rivals[1], rivals[2]];
    view.history = vec![
        act(a, Phase::PreFlop, ActionKind::Raise),
        act(b, Phase::PreFlop, ActionKind::Call),
        act(c, Phase::PreFlop, ActionKind::Call),
        act(a, Phase::Flop, ActionKind::Bet),
        act(b, Phase::Flop, ActionKind::Call),
        act(c, Phase::Flop, ActionKind::Call),
    ];
    let notes = Notes::default();
    let p = notes.profiles(&view, Skill::Hard);
    assert_eq!(p.len(), 3);
    assert!(p[0].pre_min > 0.0 && p[0].aggressive_streets == 1 && p[0].called_bets == 0);
    assert!(p[1].pre_min > 0.0 && p[1].called_bets == 1 && p[1].aggressive_streets == 0);
    assert!(
        p[1].pre_min < p[0].pre_min,
        "calling is a wider range than raising"
    );
}

#[test]
fn a_check_or_a_limp_says_nothing() {
    let (mut view, rivals) = flop_view();
    view.history = rivals
        .iter()
        .map(|s| act(*s, Phase::PreFlop, ActionKind::Call))
        .collect();
    let notes = Notes::default();
    for p in notes.profiles(&view, Skill::Hard) {
        assert_eq!(p.aggressive_streets, 0);
        assert_eq!(p.called_bets, 0);
    }
}

#[test]
fn easy_does_not_narrow_ranges() {
    let (mut view, rivals) = flop_view();
    view.history = vec![act(rivals[0], Phase::PreFlop, ActionKind::Raise)];
    let notes = Notes::default();
    for p in notes.profiles(&view, Skill::Easy) {
        assert!(p.is_any(), "{p:?}");
    }
}

#[test]
fn a_tight_raiser_has_a_narrower_range_than_a_loose_one() {
    let (mut view, rivals) = flop_view();
    let who = rivals[0];
    view.history = vec![act(who, Phase::PreFlop, ActionKind::Raise)];
    let mut tight = Notes::default();
    feed_preflop(&mut tight, who, 60, 5);
    let mut loose = Notes::default();
    feed_preflop(&mut loose, who, 60, 60);
    let fresh = Notes::default();
    let min = |n: &Notes, skill| n.profiles(&view, skill)[0].pre_min;
    assert!(
        min(&tight, Skill::Hard) > min(&fresh, Skill::Hard) + 0.03,
        "a nit's raise is stronger than a stranger's"
    );
    assert!(
        min(&loose, Skill::Hard) < min(&fresh, Skill::Hard) - 0.03,
        "a maniac's raise is weaker than a stranger's"
    );
    // Normal reads slower: the same notes move it, but less.
    let shift_hard = min(&tight, Skill::Hard) - min(&fresh, Skill::Hard);
    let shift_normal = min(&tight, Skill::Normal) - min(&fresh, Skill::Normal);
    assert!(shift_normal < shift_hard);
}

#[test]
fn a_player_who_shows_bluffs_is_given_more_of_them() {
    let (mut view, rivals) = flop_view();
    let who = rivals[0];
    view.history = vec![act(who, Phase::Flop, ActionKind::Bet)];
    let weak = Reveal {
        seat: who,
        hole: [card("7c"), card("2d")],
        category: HandCategory::HighCard,
    };
    let strong = Reveal {
        seat: who,
        hole: [card("Ac"), card("Ad")],
        category: HandCategory::ThreeOfAKind,
    };
    let aggressive = [act(who, Phase::Flop, ActionKind::Bet)];
    let mut bluffer = Notes::default();
    let mut rock = Notes::default();
    for _ in 0..20 {
        bluffer.begin_hand(&all_seats(4));
        bluffer.observe_showdown(&[weak], &aggressive);
        rock.begin_hand(&all_seats(4));
        rock.observe_showdown(&[strong], &aggressive);
    }
    let bluff = |n: &Notes| n.profiles(&view, Skill::Hard)[0].bluff;
    assert!(bluff(&bluffer) > bluff(&Notes::default()) + 0.05);
    assert!(bluff(&rock) < bluff(&Notes::default()) - 0.03);
}

#[test]
fn old_habits_fade() {
    let who = seat(1);
    let mut notes = Notes::default();
    for _ in 0..200 {
        notes.begin_hand(&all_seats(3));
        notes.observe_action(&act(who, Phase::PreFlop, ActionKind::Fold));
    }
    assert!(notes.stats(who).vpip_rate() < 0.1);
    for _ in 0..100 {
        notes.begin_hand(&all_seats(3));
        notes.observe_action(&act(who, Phase::PreFlop, ActionKind::Call));
    }
    let rate = notes.stats(who).vpip_rate();
    assert!(
        rate > 0.55,
        "after 100 loose hands the read follows the new habit: {rate}"
    );
}

#[test]
fn a_tight_raiser_is_respected_before_the_flop() {
    let state = dealt(4, 2000, 5);
    let active = state.table.active.unwrap();
    let mut view = view_for_seat(&state.table, active, &[]).unwrap();
    let raiser = view
        .seats
        .iter()
        .find(|s| s.index != view.me)
        .unwrap()
        .index;
    view.history = vec![act(raiser, Phase::PreFlop, ActionKind::Raise)];
    let mut nit = Notes::default();
    feed_preflop(&mut nit, raiser, 60, 4);
    let mut maniac = Notes::default();
    feed_preflop(&mut maniac, raiser, 60, 60);
    let caution = |n: &Notes| n.reads(&view, Skill::Hard, &trusting()).caution;
    assert!(caution(&nit) > 0.0, "{}", caution(&nit));
    assert!(caution(&maniac) < 0.0, "{}", caution(&maniac));
}

#[test]
fn profiles_are_one_per_live_rival() {
    let (mut view, rivals) = flop_view();
    for s in &mut view.seats {
        if s.index == rivals[0] {
            s.status = poker_engine::HandStatus::Folded;
        }
    }
    let notes = Notes::default();
    assert_eq!(notes.profiles(&view, Skill::Hard).len(), 2);
    let _ = RangeProfile::ANY;
}

#[test]
fn narrow_ranges_stay_inside_the_time_budget() {
    // The worst case for the sampler: three rivals who each raised before the flop and bet the
    // flop, so most random hands are turned down. The estimate has its own time limit; the whole
    // decision must still be quick.
    let (mut view, rivals) = flop_view();
    let mut history: Vec<PublicAction> = rivals
        .iter()
        .map(|s| act(*s, Phase::PreFlop, ActionKind::Raise))
        .collect();
    history.extend(rivals.iter().map(|s| act(*s, Phase::Flop, ActionKind::Bet)));
    view.history = history;
    view.to_call = Chips::clamped(40);
    let mut rng = BotRng::from_seed(3);
    let mut mind =
        poker_bots::BotMind::new(Personality::sample(Archetype::Tag, &mut rng), Skill::Hard);
    let mut times = Vec::new();
    for _ in 0..30 {
        let started = std::time::Instant::now();
        let _ = poker_bots::decide(&view, &mut mind, &mut rng);
        times.push(started.elapsed());
    }
    times.sort();
    let median = times[times.len() / 2];
    let slowest = times[times.len() - 1];
    assert!(median.as_millis() < 20, "median {median:?}");
    assert!(slowest.as_millis() < 60, "slowest {slowest:?}");
}
