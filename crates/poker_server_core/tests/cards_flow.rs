//! Virtual-card rooms over the actor: who gets which cards, the server-run showdown, and the
//! rules that keep both honest. Plain channels, paused time, scripted shuffles.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::too_many_lines
)]

use std::collections::BTreeSet;
use std::time::Duration;

use poker_engine::card::Card;
use poker_engine::hand_rank::best_of;
use poker_engine::{LegalActions, PlayerAction};
use poker_server_core::cards::{FixedEntropy, shuffled_deck};
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{
    CardMode, ClientMessage, ErrorCode, RoomConfig, RoomView, ServerMessage, WireAllocation,
    WirePhase,
};
use poker_server_core::room::actor::{self, Clock, Created, Deps, ExitReason, NewRoom};
use poker_server_core::room::handle::{ConnId, Outbound, RoomHandle};
use poker_server_core::room::state::{HostCommand, Op, RoomState};
use poker_server_core::store::journal::Journal;
use poker_server_core::store::snapshot;
use poker_server_core::util::token;
use tokio::sync::mpsc;

// -------------------------------------------------------------------------------------------
// Harness
// -------------------------------------------------------------------------------------------

fn config(mode: CardMode) -> RoomConfig {
    RoomConfig {
        card_mode: mode,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 30,
        solo: None,
    }
}

fn script(seed: u8) -> Vec<u8> {
    (0..=255_u8)
        .map(|i| i.wrapping_mul(37).wrapping_add(seed))
        .collect()
}

fn room_with(
    mode: CardMode,
    entropy: FixedEntropy,
    data_dir: Option<std::path::PathBuf>,
) -> Created {
    let new = NewRoom {
        code: "ABCD".into(),
        config: config(mode),
        host_name: "Host".into(),
        data_dir,
    };
    let deps = Deps {
        clock: Clock::new(),
        entropy: Box::new(entropy),
    };
    actor::create_with(new, &Limits::default(), &Timings::default(), deps).unwrap()
}

fn virtual_room() -> Created {
    room_with(CardMode::Virtual, FixedEntropy::new(script(11)), None)
}

fn physical_room() -> Created {
    room_with(CardMode::Physical, FixedEntropy::new(script(11)), None)
}

/// One fake connection that remembers everything it was sent.
struct Client {
    conn: ConnId,
    rx: mpsc::Receiver<Outbound>,
    id: String,
    log: Vec<ServerMessage>,
}

async fn settle() {
    tokio::time::sleep(Duration::from_millis(1)).await;
}

impl Client {
    /// New messages since the last call (also kept in `log`).
    async fn pump(&mut self) -> Vec<ServerMessage> {
        settle().await;
        let mut fresh = Vec::new();
        while let Ok(item) = self.rx.try_recv() {
            fresh.push(item.message);
        }
        self.log.extend(fresh.iter().cloned());
        fresh
    }

    fn hole_cards(&self) -> Vec<[Card; 2]> {
        self.log
            .iter()
            .filter_map(|m| match m {
                ServerMessage::HoleCards { cards, .. } => Some(*cards),
                _ => None,
            })
            .collect()
    }

    fn last_view(&self) -> Option<&RoomView> {
        self.log.iter().rev().find_map(|m| match m {
            ServerMessage::StateUpdate { view, .. } | ServerMessage::Snapshot { view, .. } => {
                Some(view)
            }
            _ => None,
        })
    }

    fn errors(&self) -> Vec<ErrorCode> {
        self.log
            .iter()
            .filter_map(|m| match m {
                ServerMessage::Error { code, .. } => Some(*code),
                _ => None,
            })
            .collect()
    }
}

async fn attach_host(room: &Created, conn: ConnId) -> Client {
    let (tx, rx) = mpsc::channel(256);
    let id = room
        .handle
        .resume(
            conn,
            tx,
            None,
            room.session_token.clone(),
            Some(room.host_token.clone()),
        )
        .await
        .unwrap();
    let mut host = Client {
        conn,
        rx,
        id,
        log: Vec::new(),
    };
    host.pump().await;
    host
}

async fn join_as(
    handle: &RoomHandle,
    conn: ConnId,
    name: &str,
    spectator: bool,
) -> (Client, String) {
    let (tx, rx) = mpsc::channel(256);
    let ok = handle
        .join(conn, tx, Some("j".into()), name.into(), spectator, None)
        .await
        .unwrap();
    let mut client = Client {
        conn,
        rx,
        id: ok.player_id,
        log: Vec::new(),
    };
    client.pump().await;
    (client, ok.session_token)
}

async fn join(handle: &RoomHandle, conn: ConnId, name: &str) -> Client {
    join_as(handle, conn, name, false).await.0
}

async fn send(room: &Created, from: &Client, message: ClientMessage) {
    room.handle
        .send(from.conn, Some("r".into()), message)
        .await
        .unwrap();
}

/// Answers whichever player is prompted until nobody is, so a hand plays out to its end.
async fn play_out(
    room: &Created,
    clients: &mut [&mut Client],
    pick: impl Fn(usize, &LegalActions) -> PlayerAction,
) {
    for step in 0..80 {
        let mut prompt = None;
        for client in clients.iter_mut() {
            for message in client.pump().await {
                if let ServerMessage::TurnPrompt {
                    next_action_seq,
                    legal,
                    ..
                } = message
                {
                    prompt = Some((client.conn, next_action_seq, legal));
                }
            }
        }
        let Some((conn, action_seq, legal)) = prompt else {
            return;
        };
        let action = pick(step, &legal);
        room.handle
            .send(conn, None, ClientMessage::GameAction { action_seq, action })
            .await
            .unwrap();
    }
    panic!("the hand never ended");
}

fn all_in_or_call(_: usize, legal: &LegalActions) -> PlayerAction {
    if legal.can_raise {
        PlayerAction::AllIn
    } else {
        PlayerAction::Call
    }
}

fn check_or_call(_: usize, legal: &LegalActions) -> PlayerAction {
    if legal.can_check {
        PlayerAction::Check
    } else {
        PlayerAction::Call
    }
}

/// Whether any message other than the owner's `HOLE_CARDS` mentions one of these cards.
fn mentions(messages: &[ServerMessage], cards: &[Card]) -> bool {
    messages
        .iter()
        .filter(|m| !matches!(m, ServerMessage::HoleCards { .. }))
        .any(|m| {
            let json = serde_json::to_string(m).unwrap();
            cards
                .iter()
                .any(|card| json.contains(&format!("\"{card}\"")))
        })
}

/// A finished hand: the next-hand screen, or the lobby when somebody lost every chip.
fn is_between_hands(view: &RoomView) -> bool {
    matches!(view.phase, WirePhase::NextHandPrep | WirePhase::Lobby)
}

fn chips_of(view: &RoomView) -> u64 {
    view.seats.iter().map(|s| s.chips).sum()
}

/// Three players at a virtual table, the hand not started.
async fn table_of_three() -> (Created, Client, Client, Client) {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    let mut cy = join(&room.handle, 3, "Cy").await;
    host.pump().await;
    bob.pump().await;
    cy.pump().await;
    (room, host, bob, cy)
}

async fn table_of_two() -> (Created, Client, Client) {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    host.pump().await;
    bob.pump().await;
    (room, host, bob)
}

// -------------------------------------------------------------------------------------------
// Dealing: private cards stay private
// -------------------------------------------------------------------------------------------

#[tokio::test(start_paused = true)]
async fn start_hand_sends_hole_cards_only_to_each_owner() {
    let (room, mut host, mut bob, mut cy) = table_of_three().await;
    send(&room, &host, ClientMessage::StartHand).await;
    for client in [&mut host, &mut bob, &mut cy] {
        client.pump().await;
    }
    let mut seen = BTreeSet::new();
    for client in [&host, &bob, &cy] {
        let own = client.hole_cards();
        assert_eq!(own.len(), 1, "{} gets exactly one deal", client.id);
        assert_ne!(own[0][0], own[0][1]);
        for card in own[0] {
            assert!(seen.insert(card), "a card was dealt twice");
        }
    }
    for (client, others) in [
        (&host, [&bob, &cy]),
        (&bob, [&host, &cy]),
        (&cy, [&host, &bob]),
    ] {
        let theirs: Vec<Card> = others.iter().flat_map(|o| o.hole_cards()[0]).collect();
        assert!(
            !mentions(&client.log, &theirs),
            "{} saw somebody else's card",
            client.id
        );
    }
}

#[tokio::test(start_paused = true)]
async fn spectator_never_receives_hole_cards() {
    let (room, mut host, mut bob) = table_of_two().await;
    let (mut watcher, _) = join_as(&room.handle, 9, "Eve", true).await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], check_or_call).await;
    watcher.pump().await;
    assert!(watcher.hole_cards().is_empty());
    let dealt: Vec<Card> = [&host, &bob]
        .iter()
        .flat_map(|c| c.hole_cards()[0])
        .collect();
    // Hole cards may appear to a spectator only through the public reveals at showdown.
    let view = watcher.last_view().unwrap();
    let revealed: BTreeSet<Card> = view.reveals.iter().flat_map(|r| r.cards).collect();
    for card in dealt {
        if !revealed.contains(&card) {
            assert!(
                !mentions(&watcher.log, &[card]),
                "{card} leaked to a spectator"
            );
        }
    }
}

#[tokio::test(start_paused = true)]
async fn state_update_never_contains_hole_cards() {
    let (room, mut host, mut bob, mut cy) = table_of_three().await;
    send(&room, &host, ClientMessage::StartHand).await;
    for client in [&mut host, &mut bob, &mut cy] {
        client.pump().await;
    }
    let dealt: Vec<Card> = [&host, &bob, &cy]
        .iter()
        .flat_map(|c| c.hole_cards()[0])
        .collect();
    for client in [&host, &bob, &cy] {
        let views = client
            .log
            .iter()
            .filter(|m| {
                matches!(
                    m,
                    ServerMessage::StateUpdate { .. } | ServerMessage::Snapshot { .. }
                )
            })
            .cloned()
            .collect::<Vec<_>>();
        assert!(!views.is_empty());
        assert!(!mentions(&views, &dealt), "a view carried a hole card");
        let view = client.last_view().unwrap();
        assert!(view.board.is_empty(), "no board before the flop");
        assert!(view.reveals.is_empty());
        assert!(view.seats.iter().all(|s| s.has_cards));
    }
}

#[tokio::test(start_paused = true)]
async fn resume_resends_hole_cards_after_the_snapshot() {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    let (mut bob, bob_token) = join_as(&room.handle, 2, "Bob", false).await;
    host.pump().await;
    send(&room, &host, ClientMessage::StartHand).await;
    bob.pump().await;
    let before = bob.hole_cards()[0];
    room.handle.detach(bob.conn);
    host.pump().await;

    let (tx, rx) = mpsc::channel(256);
    room.handle
        .resume(22, tx, Some("again".into()), bob_token, None)
        .await
        .unwrap();
    let mut again = Client {
        conn: 22,
        rx,
        id: bob.id.clone(),
        log: Vec::new(),
    };
    again.pump().await;
    let snapshot_at = again
        .log
        .iter()
        .position(|m| matches!(m, ServerMessage::Snapshot { .. }))
        .expect("snapshot");
    let cards_at = again
        .log
        .iter()
        .position(|m| matches!(m, ServerMessage::HoleCards { .. }))
        .expect("the cards come back");
    assert!(cards_at > snapshot_at, "cards follow the snapshot");
    assert_eq!(again.hole_cards(), vec![before]);
}

#[tokio::test(start_paused = true)]
async fn superseded_connection_gets_no_cards() {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    let (mut bob, bob_token) = join_as(&room.handle, 2, "Bob", false).await;
    let (tx, rx) = mpsc::channel(256);
    room.handle
        .resume(30, tx, None, bob_token, None)
        .await
        .unwrap();
    let mut second = Client {
        conn: 30,
        rx,
        id: bob.id.clone(),
        log: Vec::new(),
    };
    second.pump().await;
    host.pump().await;

    send(&room, &host, ClientMessage::StartHand).await;
    second.pump().await;
    bob.pump().await;
    assert_eq!(
        second.hole_cards().len(),
        1,
        "the live connection gets the cards"
    );
    assert!(bob.hole_cards().is_empty(), "the superseded one gets none");
    assert!(bob.errors().contains(&ErrorCode::Superseded));
}

// -------------------------------------------------------------------------------------------
// The server's showdown
// -------------------------------------------------------------------------------------------

/// The winners the board and reveals imply, worked out here with the ranking function only.
fn expected_winners(view: &RoomView) -> BTreeSet<String> {
    let ranked: Vec<(String, poker_engine::hand_rank::HandRank)> = view
        .reveals
        .iter()
        .map(|reveal| {
            let mut seven: Vec<Card> = reveal.cards.to_vec();
            seven.extend(view.board.iter().copied());
            (reveal.player_id.clone(), best_of(&seven).unwrap())
        })
        .collect();
    let top = ranked.iter().map(|(_, rank)| *rank).max().unwrap();
    ranked
        .into_iter()
        .filter(|(_, rank)| *rank == top)
        .map(|(id, _)| id)
        .collect()
}

#[tokio::test(start_paused = true)]
async fn all_in_runout_resolves_automatically_and_pays_by_rank() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], all_in_or_call).await;
    host.pump().await;
    let view = host.last_view().unwrap().clone();
    assert!(
        is_between_hands(&view),
        "nobody had to resolve it: {:?}",
        view.phase
    );
    assert_eq!(view.board.len(), 5);
    assert_eq!(view.reveals.len(), 2);
    assert_eq!(chips_of(&view), 2000, "chips are conserved");
    let result = view.result.clone().expect("a result");
    assert!(!result.uncontested);
    let winners: BTreeSet<String> = result
        .pots
        .iter()
        .flat_map(|pot| pot.winner_player_ids.clone())
        .collect();
    assert_eq!(winners, expected_winners(&view));
    let paid: u64 = result
        .pots
        .iter()
        .flat_map(|p| &p.shares)
        .map(|s| s.amount)
        .sum();
    assert_eq!(paid, 2000);
    for pot in &result.pots {
        assert!(pot.shares.iter().all(|share| !share.name.is_empty()));
    }
}

#[tokio::test(start_paused = true)]
async fn uncontested_hand_reveals_nothing() {
    let (room, mut host, mut bob, mut cy) = table_of_three().await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob, &mut cy], |_, legal| {
        if legal.can_check {
            PlayerAction::Check
        } else {
            PlayerAction::Fold
        }
    })
    .await;
    host.pump().await;
    let view = host.last_view().unwrap();
    assert_eq!(view.phase, WirePhase::NextHandPrep);
    assert!(
        view.reveals.is_empty(),
        "nobody has to show a winning hand nobody called"
    );
    assert!(view.board.is_empty());
    let result = view.result.as_ref().expect("the pot is still reported");
    assert!(result.uncontested);
    assert_eq!(chips_of(view), 3000);
}

/// A deck whose five board cards are a royal flush: every contender plays the board and ties.
fn royal_board_script(players: usize) -> Vec<u8> {
    let royal: Vec<Card> = ["As", "Ks", "Qs", "Js", "Ts"]
        .iter()
        .map(|s| s.parse().unwrap())
        .collect();
    let rest: Vec<Card> = poker_engine::deck::Deck::standard()
        .cards()
        .iter()
        .copied()
        .filter(|card| !royal.contains(card))
        .collect();
    let mut wanted: Vec<Card> = rest[..players * 2].to_vec();
    wanted.extend(royal);
    wanted.extend(rest[players * 2..].iter().copied());
    // Invert the Fisher-Yates in `shuffled_deck`: one byte per step, the position to swap from.
    let mut working: Vec<Card> = poker_engine::deck::Deck::standard().cards().to_vec();
    let mut bytes = Vec::new();
    for end in (1..wanted.len()).rev() {
        let pick = working[..=end]
            .iter()
            .position(|c| *c == wanted[end])
            .unwrap();
        bytes.push(u8::try_from(pick).unwrap());
        working.swap(end, pick);
    }
    assert_eq!(working, wanted);
    let check = shuffled_deck(&mut FixedEntropy::new(bytes.clone())).unwrap();
    assert_eq!(check.cards(), wanted.as_slice());
    bytes
}

#[tokio::test(start_paused = true)]
async fn split_pot_with_odd_chip_over_the_actor() {
    let room = room_with(
        CardMode::Virtual,
        FixedEntropy::new(royal_board_script(3)),
        None,
    );
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    let mut cy = join(&room.handle, 3, "Cy").await;
    send(&room, &host, ClientMessage::StartHand).await;
    // Button shoves, the small blind gives up its blind, the big blind calls: 5 chips of dead
    // money make the pot odd (2005), and the board ties the two that are left.
    play_out(
        &room,
        &mut [&mut host, &mut bob, &mut cy],
        |step, legal| match step {
            0 => PlayerAction::AllIn,
            1 => PlayerAction::Fold,
            _ => {
                if legal.can_call {
                    PlayerAction::Call
                } else {
                    PlayerAction::Check
                }
            }
        },
    )
    .await;
    host.pump().await;
    let view = host.last_view().unwrap();
    assert_eq!(view.phase, WirePhase::NextHandPrep);
    assert_eq!(chips_of(view), 3000);
    let result = view.result.as_ref().unwrap();
    let main = &result.pots[0];
    assert_eq!(main.amount, 2005);
    assert_eq!(main.winner_player_ids.len(), 2, "the board ties them");
    let mut shares: Vec<u64> = main.shares.iter().map(|s| s.amount).collect();
    shares.sort_unstable();
    assert_eq!(shares, vec![1002, 1003], "the odd chip goes to one of them");
}

// -------------------------------------------------------------------------------------------
// Host controls that real cards need and virtual cards must not allow
// -------------------------------------------------------------------------------------------

#[tokio::test(start_paused = true)]
async fn host_begin_showdown_and_resolve_are_illegal_state_in_virtual_rooms() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    host.pump().await;
    send(&room, &host, ClientMessage::BeginShowdown).await;
    send(
        &room,
        &host,
        ClientMessage::ResolveShowdown {
            allocations: vec![WireAllocation {
                pot_index: 0,
                winner_player_ids: vec![bob.id.clone()],
            }],
        },
    )
    .await;
    host.pump().await;
    assert_eq!(
        host.errors(),
        vec![ErrorCode::IllegalState, ErrorCode::IllegalState]
    );
    bob.pump().await;
}

#[tokio::test(start_paused = true)]
async fn physical_room_manual_showdown_still_works() {
    let room = physical_room();
    let mut host = attach_host(&room, 1).await;
    let mut bob = join(&room.handle, 2, "Bob").await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], all_in_or_call).await;
    host.pump().await;
    assert_eq!(host.last_view().unwrap().phase, WirePhase::AllInRunout);
    assert!(
        host.hole_cards().is_empty(),
        "a physical room deals nothing"
    );
    send(&room, &host, ClientMessage::BeginShowdown).await;
    host.pump().await;
    assert_eq!(host.last_view().unwrap().phase, WirePhase::Showdown);
    let host_id = host.id.clone();
    send(
        &room,
        &host,
        ClientMessage::ResolveShowdown {
            allocations: vec![WireAllocation {
                pot_index: 0,
                winner_player_ids: vec![host_id],
            }],
        },
    )
    .await;
    host.pump().await;
    let view = host.last_view().unwrap();
    assert!(is_between_hands(view));
    assert!(view.result.is_none() && view.reveals.is_empty() && view.board.is_empty());
}

#[tokio::test(start_paused = true)]
async fn undo_is_allowed_within_a_street_and_refused_across_streets_and_after_showdown() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    // One action in the pre-flop round, then take it back: same street, so it works.
    let mut first = None;
    for client in [&mut host, &mut bob] {
        for message in client.pump().await {
            if let ServerMessage::TurnPrompt {
                next_action_seq, ..
            } = message
            {
                first = Some((client.conn, next_action_seq));
            }
        }
    }
    let (conn, action_seq) = first.expect("someone is prompted");
    room.handle
        .send(
            conn,
            None,
            ClientMessage::GameAction {
                action_seq,
                action: PlayerAction::Call,
            },
        )
        .await
        .unwrap();
    host.pump().await;
    bob.pump().await;
    send(&room, &host, ClientMessage::Undo).await;
    let mut after_undo = host.pump().await;
    after_undo.extend(bob.pump().await);
    assert!(host.errors().is_empty(), "undo inside the street is fine");

    // Play the hand to its end with nobody losing everything, then try to undo after showdown.
    let again = after_undo.iter().find_map(|message| match message {
        ServerMessage::TurnPrompt {
            player_id,
            next_action_seq,
            legal,
            ..
        } => Some((
            if *player_id == host.id {
                host.conn
            } else {
                bob.conn
            },
            *next_action_seq,
            *legal,
        )),
        _ => None,
    });
    let (conn, action_seq, legal) = again.expect("the player is prompted again after undo");
    room.handle
        .send(
            conn,
            None,
            ClientMessage::GameAction {
                action_seq,
                action: check_or_call(0, &legal),
            },
        )
        .await
        .unwrap();
    play_out(&room, &mut [&mut host, &mut bob], check_or_call).await;
    host.pump().await;
    assert_eq!(host.last_view().unwrap().phase, WirePhase::NextHandPrep);
    send(&room, &host, ClientMessage::Undo).await;
    host.pump().await;
    assert!(host.errors().contains(&ErrorCode::IllegalState));
    assert_eq!(host.last_view().unwrap().phase, WirePhase::NextHandPrep);
}

#[tokio::test(start_paused = true)]
async fn undo_across_a_street_boundary_is_refused() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    // Heads-up pre-flop: the button calls and the big blind checks, which opens the flop.
    for _ in 0..2 {
        let mut prompted = None;
        for client in [&mut host, &mut bob] {
            for message in client.pump().await {
                if let ServerMessage::TurnPrompt {
                    next_action_seq,
                    legal,
                    ..
                } = message
                {
                    prompted = Some((client.conn, next_action_seq, legal));
                }
            }
        }
        let (conn, action_seq, legal) = prompted.unwrap();
        room.handle
            .send(
                conn,
                None,
                ClientMessage::GameAction {
                    action_seq,
                    action: check_or_call(0, &legal),
                },
            )
            .await
            .unwrap();
    }
    host.pump().await;
    assert_eq!(host.last_view().unwrap().phase, WirePhase::Flop);
    assert_eq!(host.last_view().unwrap().board.len(), 3);
    send(&room, &host, ClientMessage::Undo).await;
    host.pump().await;
    assert!(host.errors().contains(&ErrorCode::IllegalState));
    assert_eq!(
        host.last_view().unwrap().board.len(),
        3,
        "the flop stays on the table"
    );
}

// -------------------------------------------------------------------------------------------
// Starting a hand
// -------------------------------------------------------------------------------------------

#[tokio::test(start_paused = true)]
async fn double_start_hand_deals_once() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    send(&room, &host, ClientMessage::StartHand).await;
    host.pump().await;
    bob.pump().await;
    assert_eq!(host.hole_cards().len(), 1);
    assert_eq!(bob.hole_cards().len(), 1);
    assert_eq!(host.errors(), vec![ErrorCode::HandInProgress]);
    assert_eq!(host.last_view().unwrap().hand_number, 1);
}

#[tokio::test(start_paused = true)]
async fn rejected_start_hand_changes_nothing_and_sends_no_cards() {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    let before = host.last_view().unwrap().clone();
    send(&room, &host, ClientMessage::StartHand).await;
    let got = host.pump().await;
    assert!(got.iter().any(|m| matches!(m, ServerMessage::Error { .. })));
    assert!(got.iter().all(|m| !matches!(
        m,
        ServerMessage::HoleCards { .. } | ServerMessage::StateUpdate { .. }
    )));
    assert!(host.hole_cards().is_empty());
    // And the room still works: a second player makes the next start succeed.
    let mut bob = join(&room.handle, 2, "Bob").await;
    host.pump().await;
    send(&room, &host, ClientMessage::StartHand).await;
    host.pump().await;
    bob.pump().await;
    assert_eq!(bob.hole_cards().len(), 1);
    assert_eq!(before.hand_number, 0);
}

#[tokio::test(start_paused = true)]
async fn client_sent_start_hand_with_deck_field_is_ignored() {
    let json = serde_json::json!({
        "v": 1,
        "type": "START_HAND",
        "deck": ["As", "Ks", "Qs"],
    });
    let parsed: ClientMessage = serde_json::from_value(json).unwrap();
    assert!(matches!(parsed, ClientMessage::StartHand));

    // Two rooms with different shuffles deal differently whatever the host's frames say.
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, parsed).await;
    host.pump().await;
    bob.pump().await;
    let dealt = host.hole_cards()[0];
    let expected = shuffled_deck(&mut FixedEntropy::new(script(11))).unwrap();
    let stacked = poker_engine::deck::Deck::standard();
    assert_ne!(expected.cards(), stacked.cards());
    let all: BTreeSet<Card> = expected.cards().iter().copied().collect();
    assert!(dealt.iter().all(|card| all.contains(card)));
    assert_ne!(
        [dealt[0], dealt[1]],
        [stacked.cards()[0], stacked.cards()[1]],
        "the deck came from the server's entropy, not from the wire"
    );
}

// -------------------------------------------------------------------------------------------
// Configuration, late viewers and what stays on the table
// -------------------------------------------------------------------------------------------

#[tokio::test(start_paused = true)]
async fn card_mode_cannot_be_changed_by_configure() {
    let room = virtual_room();
    let mut host = attach_host(&room, 1).await;
    send(
        &room,
        &host,
        ClientMessage::RoomConfigure {
            config: config(CardMode::Physical),
        },
    )
    .await;
    host.pump().await;
    let info = room.handle.info().await.unwrap();
    assert_eq!(info.card_mode, CardMode::Virtual);
}

#[tokio::test(start_paused = true)]
async fn late_spectator_sees_board_and_reveals_of_the_last_hand() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], all_in_or_call).await;
    host.pump().await;

    let (watcher, _) = join_as(&room.handle, 9, "Eve", true).await;
    let view = watcher.last_view().unwrap();
    assert_eq!(view.board.len(), 5);
    assert_eq!(view.reveals.len(), 2);
    assert!(view.result.is_some());
    assert!(watcher.hole_cards().is_empty());
}

#[tokio::test(start_paused = true)]
async fn snapshot_after_the_hand_carries_result_reveals_and_board() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], all_in_or_call).await;
    room.handle.detach(bob.conn);
    let (tx, rx) = mpsc::channel(256);
    room.handle
        .resume(
            40,
            tx,
            None,
            room.session_token.clone(),
            Some(room.host_token.clone()),
        )
        .await
        .unwrap();
    let mut back = Client {
        conn: 40,
        rx,
        id: host.id.clone(),
        log: Vec::new(),
    };
    back.pump().await;
    let view = back.last_view().unwrap();
    assert_eq!(view.board.len(), 5);
    assert_eq!(view.reveals.len(), 2);
    assert!(view.result.is_some());
    assert_eq!(
        back.hole_cards().len(),
        1,
        "own cards of the finished hand come back too"
    );
}

#[tokio::test(start_paused = true)]
async fn result_stays_until_the_next_start_hand() {
    let (room, mut host, mut bob) = table_of_two().await;
    send(&room, &host, ClientMessage::StartHand).await;
    play_out(&room, &mut [&mut host, &mut bob], check_or_call).await;
    host.pump().await;
    assert!(host.last_view().unwrap().result.is_some());
    // Time passing does not clear it.
    tokio::time::sleep(Duration::from_mins(2)).await;
    host.pump().await;
    assert!(host.last_view().unwrap().result.is_some());

    send(&room, &host, ClientMessage::StartHand).await;
    host.pump().await;
    let view = host.last_view().unwrap();
    assert!(view.result.is_none());
    assert!(view.reveals.is_empty());
    assert!(view.board.is_empty());
    assert_eq!(
        host.hole_cards().len(),
        2,
        "a new deal replaces the old cards"
    );
}

// -------------------------------------------------------------------------------------------
// Crash between the last bet and the payout
// -------------------------------------------------------------------------------------------

/// Journals and applies an op the way the actor does: journal first, then swap the state in.
fn run(live: &mut RoomState, journal: &mut Journal, timings: &Timings, op: Op) {
    let mut next = live.clone();
    journal.append(&op).unwrap();
    next.apply(op, timings).unwrap();
    *live = next;
}

#[tokio::test(start_paused = true)]
async fn restore_between_street_end_and_auto_showdown_completes_the_hand() {
    let dir = tempfile::tempdir().unwrap();
    let timings = Timings::default();
    let cfg = config(CardMode::Virtual);
    let host_token = "host-token";
    let host_session = "host-session";
    let mut live = RoomState::new(
        "ABCD".into(),
        cfg,
        "Host",
        token::hash(host_token),
        token::hash(host_session),
        0,
    )
    .unwrap();
    snapshot::write(dir.path(), &live, 0).unwrap();
    let mut journal = Journal::open(dir.path(), 0).unwrap();
    run(
        &mut live,
        &mut journal,
        &timings,
        Op::Join {
            player_id: "p_2".into(),
            name: "Bob".into(),
            spectator: false,
            seat: None,
            token_hash: token::hash("bob-session"),
            at_ms: 1,
        },
    );
    let deck = shuffled_deck(&mut FixedEntropy::new(script(5))).unwrap();
    run(
        &mut live,
        &mut journal,
        &timings,
        Op::Host {
            by: "p_1".into(),
            command: HostCommand::StartHand { deck: Some(deck) },
            at_ms: 2,
        },
    );
    // Both shove; the ending op is journaled, the payout never was: the process died here.
    let mut seq = [0_u64, 0_u64];
    for at_ms in [3, 4] {
        let (seat, _) = live.game.legal_actions().unwrap();
        let (id, index) = if live.players["p_1"].seat == Some(seat.get()) {
            ("p_1", 0)
        } else {
            ("p_2", 1)
        };
        run(
            &mut live,
            &mut journal,
            &timings,
            Op::Act {
                player_id: id.into(),
                action_seq: seq[index],
                action: PlayerAction::AllIn,
                at_ms,
            },
        );
        seq[index] += 1;
    }
    assert!(
        live.needs_auto_showdown(),
        "the hand is waiting for its payout"
    );
    drop(journal);

    let finish = |dir: &std::path::Path| {
        let deps = Deps {
            clock: Clock::new(),
            entropy: Box::new(FixedEntropy::new(script(5))),
        };
        actor::restore_with(dir.to_path_buf(), &Limits::default(), &timings, deps).unwrap()
    };
    let (handle, task) = finish(dir.path());
    let (tx, rx) = mpsc::channel(256);
    handle
        .resume(1, tx, None, host_session.into(), Some(host_token.into()))
        .await
        .unwrap();
    let mut host = Client {
        conn: 1,
        rx,
        id: "p_1".into(),
        log: Vec::new(),
    };
    host.pump().await;
    let view = host.last_view().unwrap().clone();
    assert!(
        is_between_hands(&view),
        "restore finished the hand: {:?}",
        view.phase
    );
    assert_eq!(chips_of(&view), 2000, "no chips lost");
    assert!(view.result.is_some());
    let stacks: Vec<u64> = view.seats.iter().map(|s| s.chips).collect();

    // Killed again after the payout: the second restore must not pay a second time.
    handle.close().await;
    assert_eq!(task.await.unwrap(), ExitReason::Closed);
    let (handle, task) = finish(dir.path());
    let (tx, rx) = mpsc::channel(256);
    handle
        .resume(2, tx, None, host_session.into(), Some(host_token.into()))
        .await
        .unwrap();
    let mut again = Client {
        conn: 2,
        rx,
        id: "p_1".into(),
        log: Vec::new(),
    };
    again.pump().await;
    let view = again.last_view().unwrap();
    assert!(is_between_hands(view));
    assert_eq!(
        view.seats.iter().map(|s| s.chips).collect::<Vec<_>>(),
        stacks
    );
    handle.close().await;
    let _ = task.await;
}

// -------------------------------------------------------------------------------------------
// The reducer itself
// -------------------------------------------------------------------------------------------

/// A virtual room whose betting just ended with everybody all in, payout not yet applied.
fn state_waiting_for_payout() -> RoomState {
    let timings = Timings::default();
    let mut state = RoomState::new(
        "ABCD".into(),
        config(CardMode::Virtual),
        "Host",
        token::hash("h"),
        token::hash("hs"),
        0,
    )
    .unwrap();
    let step = |state: &mut RoomState, op: Op| {
        state.apply(op, &timings).unwrap();
    };
    step(
        &mut state,
        Op::Join {
            player_id: "p_2".into(),
            name: "Bob".into(),
            spectator: false,
            seat: None,
            token_hash: token::hash("b"),
            at_ms: 1,
        },
    );
    let deck = shuffled_deck(&mut FixedEntropy::new(script(9))).unwrap();
    step(
        &mut state,
        Op::Host {
            by: "p_1".into(),
            command: HostCommand::StartHand { deck: Some(deck) },
            at_ms: 2,
        },
    );
    let mut seq = [0_u64; 2];
    for at_ms in [3, 4] {
        let (seat, _) = state.game.legal_actions().unwrap();
        let index = usize::from(state.players["p_2"].seat == Some(seat.get()));
        let id = ["p_1", "p_2"][index];
        step(
            &mut state,
            Op::Act {
                player_id: id.into(),
                action_seq: seq[index],
                action: PlayerAction::AllIn,
                at_ms,
            },
        );
        seq[index] += 1;
    }
    assert!(state.needs_auto_showdown());
    state
}

#[test]
fn manual_showdown_commands_are_refused_even_when_the_engine_would_accept_them() {
    let timings = Timings::default();
    for command in [
        HostCommand::BeginShowdown,
        HostCommand::ResolveShowdown {
            allocations: vec![WireAllocation {
                pot_index: 0,
                winner_player_ids: vec!["p_1".into()],
            }],
        },
    ] {
        let mut state = state_waiting_for_payout();
        let before = state.clone();
        let error = state
            .apply(
                Op::Host {
                    by: "p_1".into(),
                    command,
                    at_ms: 10,
                },
                &timings,
            )
            .unwrap_err();
        assert_eq!(error.code, ErrorCode::IllegalState);
        assert!(error.message.contains("automatically"), "{}", error.message);
        assert_eq!(state.game.table.phase, before.game.table.phase);
    }
}

#[test]
fn the_server_payout_is_the_only_way_out_of_a_virtual_runout() {
    let timings = Timings::default();
    let mut state = state_waiting_for_payout();
    let op = state
        .auto_showdown_op(11)
        .unwrap()
        .expect("a payout is due");
    state.apply(op.clone(), &timings).unwrap();
    assert!(!state.needs_auto_showdown());
    // Replaying the same op later pays nothing a second time.
    let before = state.clone();
    assert!(state.apply(op, &timings).is_err());
    assert_eq!(state, before);
    let total: u64 = state.game.table.seats.iter().map(|s| s.chips.get()).sum();
    assert_eq!(total, 2000);
}
