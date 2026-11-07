//! Opponent notes, reads and mood.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_bots::notes::{Notes, OppStats, Reads};
use poker_bots::{Archetype, BotMind, BotRng, Personality, PublicAction, Skill, view_for_seat};
use poker_engine::{ActionKind, Chips, Phase};
use support::{dealt, seat};

fn act(seat_no: u8, street: Phase, kind: ActionKind) -> PublicAction {
    PublicAction {
        seat: seat(seat_no),
        street,
        kind,
        amount: Chips::ZERO,
    }
}

/// A personality that trusts reads fully, so tests see the whole effect of a read.
fn trusting() -> Personality {
    let mut p = Personality::sample(Archetype::Tag, &mut BotRng::from_seed(1));
    p.read_weight = 1.0;
    p
}

/// A hand in which `bettor` bets the flop and `folder` folds to it.
fn fold_to_bet_hand(notes: &mut Notes, dealt: &[poker_engine::SeatIndex], bettor: u8, folder: u8) {
    notes.begin_hand(dealt);
    notes.observe_action(&act(bettor, Phase::Flop, ActionKind::Bet));
    notes.observe_action(&act(folder, Phase::Flop, ActionKind::Fold));
}

fn all_seats(n: u8) -> Vec<poker_engine::SeatIndex> {
    (0..n).map(seat).collect()
}

/// A flop view for the seat that acts, with the other three still in.
fn flop_view() -> (poker_bots::BotView, u8) {
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
    (
        view_for_seat(&state.table, active, &[]).unwrap(),
        active.get(),
    )
}

#[test]
fn counters_follow_the_public_betting() {
    let mut n = Notes::default();
    let dealt = all_seats(3);
    n.begin_hand(&dealt);
    n.observe_action(&act(0, Phase::PreFlop, ActionKind::Call));
    n.observe_action(&act(0, Phase::PreFlop, ActionKind::Raise));
    n.observe_action(&act(1, Phase::PreFlop, ActionKind::Fold));
    n.observe_action(&act(0, Phase::Flop, ActionKind::Bet));
    n.observe_action(&act(1, Phase::Flop, ActionKind::Fold));
    n.observe_action(&act(2, Phase::Flop, ActionKind::Call));
    let a = n.stats(seat(0));
    assert_eq!(
        (a.hands, a.vpip, a.pfr, a.post_bets),
        (1, 1, 1, 1),
        "vpip and pfr count once a hand"
    );
    let b = n.stats(seat(1));
    assert_eq!((b.vpip, b.faced_bet, b.folded_to_bet), (0, 1, 1));
    let c = n.stats(seat(2));
    assert_eq!((c.faced_bet, c.folded_to_bet, c.post_calls), (1, 0, 1));
}

#[test]
fn a_new_street_clears_facing_a_bet() {
    let mut n = Notes::default();
    n.begin_hand(&all_seats(2));
    n.observe_action(&act(0, Phase::Flop, ActionKind::Bet));
    n.observe_action(&act(1, Phase::Turn, ActionKind::Check));
    assert_eq!(
        n.stats(seat(1)).faced_bet,
        0,
        "the turn is a new street: nothing to face yet"
    );
}

#[test]
fn counters_never_overflow() {
    let mut n = Notes::default();
    n.begin_hand(&all_seats(2));
    for _ in 0..200_000 {
        n.observe_action(&act(0, Phase::Flop, ActionKind::Bet));
        n.observe_action(&act(1, Phase::Flop, ActionKind::Fold));
    }
    assert!(n.stats(seat(1)).folded_to_bet <= 60_000);
}

#[test]
fn smoothing_resists_one_hand() {
    let mut n = Notes::default();
    fold_to_bet_hand(&mut n, &all_seats(3), 0, 1);
    let s = n.stats(seat(1));
    assert_eq!((s.faced_bet, s.folded_to_bet), (1, 1));
    let rate = s.fold_to_bet();
    assert!(
        (0.45..0.52).contains(&rate),
        "one fold moves the read only a little: {rate}"
    );
    assert!(
        OppStats::default().fold_to_bet() > 0.44 && OppStats::default().fold_to_bet() < 0.46,
        "no data means a typical player"
    );
}

#[test]
fn easy_never_reads() {
    let (view, me) = flop_view();
    let other = (0..4).find(|s| *s != me).unwrap();
    let mut n = Notes::default();
    for _ in 0..80 {
        fold_to_bet_hand(&mut n, &all_seats(4), me, other);
    }
    assert_eq!(n.reads(&view, Skill::Easy, &trusting()), Reads::NEUTRAL);
}

#[test]
fn reads_need_enough_hands() {
    let (view, me) = flop_view();
    let rivals: Vec<u8> = (0..4).filter(|s| *s != me).collect();
    let mut n = Notes::default();
    let dealt = all_seats(4);
    let feed = |n: &mut Notes, hands: u32| {
        for _ in 0..hands {
            // Every rival folds to a bet every hand (one bets, the others fold).
            n.begin_hand(&dealt);
            n.observe_action(&act(me, Phase::Flop, ActionKind::Bet));
            for r in &rivals {
                n.observe_action(&act(*r, Phase::Flop, ActionKind::Fold));
            }
        }
    };
    feed(&mut n, 24);
    assert_eq!(
        n.reads(&view, Skill::Normal, &trusting()),
        Reads::NEUTRAL,
        "Normal needs 25 hands"
    );
    assert_ne!(
        n.reads(&view, Skill::Hard, &trusting()),
        Reads::NEUTRAL,
        "Hard needs only 10"
    );
    feed(&mut n, 1);
    assert_ne!(n.reads(&view, Skill::Normal, &trusting()), Reads::NEUTRAL);
}

#[test]
fn a_bot_bluffs_more_against_folders_than_against_callers() {
    let (view, me) = flop_view();
    let rivals: Vec<u8> = (0..4).filter(|s| *s != me).collect();
    let (mut folders, mut stations) = (Notes::default(), Notes::default());
    for _ in 0..40 {
        folders.begin_hand(&all_seats(4));
        stations.begin_hand(&all_seats(4));
        folders.observe_action(&act(me, Phase::Flop, ActionKind::Bet));
        stations.observe_action(&act(me, Phase::Flop, ActionKind::Bet));
        for r in &rivals {
            folders.observe_action(&act(*r, Phase::Flop, ActionKind::Fold));
            stations.observe_action(&act(*r, Phase::Flop, ActionKind::Call));
        }
    }
    let vs_folders = folders.reads(&view, Skill::Hard, &trusting());
    let vs_stations = stations.reads(&view, Skill::Hard, &trusting());
    assert!(vs_folders.bluff_boost > 1.3, "{vs_folders:?}");
    assert!(vs_stations.bluff_boost < 0.7, "{vs_stations:?}");
    // Normal leans on it less than Hard.
    let normal = folders.reads(&view, Skill::Normal, &trusting());
    assert!(normal.bluff_boost > 1.0 && normal.bluff_boost < vs_folders.bluff_boost);
}

#[test]
fn a_known_bluffer_is_called_lighter_and_a_rock_is_respected() {
    // The bettor is the last aggressor on this street in the view's own history.
    let (mut view, me) = flop_view();
    let bettor = (0..4).find(|s| *s != me).unwrap();
    view.history = vec![act(bettor, view.phase, ActionKind::Bet)];
    let (mut bluffer, mut rock) = (Notes::default(), Notes::default());
    for _ in 0..40 {
        bluffer.begin_hand(&all_seats(4));
        rock.begin_hand(&all_seats(4));
        for _ in 0..3 {
            bluffer.observe_action(&act(bettor, Phase::Flop, ActionKind::Bet));
        }
        bluffer.observe_showdown(
            &[poker_bots::Reveal {
                seat: seat(bettor),
                hole: [support::card("2c"), support::card("7d")],
                category: poker_engine::hand_rank::HandCategory::HighCard,
            }],
            &[act(bettor, Phase::Flop, ActionKind::Bet)],
        );
        rock.observe_action(&act(bettor, Phase::Flop, ActionKind::Call));
        rock.observe_action(&act(bettor, Phase::Turn, ActionKind::Call));
    }
    let light = bluffer.reads(&view, Skill::Hard, &trusting());
    let careful = rock.reads(&view, Skill::Hard, &trusting());
    assert!(light.caution < 0.0, "calls down a bluffer: {light:?}");
    assert!(
        careful.caution > 0.0,
        "a passive player who bets is respected: {careful:?}"
    );
}

#[test]
fn notes_hold_only_counters() {
    // The notes cannot contain a card: the opponent record is nine small integers.
    assert_eq!(
        std::mem::size_of::<OppStats>(),
        9 * std::mem::size_of::<u16>()
    );
}

#[test]
fn mood_builds_after_a_big_loss_decays_and_a_knockout_calms_it() {
    let mut mind = BotMind::new(trusting(), Skill::Normal);
    let bb = Chips::new(20).unwrap();
    mind.observe_hand_end(-100, bb, 0);
    assert!(mind.mood < f32::EPSILON, "a small loss is shrugged off");
    mind.observe_hand_end(-1200, bb, 0);
    let tilted = mind.mood;
    assert!(tilted > 0.3, "{tilted}");
    mind.observe_hand_end(0, bb, 0);
    assert!(mind.mood < tilted, "it fades");
    let before = mind.mood;
    mind.observe_hand_end(500, bb, 1);
    assert!(mind.mood < before, "a knockout calms it");
    for _ in 0..40 {
        mind.observe_hand_end(0, bb, 0);
    }
    assert!(mind.mood < 0.01);
    for _ in 0..40 {
        mind.observe_hand_end(-100_000, bb, 0);
    }
    assert!((0.0..=1.0).contains(&mind.mood));
}
