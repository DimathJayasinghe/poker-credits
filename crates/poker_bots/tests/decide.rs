//! Decisions: always legal, bounded, varied.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::cast_precision_loss
)]

mod support;

use poker_bots::decide::think_time;
use poker_bots::names::{NAMES, pick_names};
use poker_bots::personality::{Archetype, pick_archetypes};
use poker_bots::{BotMind, BotRng, Personality, Skill, decide};
use poker_engine::PlayerAction;
use proptest::prelude::*;
use support::chips;
use support::sim::{Bot, play_hand, table};

fn bots_for(n: usize, skill: Skill, seed: u64) -> Vec<Bot> {
    let mut rng = BotRng::from_seed(seed);
    let kinds = pick_archetypes(n, &mut rng);
    kinds
        .into_iter()
        .enumerate()
        .map(|(i, kind)| Bot {
            mind: BotMind::new(Personality::sample(kind, &mut rng), skill),
            rng: BotRng::from_seed(seed ^ (i as u64 + 1).wrapping_mul(0x9E37_79B9)),
        })
        .collect()
}

fn skill_of(n: u8) -> Skill {
    match n % 3 {
        0 => Skill::Easy,
        1 => Skill::Normal,
        _ => Skill::Hard,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(60))]

    /// Whatever the stacks, blinds, skills and styles, every action is accepted by the engine and
    /// the hands finish with chips conserved.
    #[test]
    fn decide_is_always_legal(
        stacks in proptest::collection::vec(1u64..=3000, 2..=9),
        small in 1u64..=50,
        skill in 0u8..3,
        seed in any::<u64>(),
    ) {
        let n = stacks.len();
        let mut state = table(&stacks, small, small * 2);
        let total: u64 = stacks.iter().sum();
        let mut bots = bots_for(n, skill_of(skill), seed);
        let mut deck_rng = BotRng::from_seed(seed.wrapping_add(1));
        for _ in 0..12 {
            match play_hand(&mut state, &mut bots, &mut deck_rng) {
                Ok(Some(log)) => prop_assert_eq!(log.net.iter().sum::<i64>(), 0),
                Ok(None) => break,
                Err(reason) => prop_assert!(false, "{}", reason),
            }
            prop_assert_eq!(state.table.total_chips(), total);
        }
    }
}

#[test]
fn raise_amounts_stay_within_the_legal_range() {
    // Short stacks and deep stacks, heads up and full ring.
    for (stacks, seed) in [
        (vec![30, 4000], 1_u64),
        (vec![25, 25, 25], 2),
        (vec![500; 9], 3),
        (vec![15, 2000, 60, 800], 4),
    ] {
        let mut state = table(&stacks, 5, 10);
        let mut bots = bots_for(stacks.len(), Skill::Hard, seed);
        let mut deck_rng = BotRng::from_seed(seed);
        for _ in 0..40 {
            let Some(_) = play_hand(&mut state, &mut bots, &mut deck_rng).unwrap() else {
                break;
            };
        }
    }
}

#[test]
fn personality_params_in_range() {
    let mut rng = BotRng::from_seed(8);
    for kind in Archetype::ALL {
        for _ in 0..200 {
            let p = Personality::sample(kind, &mut rng);
            for v in [
                p.looseness,
                p.aggression,
                p.bluff,
                p.trap,
                p.tilt,
                p.think_speed,
                p.read_weight,
            ] {
                assert!((0.0..=1.0).contains(&v), "{kind:?}: {v}");
            }
            assert!((0.3..=1.2).contains(&p.size_habit));
            assert!(p.rival().read_weight >= p.read_weight);
        }
    }
}

#[test]
fn pick_archetypes_distinct_until_six() {
    let mut rng = BotRng::from_seed(3);
    for seed in 0..50 {
        let mut rng2 = BotRng::from_seed(seed);
        let picked = pick_archetypes(6, &mut rng2);
        let mut unique = picked.clone();
        unique.sort_by_key(|a| *a as u8);
        unique.dedup();
        assert_eq!(unique.len(), 6, "{picked:?}");
    }
    assert_eq!(pick_archetypes(9, &mut rng).len(), 9);
    assert!(pick_archetypes(0, &mut rng).is_empty());
}

#[test]
fn names_are_valid_and_distinct() {
    let mut seen = std::collections::HashSet::new();
    for name in NAMES {
        assert!((1..=20).contains(&name.len()));
        assert!(
            name.chars()
                .all(|c| c.is_ascii_alphanumeric() || c == ' ' || c == '_' || c == '-'),
            "{name}"
        );
        assert!(seen.insert(name.to_ascii_lowercase()), "duplicate {name}");
    }
    let mut rng = BotRng::from_seed(1);
    let picked = pick_names(9, &["maya", "LIAM"], &mut rng);
    assert_eq!(picked.len(), 9);
    assert!(
        !picked
            .iter()
            .any(|n| n.eq_ignore_ascii_case("maya") || n.eq_ignore_ascii_case("liam"))
    );
    assert_eq!(
        pick_names(100, &[], &mut rng).len(),
        NAMES.len(),
        "pool runs out, no panic"
    );
}

fn a_view() -> (poker_bots::BotView, Personality) {
    let mut rng = BotRng::from_seed(5);
    let mut p = Personality::sample(Archetype::Tag, &mut rng);
    p.think_speed = 0.5;
    let state = support::dealt(4, 1000, 3);
    let active = state.table.active.unwrap();
    (
        poker_bots::view_for_seat(&state.table, active, &[]).unwrap(),
        p,
    )
}

fn average(
    view: &poker_bots::BotView,
    action: PlayerAction,
    closeness: f32,
    p: &Personality,
) -> f32 {
    let mut rng = BotRng::from_seed(11);
    let times: Vec<u32> = (0..400)
        .map(|_| think_time(view, action, closeness, p, &mut rng))
        .collect();
    times.iter().map(|ms| *ms as f32).sum::<f32>() / times.len() as f32
}

#[test]
fn think_time_ranges() {
    // Every thinking time of every kind of spot sits inside the documented bounds, and a bot
    // is never instant: even a clear fold takes a person's moment.
    let (mut view, p) = a_view();
    let mut rng = BotRng::from_seed(9);
    let actions = [
        PlayerAction::Fold,
        PlayerAction::Check,
        PlayerAction::Call,
        PlayerAction::Raise {
            to_amount: chips(60),
        },
        PlayerAction::AllIn,
    ];
    for owed in [0, 20, 400, 990] {
        view.to_call = chips(owed);
        for action in actions {
            for closeness in [0.0, 0.5, 1.0] {
                for _ in 0..200 {
                    let ms = think_time(&view, action, closeness, &p, &mut rng);
                    assert!((350..=10_000).contains(&ms), "{action:?} {owed} {ms}");
                }
            }
        }
    }
}

#[test]
fn think_time_follows_the_spot() {
    let (mut view, p) = a_view();
    view.to_call = chips(0);
    let check = average(&view, PlayerAction::Check, 0.0, &p);
    let easy_fold = {
        view.to_call = chips(20);
        average(&view, PlayerAction::Fold, 0.0, &p)
    };
    let close_call = average(&view, PlayerAction::Call, 1.0, &p);
    view.to_call = chips(900);
    let all_in = average(&view, PlayerAction::AllIn, 1.0, &p);
    assert!(
        easy_fold < check,
        "an easy preflop fold is the quickest: {easy_fold} {check}"
    );
    assert!(check < close_call, "{check} {close_call}");
    assert!(
        close_call < all_in,
        "a big decision takes the longest: {close_call} {all_in}"
    );
    assert!(check > 500.0 && all_in > 2_500.0, "{check} {all_in}");
}

#[test]
fn a_slow_player_takes_longer_than_a_quick_one() {
    let (view, mut p) = a_view();
    p.think_speed = 1.0;
    let quick = average(&view, PlayerAction::Call, 0.5, &p);
    p.think_speed = 0.0;
    let slow = average(&view, PlayerAction::Call, 0.5, &p);
    assert!(slow > quick * 1.8, "{quick} {slow}");
}

#[test]
fn timing_never_changes_which_hands_are_played() {
    // The decision is made before the timing draws, and timing uses a generator of its own: two
    // runs from the same seed give the same actions, and one timing draw is all the main stream pays.
    let (view, p) = a_view();
    let run = |seed: u64| {
        let mut rng = BotRng::from_seed(seed);
        let mut mind = BotMind::new(p, Skill::Normal);
        let first = decide(&view, &mut mind, &mut rng);
        (first, rng.next_u64())
    };
    assert_eq!(run(77), run(77));
    let (_, after) = run(77);
    let mut check = BotRng::from_seed(77);
    let mut mind = BotMind::new(p, Skill::Normal);
    let _ = decide(&view, &mut mind, &mut check);
    assert_eq!(check.next_u64(), after);
}

#[test]
fn hard_bots_play_a_full_ring_quickly() {
    // A Hard bot's decision on a big board against many opponents stays fast.
    let mut state = table(&[1000; 9], 10, 20);
    let mut bots = bots_for(9, Skill::Hard, 77);
    let mut deck_rng = BotRng::from_seed(78);
    let started = std::time::Instant::now();
    for _ in 0..10 {
        let _ = play_hand(&mut state, &mut bots, &mut deck_rng).unwrap();
    }
    assert!(
        started.elapsed() < std::time::Duration::from_secs(20),
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn legalize_turns_any_wish_into_a_legal_action() {
    use poker_bots::decide::legalize;
    use poker_engine::Chips;
    // First to act preflop owes the blind: can call and raise, cannot check.
    let state = support::dealt(3, 1000, 12);
    let active = state.table.active.unwrap();
    let view = poker_bots::view_for_seat(&state.table, active, &[]).unwrap();
    assert!(view.legal.can_call && !view.legal.can_check);
    assert_eq!(
        legalize(PlayerAction::Check, &view),
        PlayerAction::Fold,
        "cannot check what is owed"
    );
    assert_eq!(legalize(PlayerAction::Call, &view), PlayerAction::Call);
    let below = PlayerAction::Raise {
        to_amount: Chips::clamped(1),
    };
    let PlayerAction::Raise { to_amount } = legalize(below, &view) else {
        panic!("a raise stays a raise")
    };
    assert_eq!(
        to_amount, view.legal.min_raise_to,
        "raises under the minimum are lifted to it"
    );
    let above = PlayerAction::Raise {
        to_amount: Chips::clamped(10_000_000),
    };
    assert_eq!(
        legalize(above, &view),
        PlayerAction::AllIn,
        "raises over the stack are shoves"
    );

    // The big blind with nobody raising may check: a fold is turned into the free check.
    let mut state = support::dealt(2, 1000, 3);
    // Heads-up: the small blind (button) acts first; limp to hand the option to the big blind.
    state = poker_engine::apply(
        &state,
        poker_engine::Command::Action {
            player_id: support::pid(usize::from(state.table.active.unwrap().get())),
            action: PlayerAction::Call,
        },
    )
    .unwrap()
    .state;
    let active = state.table.active.unwrap();
    let view = poker_bots::view_for_seat(&state.table, active, &[]).unwrap();
    assert!(view.legal.can_check);
    assert_eq!(legalize(PlayerAction::Fold, &view), PlayerAction::Check);
    assert_eq!(legalize(PlayerAction::Call, &view), PlayerAction::Check);
}

#[test]
fn decide_cost_budget() {
    // Hard, postflop, six opponents: the worst case for the equity estimate. The estimate has an
    // 8 ms budget of its own; the median must stay well under it even in a debug build.
    let mut rng = BotRng::from_seed(21);
    let mut mind = BotMind::new(Personality::sample(Archetype::Tag, &mut rng), Skill::Hard);
    let mut times = Vec::new();
    for seed in 0..60 {
        let mut state = support::dealt(7, 5000, seed);
        // Walk to the flop by calling around.
        while state.table.phase == poker_engine::Phase::PreFlop {
            let Some(active) = state.table.active else {
                break;
            };
            let action = if state.table.seat(active).unwrap().street_bet < state.table.current_bet {
                PlayerAction::Call
            } else {
                PlayerAction::Check
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
        let Some(active) = state.table.active else {
            continue;
        };
        let Some(view) = poker_bots::view_for_seat(&state.table, active, &[]) else {
            continue;
        };
        let started = std::time::Instant::now();
        let _ = decide(&view, &mut mind, &mut rng);
        times.push(started.elapsed());
    }
    times.sort();
    let median = times[times.len() / 2];
    assert!(
        median < std::time::Duration::from_millis(12),
        "median decision {median:?}"
    );
    eprintln!(
        "hard postflop median decision: {median:?} over {} decisions",
        times.len()
    );
}

#[test]
fn a_table_has_no_single_rhythm() {
    // Across every kind of player and spot, most moves are quick, a few are slow, and the
    // spread between a quick player and a slow one is wide: nobody waits long for most moves.
    let (mut view, mut p) = a_view();
    view.to_call = chips(40);
    let mut rng = BotRng::from_seed(21);
    let mut times: Vec<u32> = Vec::new();
    for speed in [0.0_f32, 0.25, 0.5, 0.75, 1.0] {
        p.think_speed = speed;
        for action in [PlayerAction::Fold, PlayerAction::Call, PlayerAction::Check] {
            for closeness in [0.0, 0.4, 0.8] {
                for _ in 0..80 {
                    times.push(think_time(&view, action, closeness, &p, &mut rng));
                }
            }
        }
    }
    times.sort_unstable();
    let at = |q: usize| times[times.len() * q / 100];
    assert!(at(25) < 1_200, "a quarter of the moves take {} ms", at(25));
    assert!(at(50) < 2_200, "half of the moves take {} ms", at(50));
    assert!(at(90) > 3_000, "the slow tail takes {} ms", at(90));
    let mut quick = 0.0_f32;
    let mut slow = 0.0_f32;
    p.think_speed = 1.0;
    quick += average(&view, PlayerAction::Call, 0.5, &p);
    p.think_speed = 0.0;
    slow += average(&view, PlayerAction::Call, 0.5, &p);
    assert!(slow > quick * 2.5, "tempos differ: {quick} vs {slow}");
}
