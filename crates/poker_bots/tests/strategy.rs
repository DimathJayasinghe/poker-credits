//! Strategy in chosen spots: what a bot does with a given hand, board, price and opponent.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::cast_precision_loss,
    clippy::too_many_arguments
)]

mod support;

use poker_bots::{Archetype, BotMind, BotRng, Personality, PublicAction, Reveal, Skill, decide};
use poker_bots::{BotView, SeatView};
use poker_engine::blinds::Blinds;
use poker_engine::hand_rank::HandCategory;
use poker_engine::validator::LegalActions;
use poker_engine::{ActionKind, HandStatus, Phase, PlayerAction, SeatIndex};
use support::{card, cards, chips, pid, seat};

/// One decision spot for the bot at seat 0 against one rival at seat 1 (the button, so the bot
/// acts last after the flop).
struct Spot {
    hole: &'static str,
    board: &'static str,
    pot: u64,
    to_call: u64,
    stack: u64,
    rival_stack: u64,
    history: Vec<PublicAction>,
}

impl Spot {
    fn new(hole: &'static str, board: &'static str) -> Spot {
        Spot {
            hole,
            board,
            pot: 100,
            to_call: 0,
            stack: 2000,
            rival_stack: 2000,
            history: Vec::new(),
        }
    }

    fn view(&self) -> BotView {
        let h = cards(self.hole);
        let board = cards(self.board);
        let phase = match board.len() {
            0 => Phase::PreFlop,
            3 => Phase::Flop,
            4 => Phase::Turn,
            _ => Phase::River,
        };
        let me_bet = 0;
        let seats = vec![
            SeatView {
                index: seat(0),
                player_id: pid(0),
                chips: chips(self.stack),
                street_bet: chips(me_bet),
                hand_contrib: chips(0),
                status: HandStatus::Live,
                sitting_out: false,
            },
            SeatView {
                index: seat(1),
                player_id: pid(1),
                chips: chips(self.rival_stack),
                street_bet: chips(self.to_call),
                hand_contrib: chips(self.to_call),
                status: HandStatus::Live,
                sitting_out: false,
            },
        ];
        let max = self.stack;
        let min = (self.to_call * 2).max(20).min(max);
        BotView {
            me: seat(0),
            hole: [h[0], h[1]],
            board,
            phase,
            pot_total: chips(self.pot),
            seats,
            button: Some(seat(1)),
            to_call: chips(self.to_call),
            legal: LegalActions {
                can_fold: true,
                can_check: self.to_call == 0,
                can_call: self.to_call > 0,
                call_amount: chips(self.to_call.min(self.stack)),
                can_raise: self.stack > self.to_call,
                min_raise_to: chips(min),
                max_raise_to: chips(max),
            },
            blinds: Blinds {
                small_blind: chips(10),
                big_blind: chips(20),
                ante: chips(0),
            },
            hand_number: 5,
            history: self.history.clone(),
        }
    }
}

fn act(who: u8, street: Phase, kind: ActionKind) -> PublicAction {
    PublicAction {
        seat: seat(who),
        street,
        kind,
        amount: chips(0),
    }
}

fn mind(kind: Archetype, skill: Skill) -> BotMind {
    let mut p = Personality::sample(kind, &mut BotRng::from_seed(11));
    p.read_weight = 1.0;
    let mut m = BotMind::new(p, skill);
    m.equity_budget = None;
    m
}

fn everyone() -> Vec<SeatIndex> {
    vec![seat(0), seat(1)]
}

/// Notes on seat 1 from sixty hands of a given habit: `tight` raises 4 times in 60 and mostly
/// calls after the flop and shows strength; the other raises 36 times, always bets and shows
/// weak hands.
fn rival_notes(notes: &mut poker_bots::notes::Notes, tight: bool) {
    for h in 0..60 {
        notes.begin_hand(&everyone());
        let raises = if tight { h < 4 } else { h < 36 };
        notes.observe_action(&act(
            1,
            Phase::PreFlop,
            if raises {
                ActionKind::Raise
            } else {
                ActionKind::Fold
            },
        ));
        notes.observe_action(&act(
            1,
            Phase::Flop,
            if tight {
                ActionKind::Call
            } else {
                ActionKind::Bet
            },
        ));
    }
    let reveal = Reveal {
        seat: seat(1),
        hole: if tight {
            [card("Ac"), card("Ad")]
        } else {
            [card("7c"), card("2d")]
        },
        category: if tight {
            HandCategory::ThreeOfAKind
        } else {
            HandCategory::HighCard
        },
    };
    for _ in 0..25 {
        notes.begin_hand(&everyone());
        notes.observe_showdown(&[reveal], &[act(1, Phase::Flop, ActionKind::Bet)]);
    }
}

/// How often the bot does each thing over `trials` fresh dice: (fold, call/check, raise/all-in).
fn mix(spot: &Spot, mind: &mut BotMind, trials: u64) -> (f32, f32, f32) {
    let view = spot.view();
    let (mut fold, mut pass, mut raise) = (0.0, 0.0, 0.0);
    for seed in 0..trials {
        let mut rng = BotRng::from_seed(seed * 7919 + 3);
        match decide(&view, mind, &mut rng).action {
            PlayerAction::Fold => fold += 1.0,
            PlayerAction::Check | PlayerAction::Call => pass += 1.0,
            PlayerAction::Raise { .. } | PlayerAction::AllIn => raise += 1.0,
        }
    }
    let n = trials as f32;
    (fold / n, pass / n, raise / n)
}

#[test]
fn easy_does_not_bet_a_board_it_only_shares() {
    for board in ["Ks Kd Kh 9c 4d", "As Ad 7s 7h Kc"] {
        let spot = Spot::new("2c 3d", board);
        let mut m = mind(Archetype::Tag, Skill::Easy);
        let (_, _, raise) = mix(&spot, &mut m, 200);
        assert!(raise < 0.2, "{board}: raised {raise}");
    }
}

#[test]
fn a_bluff_catcher_folds_to_a_nit_and_calls_a_maniac() {
    // Second pair on the turn, facing a pot-sized bet after the rival also bet the flop.
    let mut spot = Spot::new("7h 6c", "Ks 7d 2c 4h");
    spot.pot = 300;
    spot.to_call = 200;
    spot.history = vec![
        act(1, Phase::PreFlop, ActionKind::Raise),
        act(0, Phase::PreFlop, ActionKind::Call),
        act(1, Phase::Flop, ActionKind::Bet),
        act(0, Phase::Flop, ActionKind::Call),
        act(1, Phase::Turn, ActionKind::Bet),
    ];
    let mut vs_nit = mind(Archetype::Tag, Skill::Hard);
    rival_notes(&mut vs_nit.notes, true);
    let mut vs_maniac = mind(Archetype::Tag, Skill::Hard);
    rival_notes(&mut vs_maniac.notes, false);
    let (fold_nit, _, _) = mix(&spot, &mut vs_nit, 80);
    let (fold_maniac, _, _) = mix(&spot, &mut vs_maniac, 80);
    assert!(fold_nit > 0.8, "folds to a nit {fold_nit}");
    assert!(fold_maniac < 0.4, "folds to a maniac {fold_maniac}");
}

#[test]
fn the_shorter_the_stack_the_wider_the_shove() {
    let mut deal = BotRng::from_seed(99);
    let hands: Vec<String> = (0..300)
        .map(|_| {
            let deck = support::shuffled(&mut deal);
            let c = &deck.cards()[..2];
            format!("{} {}", c[0], c[1])
        })
        .collect();
    let shove_rate = |bb: u64, skill: Skill| {
        let mut m = mind(Archetype::Tag, skill);
        let mut shoves = 0.0;
        for (i, h) in hands.iter().enumerate() {
            let h: &'static str = Box::leak(h.clone().into_boxed_str());
            let mut spot = Spot::new(h, "");
            spot.pot = 30;
            spot.to_call = 20;
            spot.stack = bb * 20;
            spot.rival_stack = 2000;
            spot.history = vec![];
            let view = spot.view();
            let mut rng = BotRng::from_seed(i as u64 + 1);
            if matches!(decide(&view, &mut m, &mut rng).action, PlayerAction::AllIn) {
                shoves += 1.0;
            }
        }
        shoves / hands.len() as f32
    };
    for skill in [Skill::Normal, Skill::Hard] {
        let (three, seven, eleven) = (
            shove_rate(3, skill),
            shove_rate(7, skill),
            shove_rate(11, skill),
        );
        eprintln!("{skill:?}: 3bb {three:.2} 7bb {seven:.2} 11bb {eleven:.2}");
        assert!(three > 0.75, "{skill:?} 3bb {three}");
        assert!(
            three > seven && seven > eleven,
            "{skill:?} {three} {seven} {eleven}"
        );
        assert!(eleven < 0.40, "{skill:?} 11bb {eleven}");
    }
}

#[test]
fn a_strong_draw_is_played_like_a_hand() {
    let draw = Spot::new("Ah 5h", "Kh 9h 2c");
    let air = Spot::new("5c 4d", "Kh 9h 2c");
    for skill in [Skill::Normal, Skill::Hard] {
        let mut m = mind(Archetype::Tag, skill);
        let (_, _, with_draw) = mix(&draw, &mut m, 300);
        let (_, _, nothing) = mix(&air, &mut m, 300);
        eprintln!("{skill:?}: draw {with_draw:.2} air {nothing:.2}");
        assert!(
            with_draw > nothing + 0.12,
            "{skill:?} {with_draw} vs {nothing}"
        );
    }
}

#[test]
fn bluffs_come_from_hands_that_block_the_nuts() {
    // Nothing on the river on a flush board: holding the ace of the flush suit blocks the nuts.
    let blocker = Spot::new("Ah 7c", "Kh 9h 5h 2c 3d");
    let nothing = Spot::new("7d 4c", "Kh 9h 5h 2c 3d");
    // Only Hard picks its bluffs by what it blocks; Normal bluffs the same with any nothing.
    let skill = Skill::Hard;
    let mut m = mind(Archetype::Lag, skill);
    let (_, _, with) = mix(&blocker, &mut m, 600);
    let (_, _, without) = mix(&nothing, &mut m, 600);
    eprintln!("{skill:?}: blocker {with:.3} none {without:.3}");
    assert!(with > without * 1.5, "{skill:?} {with} vs {without}");
}

/// Mean size of the bets a bot makes with `hole` on `board`.
fn mean_bet(hole: &'static str, board: &'static str, skill: Skill) -> f32 {
    mean_bet_over(hole, board, skill, 800)
}

fn mean_bet_over(hole: &'static str, board: &'static str, skill: Skill, trials: u64) -> f32 {
    let spot = Spot::new(hole, board);
    let view = spot.view();
    let mut m = mind(Archetype::Tag, skill);
    let (mut total, mut count) = (0.0, 0.0);
    for seed in 0..trials {
        let mut rng = BotRng::from_seed(seed * 31 + 5);
        if let PlayerAction::Raise { to_amount } = decide(&view, &mut m, &mut rng).action {
            total += to_amount.get() as f32;
            count += 1.0;
        }
    }
    assert!(
        count > 20.0,
        "{hole} on {board} bets only {count} times in {trials}"
    );
    total / count
}

#[test]
fn hard_sizes_a_bet_by_the_board_not_by_the_hand() {
    let value = mean_bet("9c 9d", "9s 8d 3c", Skill::Hard);
    let draw = mean_bet("Ah 5h", "Kh 9h 2c", Skill::Hard);
    let value_wet = mean_bet("Ks Kd", "Kh 9h 2c", Skill::Hard);
    eprintln!(
        "Hard bets: value {value:.0}, draw {draw:.0}, value on the draw board {value_wet:.0}"
    );
    // The same board gets the same size whether the hand is a draw or a set.
    assert!(
        (draw - value_wet).abs() / value_wet < 0.10,
        "draw {draw} vs value {value_wet} on one board"
    );
}

/// Forty hands in which the bot at seat 0 bets the flop and the rival either folds or calls.
fn response_notes(notes: &mut poker_bots::notes::Notes, folds: bool) {
    for _ in 0..40 {
        notes.begin_hand(&everyone());
        notes.observe_action(&act(0, Phase::Flop, ActionKind::Bet));
        notes.observe_action(&act(
            1,
            Phase::Flop,
            if folds {
                ActionKind::Fold
            } else {
                ActionKind::Call
            },
        ));
    }
}

#[test]
fn a_reader_bets_at_players_who_fold_and_not_at_players_who_call() {
    // Nothing in hand, nothing to draw to, checked to on a dry flop.
    let spot = Spot::new("5c 4d", "Ks 9h 2c");
    let mut vs_folder = mind(Archetype::Tag, Skill::Hard);
    response_notes(&mut vs_folder.notes, true);
    let mut vs_caller = mind(Archetype::Tag, Skill::Hard);
    response_notes(&mut vs_caller.notes, false);
    let (_, _, folder) = mix(&spot, &mut vs_folder, 400);
    let (_, _, caller) = mix(&spot, &mut vs_caller, 400);
    eprintln!("bets with nothing: vs a folder {folder:.2}, vs a caller {caller:.2}");
    assert!(folder > caller + 0.20, "{folder} vs {caller}");
    // Normal reads too, but slowly and less: it moves the same way by less.
    let mut normal_folder = mind(Archetype::Tag, Skill::Normal);
    response_notes(&mut normal_folder.notes, true);
    let (_, _, normal) = mix(&spot, &mut normal_folder, 400);
    assert!(normal < folder, "normal {normal} vs hard {folder}");
}

#[test]
fn a_reader_value_bets_thinner_against_players_who_call() {
    // A hand just short of a value bet: worth one only against someone who pays with worse.
    let spot = Spot::new("Qd 7c", "Ks 9h 2c");
    let mut stranger = mind(Archetype::Tag, Skill::Hard);
    let mut vs_caller = mind(Archetype::Tag, Skill::Hard);
    response_notes(&mut vs_caller.notes, false);
    let (_, _, unknown) = mix(&spot, &mut stranger, 400);
    let (_, _, caller) = mix(&spot, &mut vs_caller, 400);
    eprintln!("bets a borderline hand: vs a stranger {unknown:.2}, vs a caller {caller:.2}");
    assert!(caller > unknown + 0.10, "{caller} vs {unknown}");
}

#[test]
fn easy_bet_sizes_give_the_hand_away() {
    // A beginner bets big with a strong hand and small without: a human can read it.
    let strong = mean_bet("9c 9d", "9s 8d 3c", Skill::Easy);
    let weak = mean_bet_over("Qd 7c", "Ks 9h 2c", Skill::Easy, 6000);
    eprintln!("Easy bets: strong {strong:.0}, weak {weak:.0}");
    assert!(strong > weak * 1.5, "strong {strong} vs weak {weak}");
}
