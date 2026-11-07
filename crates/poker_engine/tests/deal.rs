//! Virtual hands: dealing, board reveal, showdown reveal, results, undo and old data.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

mod support;

use poker_engine::card::Card;
use poker_engine::deck::Deck;
use poker_engine::{
    Allocation, Command, Event, GameState, HandStatus, Phase, PlayerAction, PlayerId,
};
use support::{lobby, pid, step};

fn virtual_hand(stacks: &[u64]) -> GameState {
    let mut state = lobby(stacks, 1, 2);
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(Deck::standard()),
        },
    );
    state
}

fn act_active(state: &mut GameState, action: PlayerAction) -> Vec<Event> {
    let seat = state.table.active.expect("someone is to act");
    let player_id = state.table.seat(seat).unwrap().player_id.clone();
    step(state, Command::Action { player_id, action })
}

/// Checks or calls until the phase changes.
fn finish_street(state: &mut GameState) -> Vec<Event> {
    let start = state.table.phase;
    let mut events = Vec::new();
    while state.table.phase == start {
        let seat = state.table.active.expect("someone is to act");
        let owes = state.table.current_bet > state.table.seat(seat).unwrap().street_bet;
        let action = if owes {
            PlayerAction::Call
        } else {
            PlayerAction::Check
        };
        events.extend(act_active(state, action));
    }
    events
}

fn all_in_everyone(state: &mut GameState) -> Vec<Event> {
    let mut events = Vec::new();
    while state.table.active.is_some() {
        events.extend(act_active(state, PlayerAction::AllIn));
    }
    events
}

fn all_cards() -> Vec<Card> {
    Deck::standard().cards().to_vec()
}

#[test]
fn deal_gives_two_cards_per_live_seat_in_order_from_the_button() {
    let state = virtual_hand(&[1000, 1000, 1000]);
    let deal = state.table.deal.as_ref().unwrap();
    let dealer = state.table.dealer.unwrap();
    let expected: Vec<PlayerId> = state
        .table
        .seats_after(dealer)
        .filter(|s| s.status == HandStatus::Live)
        .map(|s| s.player_id.clone())
        .collect();
    let dealt: Vec<PlayerId> = deal.holes.iter().map(|(id, _)| id.clone()).collect();
    assert_eq!(dealt, expected);
    let deck = Deck::standard();
    let cards = deck.cards();
    assert_eq!(deal.holes[0].1, [cards[0], cards[1]]);
    assert_eq!(deal.holes[2].1, [cards[4], cards[5]]);
    assert_eq!(deal.board.to_vec(), cards[6..11].to_vec());
    assert_eq!(deal.hand_number, 1);
    assert_eq!(deal.board_shown, 0);
    assert!(deal.revealed.is_empty());
}

#[test]
fn sitting_out_players_are_not_dealt() {
    let mut state = lobby(&[1000, 1000, 1000], 1, 2);
    step(
        &mut state,
        Command::SetSittingOut {
            player_id: pid(1),
            sitting_out: true,
        },
    );
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: Some(Deck::standard()),
        },
    );
    let deal = state.table.deal.as_ref().unwrap();
    assert_eq!(deal.holes.len(), 2);
    assert!(deal.hole_of(&pid(1)).is_none());
}

#[test]
fn no_card_is_dealt_twice() {
    let state = virtual_hand(&[1000, 1000, 1000, 1000]);
    let deal = state.table.deal.as_ref().unwrap();
    let mut seen: Vec<Card> = deal.holes.iter().flat_map(|(_, c)| *c).collect();
    seen.extend(deal.board);
    let total = seen.len();
    seen.sort_unstable();
    seen.dedup();
    assert_eq!(seen.len(), total);
    assert_eq!(total, 4 * 2 + 5);
}

#[test]
fn physical_start_hand_leaves_deal_none() {
    let state = support::dealt(&[1000, 1000], 1, 2);
    assert!(state.table.deal.is_none());
}

#[test]
fn board_shown_is_0_3_4_5_by_street() {
    let mut state = virtual_hand(&[1000, 1000, 1000]);
    let shown = |s: &GameState| s.table.deal.as_ref().unwrap().board_shown;
    assert_eq!(shown(&state), 0);
    let events = finish_street(&mut state);
    assert_eq!(state.table.phase, Phase::Flop);
    assert_eq!(shown(&state), 3);
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::BoardRevealed { cards } if cards.len() == 3))
    );
    finish_street(&mut state);
    assert_eq!((state.table.phase, shown(&state)), (Phase::Turn, 4));
    finish_street(&mut state);
    assert_eq!((state.table.phase, shown(&state)), (Phase::River, 5));
    assert_eq!(
        state.table.deal.as_ref().unwrap().visible_board(),
        &all_cards()[6..11]
    );
}

#[test]
fn runout_shows_all_five_and_reveals_all_contenders() {
    let mut state = virtual_hand(&[500, 500, 500]);
    let events = all_in_everyone(&mut state);
    assert_eq!(state.table.phase, Phase::AllInRunout);
    let deal = state.table.deal.as_ref().unwrap();
    assert_eq!(deal.board_shown, 5);
    assert_eq!(deal.revealed.len(), 3);
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::BoardRevealed { cards } if cards.len() == 5))
    );
    assert!(
        events
            .iter()
            .any(|e| matches!(e, Event::HandsRevealed { players } if players.len() == 3))
    );
}

#[test]
fn hand_won_on_the_flop_keeps_three_board_cards_and_reveals_nobody() {
    let mut state = virtual_hand(&[1000, 1000, 1000]);
    finish_street(&mut state);
    act_active(
        &mut state,
        PlayerAction::Raise {
            to_amount: support::chips(100),
        },
    );
    act_active(&mut state, PlayerAction::Fold);
    act_active(&mut state, PlayerAction::Fold);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    let deal = state.table.deal.as_ref().unwrap();
    assert_eq!(deal.board_shown, 3);
    assert!(deal.revealed.is_empty());
    let result = deal.result.as_ref().unwrap();
    assert!(result.uncontested);
    assert!(
        result
            .pots
            .iter()
            .all(|p| p.winners.len() == 1 && p.shares.len() == 1)
    );
    let winner = &result.pots[0].winners[0];
    assert!(result.pots.iter().all(|p| &p.winners[0] == winner));
}

#[test]
fn result_lists_each_pot_winner_and_shares_summing_to_the_pot() {
    let mut state = virtual_hand(&[100, 100, 100]);
    all_in_everyone(&mut state);
    step(&mut state, Command::BeginShowdown);
    let pots = state.table.pots.clone();
    let allocations = pots
        .iter()
        .map(|p| Allocation {
            pot_index: p.tier_index,
            winners: vec![pid(0)],
        })
        .collect();
    step(&mut state, Command::ResolveShowdown { allocations });
    let result = state.table.deal.as_ref().unwrap().result.clone().unwrap();
    assert!(!result.uncontested);
    assert_eq!(result.pots.len(), pots.len());
    for (pot, tier) in result.pots.iter().zip(&pots) {
        assert_eq!(pot.pot_index, tier.tier_index);
        assert_eq!(pot.amount, tier.amount);
        assert_eq!(pot.winners, vec![pid(0)]);
        let sum: u64 = pot.shares.iter().map(|(_, c)| c.get()).sum();
        assert_eq!(sum, pot.amount.get());
    }
}

#[test]
fn split_pot_result_shows_the_odd_chip_holder() {
    let mut state = virtual_hand(&[33, 33, 33]);
    all_in_everyone(&mut state);
    step(&mut state, Command::BeginShowdown);
    let allocations = vec![Allocation {
        pot_index: 0,
        winners: vec![pid(1), pid(2)],
    }];
    step(&mut state, Command::ResolveShowdown { allocations });
    let result = state.table.deal.as_ref().unwrap().result.clone().unwrap();
    let shares = &result.pots[0].shares;
    assert_eq!(shares.len(), 2);
    assert_eq!(
        shares[0].1.get(),
        50,
        "first clockwise from the button gets the odd chip"
    );
    assert_eq!(shares[1].1.get(), 49);
}

#[test]
fn deal_and_result_survive_a_json_round_trip() {
    let mut state = virtual_hand(&[100, 100, 100]);
    all_in_everyone(&mut state);
    let json = serde_json::to_string(&state).unwrap();
    let back: GameState = serde_json::from_str(&json).unwrap();
    assert_eq!(back, state);
}

#[test]
fn undo_restores_deal_with_the_phase() {
    let mut state = virtual_hand(&[1000, 1000, 1000]);
    finish_street(&mut state);
    assert_eq!(state.table.deal.as_ref().unwrap().board_shown, 3);
    step(&mut state, Command::Undo);
    assert_eq!(state.table.phase, Phase::PreFlop);
    assert_eq!(state.table.deal.as_ref().unwrap().board_shown, 0);
}

#[test]
fn command_with_an_invalid_deck_is_rejected_when_parsed() {
    let json = r#"{"kind":"START_HAND","elapsedMs":0,"deck":["As","As"]}"#;
    assert!(serde_json::from_str::<Command>(json).is_err());
}

#[test]
fn old_start_hand_json_without_deck_deserializes() {
    let command: Command = serde_json::from_str(r#"{"kind":"START_HAND","elapsedMs":5}"#).unwrap();
    assert_eq!(
        command,
        Command::StartHand {
            elapsed_ms: 5,
            deck: None
        }
    );
    let encoded = serde_json::to_string(&command).unwrap();
    assert!(
        !encoded.contains("deck"),
        "physical journals stay byte-identical: {encoded}"
    );
}

#[test]
fn old_table_json_without_deal_deserializes_and_stays_without_it() {
    let state = support::dealt(&[1000, 1000], 1, 2);
    let json = serde_json::to_string(&state).unwrap();
    assert!(
        !json.contains("\"deal\":"),
        "physical snapshots must not gain a deal key"
    );
    let back: GameState = serde_json::from_str(&json).unwrap();
    assert_eq!(back, state);
}

#[test]
fn debug_output_of_a_deal_contains_no_card() {
    let state = virtual_hand(&[1000, 1000, 1000]);
    let deal = state.table.deal.as_ref().unwrap();
    let text = format!("{deal:?} {:?}", state.table);
    for card in all_cards() {
        assert!(!text.contains(&card.to_string()), "{card} leaked in {text}");
    }
}

#[test]
fn the_next_hand_replaces_the_deal_and_physical_hands_clear_it() {
    let mut state = virtual_hand(&[1000, 1000]);
    act_active(&mut state, PlayerAction::Fold);
    assert_eq!(state.table.phase, Phase::NextHandPrep);
    assert!(
        state.table.deal.as_ref().unwrap().result.is_some(),
        "kept after the hand"
    );
    step(
        &mut state,
        Command::StartHand {
            elapsed_ms: 0,
            deck: None,
        },
    );
    assert!(state.table.deal.is_none());
}
