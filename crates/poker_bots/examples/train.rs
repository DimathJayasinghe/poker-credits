//! Self-play trainer for the bots' judgement numbers (`poker_bots::Tuning`).
//!
//! An evolution strategy (mirrored sampling, rank-weighted mean, shrinking step) searches the
//! 16-number vector. A candidate plays a Tag-style Normal bot at a six-handed table against the
//! five other styles using the hand-set numbers; every candidate of a generation sees the same
//! decks (common random numbers), so the comparison is far less noisy than the poker variance.
//! Fitness is chips won in big blinds per 100 hands, minus a penalty for leaving the style
//! envelope (how often it plays a hand, how often it folds to a postflop bet), so the trainer
//! cannot "win" by turning into a nit or a station.
//!
//! ```text
//! cargo run --release -p poker_bots --example train -- [generations] [hands] [seed]
//! ```
//!
//! It prints the best vector as Rust source to paste into `Tuning::LEARNED`.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::cast_precision_loss,
    clippy::cast_possible_truncation,
    clippy::print_stdout,
    clippy::print_stderr,
    clippy::too_many_lines
)]

#[path = "../tests/support/mod.rs"]
mod support;

use poker_bots::tuning::{PARAMS, SPEC};
use poker_bots::{Archetype, BotMind, BotRng, Personality, Skill, Tuning};
use poker_engine::{ActionKind, Phase};
use support::sim::{Bot, play_hand, table};

const START: u64 = 2000;
const BIG: f64 = 20.0;

struct Score {
    bb100: f64,
    vpip: f64,
    fold_to_bet: f64,
}

/// The level being trained (`TRAIN_SKILL=hard`; default normal).
fn trained_skill() -> Skill {
    match std::env::var("TRAIN_SKILL").as_deref() {
        Ok("hard") => Skill::Hard,
        _ => Skill::Normal,
    }
}

fn bot(kind: Archetype, tuning: Tuning, seed: u64, skill: Skill) -> Bot {
    let mut rng = BotRng::from_seed(seed);
    let mut mind = BotMind::new(Personality::sample(kind, &mut rng), skill);
    mind.equity_budget = None;
    mind.tuning = tuning;
    Bot {
        mind,
        rng: BotRng::from_seed(seed ^ 0x5EED),
    }
}

/// One candidate against the field for `hands` hands, decks from `deck_seed`.
fn evaluate(candidate: Tuning, hands: u32, deck_seed: u64) -> Score {
    let field = [
        Archetype::Rock,
        Archetype::Lag,
        Archetype::CallingStation,
        Archetype::Maniac,
        Archetype::NitTrapper,
    ];
    let mut bots = vec![bot(
        Archetype::Tag,
        candidate,
        deck_seed ^ 0x0B,
        trained_skill(),
    )];
    for (i, kind) in field.iter().enumerate() {
        bots.push(bot(
            *kind,
            Tuning::BASE,
            deck_seed ^ (100 + i as u64),
            Skill::Normal,
        ));
    }
    let n = bots.len();
    let mut state = table(&vec![START; n], 10, 20);
    let mut deck_rng = BotRng::from_seed(deck_seed);
    let (mut net, mut played, mut vpip) = (0.0_f64, 0.0_f64, 0.0_f64);
    let (mut folds, mut facing) = (0.0_f64, 0.0_f64);
    for _ in 0..hands {
        for i in 0..n {
            let seat = state.table.seat_of(&support::pid(i)).unwrap();
            if seat.chips.get() < 40 {
                let top = START - seat.chips.get();
                state = poker_engine::apply(
                    &state,
                    poker_engine::Command::Rebuy {
                        player_id: support::pid(i),
                        amount: support::chips(top),
                    },
                )
                .map(|t| t.state)
                .unwrap_or(state);
            }
        }
        let Some(log) = play_hand(&mut state, &mut bots, &mut deck_rng).unwrap() else {
            break;
        };
        played += 1.0;
        net += log.net[0] as f64;
        let mine = |a: &&poker_bots::PublicAction| a.seat.get() == 0;
        if log.actions.iter().filter(mine).any(|a| {
            a.street == Phase::PreFlop
                && matches!(
                    a.kind,
                    ActionKind::Call | ActionKind::Raise | ActionKind::Bet
                )
        }) {
            vpip += 1.0;
        }
        for a in log.actions.iter().filter(mine) {
            if a.street == Phase::PreFlop {
                continue;
            }
            match a.kind {
                ActionKind::Fold => {
                    folds += 1.0;
                    facing += 1.0;
                }
                ActionKind::Call | ActionKind::Raise => facing += 1.0,
                _ => {}
            }
        }
    }
    let played = played.max(1.0);
    Score {
        bb100: net / played / BIG * 100.0,
        vpip: vpip / played,
        fold_to_bet: if facing > 0.0 { folds / facing } else { 0.0 },
    }
}

/// Fitness: chips won, minus a penalty for leaving the style envelope.
fn fitness(s: &Score) -> f64 {
    let mut penalty = 0.0;
    // A Tag plays roughly a fifth to a third of its hands and neither folds to every bet (the
    // owner found bots that fold too easily no fun) nor calls everything.
    let (fold_low, fold_high) = match trained_skill() {
        Skill::Hard => (0.30, 0.42),
        _ => (0.28, 0.40),
    };
    penalty += 400.0 * (0.20 - s.vpip).max(0.0);
    penalty += 400.0 * (s.vpip - 0.36).max(0.0);
    penalty += 400.0 * (s.fold_to_bet - fold_high).max(0.0);
    penalty += 400.0 * (fold_low - s.fold_to_bet).max(0.0);
    s.bb100 - penalty
}

fn decode(u: &[f64; PARAMS]) -> Tuning {
    let mut v = [0.0_f32; PARAMS];
    for i in 0..PARAMS {
        let s = SPEC[i];
        v[i] = s.min + (s.max - s.min) * u[i].clamp(0.0, 1.0) as f32;
    }
    Tuning { v }
}

fn encode(t: &Tuning) -> [f64; PARAMS] {
    let mut u = [0.0; PARAMS];
    for i in 0..PARAMS {
        let s = SPEC[i];
        u[i] = f64::from((t.v[i] - s.min) / (s.max - s.min));
    }
    u
}

fn gaussian(rng: &mut BotRng) -> f64 {
    // Box-Muller from two uniforms.
    let a = f64::from(rng.unit()).max(1e-9);
    let b = f64::from(rng.unit());
    (-2.0 * a.ln()).sqrt() * (std::f64::consts::TAU * b).cos()
}

/// `train eval <16 comma separated numbers> [seeds] [hands]`: the vector against the hand-set
/// one on fresh seeds, paired by seed, with the standard error of the difference.
fn validate(list: &str, seeds: u64, hands: u32) {
    let mut v = [0.0_f32; PARAMS];
    for (slot, part) in v.iter_mut().zip(list.split(',')) {
        *slot = part.trim().parse().expect("a number");
    }
    let learned = Tuning { v }.clamped();
    let runs: Vec<(Score, Score)> = std::thread::scope(|scope| {
        let handles: Vec<_> = (0..seeds)
            .map(|k| {
                scope.spawn(move || {
                    let seed = 900_001 + k * 31;
                    (
                        evaluate(Tuning::BASE, hands, seed),
                        evaluate(learned, hands, seed),
                    )
                })
            })
            .collect();
        handles.into_iter().map(|h| h.join().unwrap()).collect()
    });
    let n = runs.len() as f64;
    let diffs: Vec<f64> = runs.iter().map(|(a, b)| b.bb100 - a.bb100).collect();
    let mean = diffs.iter().sum::<f64>() / n;
    let var = diffs.iter().map(|d| (d - mean).powi(2)).sum::<f64>() / (n - 1.0);
    let avg = |f: &dyn Fn(&Score) -> f64, pick: usize| {
        runs.iter()
            .map(|r| f(if pick == 0 { &r.0 } else { &r.1 }))
            .sum::<f64>()
            / n
    };
    println!(
        "base    {:+7.1} bb/100  vpip {:4.1}%  fold {:4.1}%",
        avg(&|s| s.bb100, 0),
        100.0 * avg(&|s| s.vpip, 0),
        100.0 * avg(&|s| s.fold_to_bet, 0)
    );
    println!(
        "learned {:+7.1} bb/100  vpip {:4.1}%  fold {:4.1}%",
        avg(&|s| s.bb100, 1),
        100.0 * avg(&|s| s.vpip, 1),
        100.0 * avg(&|s| s.fold_to_bet, 1)
    );
    println!(
        "difference {mean:+.1} bb/100, standard error {:.1} over {seeds} seeds",
        (var / n).sqrt()
    );
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("eval") {
        let seeds = args.get(3).and_then(|a| a.parse().ok()).unwrap_or(20);
        let hands = args.get(4).and_then(|a| a.parse().ok()).unwrap_or(8000);
        validate(args.get(2).expect("a vector"), seeds, hands);
        return;
    }
    let generations: u32 = args.get(1).and_then(|a| a.parse().ok()).unwrap_or(40);
    let hands: u32 = args.get(2).and_then(|a| a.parse().ok()).unwrap_or(6000);
    let seed: u64 = args.get(3).and_then(|a| a.parse().ok()).unwrap_or(1);
    let lambda = 16_usize;
    let mu = 4_usize;
    let mut rng = BotRng::from_seed(seed.wrapping_mul(0x9E37_79B9));
    let mut mean = encode(&Tuning::BASE);
    let mut sigma = 0.14_f64;
    let weights: Vec<f64> = {
        let raw: Vec<f64> = (0..mu).map(|i| ((mu - i) as f64).ln() + 1.0).collect();
        let sum: f64 = raw.iter().sum();
        raw.iter().map(|w| w / sum).collect()
    };
    let started = std::time::Instant::now();
    for generation in 0..generations {
        let deck_seed = seed
            .wrapping_mul(1_000_003)
            .wrapping_add(u64::from(generation) * 7919);
        // Mirrored samples: each noise vector is tried with both signs.
        let mut noises: Vec<[f64; PARAMS]> = Vec::new();
        for _ in 0..lambda / 2 {
            let mut z = [0.0; PARAMS];
            for slot in &mut z {
                *slot = gaussian(&mut rng);
            }
            noises.push(z);
            noises.push(z.map(|x| -x));
        }
        // The preflop numbers (the first seven) keep the styles at a human scale and stay as set
        // unless `TRAIN_FREEZE=0`: the trainer learns the play after the flop.
        let frozen = if std::env::var("TRAIN_FREEZE").as_deref() == Ok("0") {
            0
        } else {
            7
        };
        let mut candidates: Vec<[f64; PARAMS]> = noises
            .iter()
            .map(|z| {
                let mut u = mean;
                for i in frozen..PARAMS {
                    u[i] = (mean[i] + sigma * z[i]).clamp(0.0, 1.0);
                }
                u
            })
            .collect();
        candidates.push(mean); // the mean itself, to follow its progress
        let results: Vec<(Score, f64)> = std::thread::scope(|scope| {
            let handles: Vec<_> = candidates
                .iter()
                .map(|u| {
                    let tuning = decode(u);
                    scope.spawn(move || {
                        let score = evaluate(tuning, hands, deck_seed);
                        let f = fitness(&score);
                        (score, f)
                    })
                })
                .collect();
            handles.into_iter().map(|h| h.join().unwrap()).collect()
        });
        let (mean_score, mean_fit) = &results[lambda];
        let mut order: Vec<usize> = (0..lambda).collect();
        order.sort_by(|a, b| results[*b].1.partial_cmp(&results[*a].1).unwrap());
        // Move the mean to the weighted centre of the best few.
        let mut next = [0.0; PARAMS];
        for (w, idx) in weights.iter().zip(order.iter()) {
            for i in 0..PARAMS {
                next[i] += w * candidates[*idx][i];
            }
        }
        // Only move if the best candidate beat the mean (guards against drifting on noise).
        if results[order[0]].1 > *mean_fit {
            mean = next;
        }
        sigma = (sigma * 0.975).max(0.04);
        println!(
            "gen {generation:3}  mean: fit {mean_fit:7.1}  {:+6.1} bb/100  vpip {:4.1}%  fold {:4.1}%   best cand {:7.1}   sigma {sigma:.3}   {:.0}s",
            mean_score.bb100,
            100.0 * mean_score.vpip,
            100.0 * mean_score.fold_to_bet,
            results[order[0]].1,
            started.elapsed().as_secs_f32()
        );
    }
    let learned = decode(&mean);
    println!("\nLEARNED = Tuning {{ v: [");
    for (i, spec) in SPEC.iter().enumerate() {
        println!(
            "    {:.4}, // {} (base {})",
            learned.v[i], spec.name, spec.base
        );
    }
    println!("] }}");
}
