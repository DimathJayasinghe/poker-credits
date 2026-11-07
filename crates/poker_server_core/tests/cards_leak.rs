//! The no-leak oracle: many random virtual games (joins, reconnects, second devices, folds,
//! all-ins, seat moves, kicks and new players between hands), every frame every connection
//! received is recorded, and none may show a hole card its owner has not revealed.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::too_many_lines
)]

use std::collections::{BTreeMap, BTreeSet};
use std::time::Duration;

use poker_engine::LegalActions;
use poker_engine::PlayerAction;
use poker_engine::card::Card;
use poker_server_core::cards::FixedEntropy;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::protocol::{
    CardMode, ClientMessage, RoomConfig, RoomView, ServerMessage, WirePhase,
};
use poker_server_core::room::actor::{self, Clock, Created, Deps, NewRoom};
use poker_server_core::room::handle::{ConnId, Outbound};
use serde_json::Value;
use tokio::sync::mpsc;

// -------------------------------------------------------------------------------------------
// The oracle
// -------------------------------------------------------------------------------------------

/// Everything one connection was ever sent.
struct Conn {
    id: ConnId,
    rx: mpsc::Receiver<Outbound>,
    player: String,
    log: Vec<ServerMessage>,
}

impl Conn {
    fn pump(&mut self) -> Vec<ServerMessage> {
        let mut fresh = Vec::new();
        while let Ok(item) = self.rx.try_recv() {
            fresh.push(item.message);
        }
        self.log.extend(fresh.iter().cloned());
        fresh
    }
}

fn cards_in(value: &Value, found: &mut BTreeSet<Card>) {
    match value {
        Value::String(text) => {
            if let Ok(card) = text.parse::<Card>() {
                found.insert(card);
            }
        }
        Value::Array(items) => items.iter().for_each(|v| cards_in(v, found)),
        Value::Object(map) => map.values().for_each(|v| cards_in(v, found)),
        _ => {}
    }
}

fn cards_of(message: &ServerMessage) -> BTreeSet<Card> {
    let mut found = BTreeSet::new();
    cards_in(&serde_json::to_value(message).unwrap(), &mut found);
    found
}

/// Cards a view is allowed to show: the board and the hands revealed at showdown.
fn public_cards(view: &RoomView) -> BTreeSet<Card> {
    let mut open: BTreeSet<Card> = view.board.iter().copied().collect();
    for reveal in &view.reveals {
        open.extend(reveal.cards);
        open.extend(reveal.best_five);
    }
    open
}

fn view_of(message: &ServerMessage) -> Option<&RoomView> {
    match message {
        ServerMessage::StateUpdate { view, .. } | ServerMessage::Snapshot { view, .. } => {
            Some(view)
        }
        _ => None,
    }
}

/// Checks every recorded frame. `Err` names the first leak or inconsistency.
fn audit(conns: &[Conn]) -> Result<(), String> {
    // Who was dealt what, from their own private messages.
    let mut dealt: BTreeMap<(String, u32), BTreeSet<Card>> = BTreeMap::new();
    for conn in conns {
        for message in &conn.log {
            if let ServerMessage::HoleCards { hand_number, cards } = message {
                let own: BTreeSet<Card> = cards.iter().copied().collect();
                let entry = dealt
                    .entry((conn.player.clone(), *hand_number))
                    .or_insert_with(|| own.clone());
                if *entry != own {
                    return Err(format!(
                        "{} was dealt two different hands in hand {hand_number}",
                        conn.player
                    ));
                }
            }
        }
    }
    // Nobody shares a card within a hand.
    let mut by_hand: BTreeMap<u32, BTreeSet<Card>> = BTreeMap::new();
    for ((player, hand), cards) in &dealt {
        let seen = by_hand.entry(*hand).or_default();
        if let Some(twice) = cards.iter().find(|c| seen.contains(c)) {
            return Err(format!(
                "{player} got {twice} which was already dealt in hand {hand}"
            ));
        }
        seen.extend(cards.iter().copied());
    }
    for conn in conns {
        for message in &conn.log {
            match view_of(message) {
                Some(view) => {
                    // A board card is a card nobody holds: a hole card shown as board is a leak.
                    let held = by_hand.get(&view.hand_number);
                    if let Some(held_card) = view
                        .board
                        .iter()
                        .find(|c| held.is_some_and(|h| h.contains(c)))
                    {
                        return Err(format!(
                            "{} saw {held_card} on the board of hand {} but it is somebody's hole card",
                            conn.player, view.hand_number
                        ));
                    }
                    // The board is dealt face down: a street's cards exist only once it is reached.
                    let allowed = match view.phase {
                        WirePhase::PreFlop => Some(0),
                        WirePhase::Flop => Some(3),
                        WirePhase::Turn => Some(4),
                        _ => None,
                    };
                    if allowed.is_some_and(|n| view.board.len() != n) {
                        return Err(format!(
                            "{} saw {} board cards in {:?}",
                            conn.player,
                            view.board.len(),
                            view.phase
                        ));
                    }
                    let open = public_cards(view);
                    let shown = cards_of(message);
                    if let Some(extra) = shown.difference(&open).next() {
                        return Err(format!(
                            "{} saw {extra} in a view of hand {} that is neither board nor revealed",
                            conn.player, view.hand_number
                        ));
                    }
                    for reveal in &view.reveals {
                        let key = (reveal.player_id.clone(), view.hand_number);
                        if let Some(own) = dealt.get(&key) {
                            let shown: BTreeSet<Card> = reveal.cards.iter().copied().collect();
                            if *own != shown {
                                return Err(format!(
                                    "{} revealed cards they were not dealt",
                                    key.0
                                ));
                            }
                        }
                    }
                }
                None => {
                    if !matches!(message, ServerMessage::HoleCards { .. })
                        && let Some(card) = cards_of(message).into_iter().next()
                    {
                        return Err(format!("{} got {card} in a non-card message", conn.player));
                    }
                }
            }
        }
    }
    Ok(())
}

// -------------------------------------------------------------------------------------------
// The world
// -------------------------------------------------------------------------------------------

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: usize) -> usize {
        usize::try_from(self.next() % u64::try_from(n).unwrap()).unwrap()
    }
}

struct World {
    room: Created,
    conns: Vec<Conn>,
    tokens: BTreeMap<String, String>,
    next_conn: ConnId,
    next_name: u32,
    rng: Rng,
    hands: u32,
}

fn config() -> RoomConfig {
    RoomConfig {
        card_mode: CardMode::Virtual,
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

async fn settle() {
    tokio::time::sleep(Duration::from_millis(1)).await;
}

impl World {
    async fn new(seed: u64) -> World {
        let script: Vec<u8> = (0..=255_u8)
            .map(|i| {
                i.wrapping_mul(61)
                    .wrapping_add(u8::try_from(seed % 251).unwrap())
            })
            .collect();
        let new = NewRoom {
            code: "LEAK".into(),
            config: config(),
            host_name: "Host".into(),
            data_dir: None,
        };
        let deps = Deps {
            clock: Clock::new(),
            entropy: Box::new(FixedEntropy::new(script)),
        };
        let room = actor::create_with(new, &Limits::default(), &Timings::default(), deps).unwrap();
        let mut world = World {
            conns: Vec::new(),
            tokens: BTreeMap::new(),
            next_conn: 1,
            next_name: 0,
            rng: Rng(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1),
            hands: 0,
            room,
        };
        let host_id = world.room.player_id.clone();
        world
            .tokens
            .insert(host_id.clone(), world.room.session_token.clone());
        world.attach(&host_id).await;
        world
    }

    fn conn_id(&mut self) -> ConnId {
        self.next_conn += 1;
        self.next_conn
    }

    /// Opens a connection for an existing participant (the host needs its second token too).
    async fn attach(&mut self, player: &str) {
        let id = self.conn_id();
        let (tx, rx) = mpsc::channel(512);
        let host_token = (player == self.room.player_id).then(|| self.room.host_token.clone());
        let token = self.tokens[player].clone();
        if self
            .room
            .handle
            .resume(id, tx, None, token, host_token)
            .await
            .is_ok()
        {
            self.conns.push(Conn {
                id,
                rx,
                player: player.to_owned(),
                log: Vec::new(),
            });
        }
    }

    async fn add_player(&mut self, spectator: bool) {
        self.next_name += 1;
        let id = self.conn_id();
        let (tx, rx) = mpsc::channel(512);
        let name = format!("pl_{}", self.next_name);
        if let Ok(ok) = self
            .room
            .handle
            .join(id, tx, None, name, spectator, None)
            .await
        {
            self.tokens.insert(ok.player_id.clone(), ok.session_token);
            self.conns.push(Conn {
                id,
                rx,
                player: ok.player_id,
                log: Vec::new(),
            });
        }
    }

    async fn pump(&mut self) -> Vec<(usize, ServerMessage)> {
        settle().await;
        let mut all = Vec::new();
        for (index, conn) in self.conns.iter_mut().enumerate() {
            all.extend(conn.pump().into_iter().map(|m| (index, m)));
        }
        all
    }

    fn host_conn(&self) -> ConnId {
        self.conns
            .iter()
            .rev()
            .find(|c| c.player == self.room.player_id)
            .map_or(1, |c| c.id)
    }

    async fn host_sends(&self, message: ClientMessage) {
        let _ = self.room.handle.send(self.host_conn(), None, message).await;
    }

    /// The latest public view any connection has.
    fn view(&self) -> Option<RoomView> {
        self.conns
            .iter()
            .flat_map(|c| c.log.iter())
            .rev()
            .find_map(view_of)
            .cloned()
    }

    fn seated_guests(&self) -> Vec<String> {
        self.view().map_or_else(Vec::new, |v| {
            v.seats
                .iter()
                .map(|s| s.player_id.clone())
                .filter(|id| *id != self.room.player_id)
                .collect()
        })
    }

    async fn reconnect(&mut self, player: &str, keep_old: bool) {
        if !keep_old && let Some(old) = self.conns.iter().rev().find(|c| c.player == player) {
            self.room.handle.detach(old.id);
        }
        self.attach(player).await;
    }

    fn choose(&mut self, legal: &LegalActions) -> PlayerAction {
        let passive = if legal.can_check {
            PlayerAction::Check
        } else {
            PlayerAction::Call
        };
        match self.rng.below(100) {
            0..=24 if !legal.can_check => PlayerAction::Fold,
            75..=89 if legal.can_raise => PlayerAction::Raise {
                to_amount: legal.min_raise_to,
            },
            90..=96 => PlayerAction::AllIn,
            _ => passive,
        }
    }

    /// Starts a hand and plays it to the end, disturbing connections along the way.
    async fn play_hand(&mut self) -> bool {
        self.host_sends(ClientMessage::StartHand).await;
        for _ in 0..200 {
            let mut prompt = None;
            for (index, message) in self.pump().await {
                if let ServerMessage::TurnPrompt {
                    player_id,
                    next_action_seq,
                    legal,
                    ..
                } = message
                {
                    prompt = Some((index, player_id, next_action_seq, legal));
                }
            }
            let Some((index, player, action_seq, legal)) = prompt else {
                return self.view().is_some_and(|v| v.result.is_some());
            };
            match self.rng.below(100) {
                0..=3 => self.reconnect(&player, false).await,
                4..=6 => self.reconnect(&player, true).await,
                _ => {
                    let action = self.choose(&legal);
                    let conn = self.conns[index].id;
                    let _ = self
                        .room
                        .handle
                        .send(conn, None, ClientMessage::GameAction { action_seq, action })
                        .await;
                }
            }
        }
        false
    }

    /// Shuffles the table between hands: moves, removals, newcomers, sitting out.
    async fn churn(&mut self) {
        for _ in 0..self.rng.below(4) {
            let guests = self.seated_guests();
            match self.rng.below(6) {
                0 if !guests.is_empty() => {
                    let player_id = guests[self.rng.below(guests.len())].clone();
                    let seat_index = u8::try_from(self.rng.below(10)).unwrap();
                    self.host_sends(ClientMessage::MoveSeat {
                        player_id,
                        seat_index,
                    })
                    .await;
                }
                1 if guests.len() > 2 => {
                    let player_id = guests[self.rng.below(guests.len())].clone();
                    self.host_sends(ClientMessage::Kick { player_id }).await;
                }
                2 | 3 => self.add_player(false).await,
                4 => self.add_player(true).await,
                _ if !guests.is_empty() => {
                    let player = guests[self.rng.below(guests.len())].clone();
                    if let Some(conn) = self.conns.iter().rev().find(|c| c.player == player) {
                        let _ = self
                            .room
                            .handle
                            .send(
                                conn.id,
                                None,
                                ClientMessage::SetSittingOut {
                                    sitting_out: self.rng.below(2) == 0,
                                },
                            )
                            .await;
                    }
                }
                _ => {}
            }
        }
        let _ = self.pump().await;
    }
}

// -------------------------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------------------------

async fn play_game(seed: u64) -> (Vec<Conn>, u32) {
    let mut world = World::new(seed).await;
    let players = 4 + world.rng.below(7);
    for _ in 1..players {
        world.add_player(false).await;
    }
    for _ in 0..world.rng.below(3) {
        world.add_player(true).await;
    }
    let _ = world.pump().await;
    for _ in 0..6 {
        if !world.play_hand().await {
            break;
        }
        world.hands += 1;
        let _ = world.pump().await;
        world.churn().await;
    }
    let hands = world.hands;
    let _ = world.pump().await;
    (world.conns, hands)
}

#[tokio::test(start_paused = true)]
async fn no_leak_oracle() {
    let mut hands = 0;
    for seed in 1..=40 {
        let (conns, played) = play_game(seed).await;
        hands += played;
        if let Err(leak) = audit(&conns) {
            panic!("seed {seed}: {leak}");
        }
    }
    assert!(hands >= 100, "the games must actually deal hands ({hands})");
}

#[tokio::test(start_paused = true)]
async fn the_oracle_catches_a_planted_leak() {
    let (mut conns, _) = play_game(7).await;
    audit(&conns).unwrap();
    // Hand somebody else's hole card to a connection inside an ordinary view.
    let victim = conns
        .iter()
        .find_map(|c| {
            c.log.iter().find_map(|m| match m {
                ServerMessage::HoleCards { hand_number, cards } => {
                    Some((c.player.clone(), *hand_number, cards[0]))
                }
                _ => None,
            })
        })
        .expect("somebody was dealt cards");
    let spy = conns.iter_mut().find(|c| c.player != victim.0).unwrap();
    let planted = spy
        .log
        .iter_mut()
        .find_map(|m| match m {
            ServerMessage::StateUpdate { view, .. } if view.hand_number == victim.1 => Some(view),
            _ => None,
        })
        .expect("a view of that hand");
    planted.board.push(victim.2);
    assert!(
        audit(&conns).is_err(),
        "a hole card in a view must be caught"
    );

    // And so must a card in a message that has no business carrying one.
    let (mut conns, _) = play_game(7).await;
    conns[0].log.push(ServerMessage::Pong { t: 1 });
    audit(&conns).unwrap();
    conns[0].log.push(
        serde_json::from_value(serde_json::json!({
            "v": 1, "type": "ERROR", "code": "BAD_REQUEST", "message": "As"
        }))
        .unwrap(),
    );
    assert!(audit(&conns).is_err());
}
