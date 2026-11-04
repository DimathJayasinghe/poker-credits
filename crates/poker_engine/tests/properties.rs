//! Property tests: chips are conserved, no command sequence panics, and replaying the accepted
//! commands (also through a snapshot round trip) always lands on the same state.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::command::Allocation;
use poker_engine::{Chips, Command, GameState, MAX_CHIPS, Phase, PlayerAction, PlayerId, apply};
use proptest::prelude::*;
use support::{cash, chips, pid, seat};

/// Case count: `PROPTEST_CASES` overrides the default so a long soak can be run on demand.
fn cases(default: u32) -> u32 {
    std::env::var("PROPTEST_CASES")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}

#[derive(Clone, Debug)]
enum Step {
    Fold,
    Check,
    Call,
    Raise(u64),
    AllIn,
    Timeout,
    Start,
    BeginShowdown,
    Resolve(u8),
    Undo,
    Pause,
    Resume,
    Rebuy(u64),
    SitOut(bool),
    Remove,
    Leave,
    Move(u8),
}

fn step_strategy() -> impl Strategy<Value = (Step, u8)> {
    let step = prop_oneof![
        4 => Just(Step::Fold),
        4 => Just(Step::Check),
        6 => Just(Step::Call),
        5 => (0..2 * MAX_CHIPS).prop_map(Step::Raise),
        3 => (0_u64..400).prop_map(Step::Raise),
        2 => Just(Step::AllIn),
        1 => Just(Step::Timeout),
        3 => Just(Step::Start),
        2 => Just(Step::BeginShowdown),
        3 => any::<u8>().prop_map(Step::Resolve),
        1 => Just(Step::Undo),
        1 => Just(Step::Pause),
        1 => Just(Step::Resume),
        1 => (1_u64..5_000).prop_map(Step::Rebuy),
        1 => any::<bool>().prop_map(Step::SitOut),
        1 => Just(Step::Remove),
        2 => Just(Step::Leave),
        2 => (0_u8..10).prop_map(Step::Move),
    ];
    // The second value picks who the command is sent as (mostly the active player).
    (step, any::<u8>())
}

fn command_for(state: &GameState, step: &Step, who: u8, players: usize) -> Command {
    let table = &state.table;
    let wrong_player = who.is_multiple_of(5);
    let player: PlayerId = match table.active.and_then(|s| table.seat(s)) {
        Some(active) if !wrong_player => active.player_id.clone(),
        _ => pid(usize::from(who) % players),
    };
    match step {
        Step::Fold => Command::Action {
            player_id: player,
            action: PlayerAction::Fold,
        },
        Step::Check => Command::Action {
            player_id: player,
            action: PlayerAction::Check,
        },
        Step::Call => Command::Action {
            player_id: player,
            action: PlayerAction::Call,
        },
        Step::Raise(to) => Command::Action {
            player_id: player,
            action: PlayerAction::Raise {
                to_amount: Chips::new(*to).unwrap(),
            },
        },
        Step::AllIn => Command::Action {
            player_id: player,
            action: PlayerAction::AllIn,
        },
        Step::Timeout => Command::Timeout { player_id: player },
        Step::Start => Command::StartHand { elapsed_ms: 0 },
        Step::BeginShowdown => Command::BeginShowdown,
        Step::Resolve(selector) => {
            let allocations = table
                .pots
                .iter()
                .filter(|_| selector & 2 == 0 || selector & 4 == 0)
                .map(|pot| {
                    let eligible = pot
                        .eligible
                        .iter()
                        .filter_map(|s| table.seat(*s))
                        .map(|s| s.player_id.clone());
                    let winners = if selector & 1 == 0 {
                        eligible.collect()
                    } else {
                        eligible.take(1).collect()
                    };
                    Allocation {
                        pot_index: pot.tier_index,
                        winners,
                    }
                })
                .collect();
            Command::ResolveShowdown { allocations }
        }
        Step::Undo => Command::Undo,
        Step::Pause => Command::Pause,
        Step::Resume => Command::Resume,
        Step::Rebuy(amount) => Command::Rebuy {
            player_id: player,
            amount: Chips::new(*amount).unwrap(),
        },
        Step::SitOut(flag) => Command::SetSittingOut {
            player_id: player,
            sitting_out: *flag,
        },
        Step::Remove => Command::RemovePlayer { player_id: player },
        Step::Leave => Command::LeaveHand { player_id: player },
        Step::Move(target) => Command::MoveSeat {
            player_id: player,
            seat: seat(*target),
        },
    }
}

fn stack_strategy() -> impl Strategy<Value = u64> {
    prop_oneof![1_u64..=2_000, (MAX_CHIPS - 5_000)..=MAX_CHIPS]
}

fn initial_state(stacks: &[u64], small_blind: u64, extra_big: u64) -> GameState {
    let mut state = GameState::new(cash(small_blind, small_blind + extra_big, 0)).unwrap();
    for (index, stack) in stacks.iter().enumerate() {
        let next = apply(
            &state,
            Command::AddPlayer {
                player_id: pid(index),
                seat: seat(u8::try_from(index).unwrap()),
                chips: chips(*stack),
            },
        )
        .unwrap();
        state = next.state;
    }
    state
}

fn assert_consistent(state: &GameState, expected_total: u64) {
    let table = &state.table;
    assert_eq!(
        table.total_chips(),
        expected_total,
        "chips must be conserved"
    );
    assert!(state.history.len() <= poker_engine::undo::UNDO_DEPTH);
    assert!(
        table
            .seats
            .windows(2)
            .all(|pair| pair[0].index < pair[1].index)
    );
    match table.phase {
        Phase::PreFlop | Phase::Flop | Phase::Turn | Phase::River => {
            let active = table
                .active
                .and_then(|s| table.seat(s))
                .expect("a betting street always has an actor");
            assert_eq!(active.status, poker_engine::HandStatus::Live);
            assert!(table.pots.is_empty());
        }
        Phase::AllInRunout | Phase::Showdown => {
            assert_eq!(table.active, None);
            let pot_total: u64 = table.pots.iter().map(|p| p.amount.get()).sum();
            assert_eq!(
                pot_total,
                table.total_pot().get(),
                "pots must hold every committed chip"
            );
        }
        Phase::Lobby | Phase::NextHandPrep => {
            assert_eq!(table.active, None);
            assert!(table.total_pot().is_zero());
            assert!(!table.paused);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: cases(300), ..ProptestConfig::default() })]

    /// Fuzzing arbitrary commands never panics, keeps every invariant, and replay is exact.
    #[test]
    fn arbitrary_commands_conserve_chips_and_replay_exactly(
        stacks in prop::collection::vec(stack_strategy(), 2..=6),
        small_blind in 1_u64..=50,
        extra_big in 0_u64..=50,
        steps in prop::collection::vec(step_strategy(), 1..120),
        snapshot_every in 1_usize..8,
    ) {
        let players = stacks.len();
        let initial = initial_state(&stacks, small_blind, extra_big);
        let mut expected_total: u64 = stacks.iter().sum();
        let mut state = initial.clone();
        let mut journal = Vec::new();

        for (index, (step, who)) in steps.iter().enumerate() {
            let command = command_for(&state, step, *who, players);
            let rebuy = if let Command::Rebuy { amount, .. } = &command { amount.get() } else { 0 };
            // Removing a player cashes out their stack, so the table total legitimately drops.
            let cash_out = match &command {
                Command::RemovePlayer { player_id } => {
                    state.table.seat_of(player_id).map_or(0, |s| s.chips.get())
                }
                _ => 0,
            };
            if let Ok(transition) = apply(&state, command.clone()) {
                expected_total = expected_total + rebuy - cash_out;
                state = transition.state;
                journal.push(command);
            }
            assert_consistent(&state, expected_total);
            if index % snapshot_every == 0 {
                let json = serde_json::to_string(&state).unwrap();
                state = serde_json::from_str(&json).unwrap();
            }
        }

        let mut replayed = initial;
        for command in journal {
            replayed = apply(&replayed, command).expect("accepted commands replay").state;
        }
        prop_assert_eq!(replayed, state);
    }

    /// A rejected command never changes anything.
    #[test]
    fn rejected_commands_do_not_mutate(
        stacks in prop::collection::vec(stack_strategy(), 2..=4),
        steps in prop::collection::vec(step_strategy(), 1..60),
    ) {
        let players = stacks.len();
        let mut state = initial_state(&stacks, 10, 10);
        for (step, who) in &steps {
            let command = command_for(&state, step, *who, players);
            let before = state.clone();
            if let Ok(transition) = apply(&state, command) {
                state = transition.state;
            } else {
                prop_assert_eq!(&state, &before);
            }
        }
    }
}

/// Picks a command the engine itself says is legal.
fn legal_command(state: &GameState, byte: u8) -> Option<Command> {
    let table = &state.table;
    match table.phase {
        Phase::PreFlop | Phase::Flop | Phase::Turn | Phase::River => {
            let (index, legal) = state.legal_actions()?;
            let player_id = table.seat(index)?.player_id.clone();
            let action = match byte % 5 {
                0 => PlayerAction::Fold,
                1 | 2 if legal.can_check => PlayerAction::Check,
                1 | 2 => PlayerAction::Call,
                3 if legal.can_raise => {
                    let span = legal.max_raise_to.get() - legal.min_raise_to.get();
                    let offset = span / 255 * u64::from(byte);
                    PlayerAction::Raise {
                        to_amount: Chips::new(legal.min_raise_to.get() + offset).ok()?,
                    }
                }
                _ if legal.can_raise => PlayerAction::AllIn,
                _ if legal.can_check => PlayerAction::Check,
                _ => PlayerAction::Call,
            };
            Some(Command::Action { player_id, action })
        }
        Phase::AllInRunout => Some(Command::BeginShowdown),
        Phase::Showdown => {
            let allocations = table
                .pots
                .iter()
                .map(|pot| {
                    let mut winners = pot
                        .eligible
                        .iter()
                        .filter_map(|s| table.seat(*s))
                        .map(|s| s.player_id.clone());
                    let winners = if byte.is_multiple_of(3) {
                        winners.collect()
                    } else {
                        winners
                            .nth(usize::from(byte) % pot.eligible.len())
                            .into_iter()
                            .collect()
                    };
                    Allocation {
                        pot_index: pot.tier_index,
                        winners,
                    }
                })
                .collect();
            Some(Command::ResolveShowdown { allocations })
        }
        Phase::NextHandPrep | Phase::Lobby => Some(Command::StartHand {
            elapsed_ms: u64::from(byte),
        }),
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: cases(300), ..ProptestConfig::default() })]

    /// Every command built from the engine's own legal actions is accepted, whole hands play out,
    /// and chips are conserved throughout.
    #[test]
    fn legal_play_is_always_accepted_and_hands_complete(
        stacks in prop::collection::vec(stack_strategy(), 2..=8),
        small_blind in 1_u64..=50,
        extra_big in 0_u64..=50,
        bytes in prop::collection::vec(any::<u8>(), 200..400),
    ) {
        let total: u64 = stacks.iter().sum();
        let mut state = initial_state(&stacks, small_blind, extra_big);
        let mut hands_ended = 0_u32;
        for byte in bytes {
            let Some(command) = legal_command(&state, byte) else { break };
            let was_hand_phase = state.table.phase != Phase::Lobby && state.table.phase != Phase::NextHandPrep;
            match apply(&state, command) {
                Ok(transition) => {
                    let ended = transition.events.iter().any(|e| matches!(e, poker_engine::Event::HandEnded { .. }));
                    hands_ended += u32::from(ended && was_hand_phase);
                    state = transition.state;
                }
                Err(poker_engine::PokerError::NotEnoughPlayers) => break, // everyone but one busted
                Err(error) => prop_assert!(false, "engine rejected its own legal command: {error}"),
            }
            assert_consistent(&state, total);
        }
        prop_assert!(hands_ended >= 1, "200+ legal commands must finish at least one hand");
    }
}

/// Found by a long soak (`PROPTEST_CASES=50000`): the blinds fold out of turn, so the only
/// contender is the button, who has paid nothing. The blinds used to vanish with no pot to hold
/// them.
#[test]
fn dead_money_goes_to_a_contender_who_has_paid_nothing() {
    let stacks = [1_000_u64, 11, 55, 1];
    let mut state = initial_state(&stacks, 1, 0);
    let total: u64 = stacks.iter().sum();
    for command in [
        Command::StartHand { elapsed_ms: 0 },
        Command::LeaveHand { player_id: pid(3) },
        Command::LeaveHand { player_id: pid(2) },
        Command::LeaveHand { player_id: pid(1) },
    ] {
        state = apply(&state, command).unwrap().state;
        assert_eq!(state.table.total_chips(), total, "chips must be conserved");
    }
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    let winner = state.table.seat_of(&pid(0)).unwrap();
    assert_eq!(winner.chips.get(), 1_002);
}
