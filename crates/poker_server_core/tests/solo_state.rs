//! The solo rules of the pure reducer: seating, places, who may do what.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use poker_bots::Skill;
use poker_engine::{Chips, Phase};
use poker_server_core::config::Timings;
use poker_server_core::protocol::{CardMode, ErrorCode, RoomConfig, SoloConfig};
use poker_server_core::room::state::{Op, RoomState};

fn config(bots: u8) -> RoomConfig {
    RoomConfig {
        card_mode: CardMode::Virtual,
        starting_chips: 1000,
        small_blind: 5,
        big_blind: 10,
        ante: 0,
        is_tournament: false,
        blind_level_minutes: 10,
        turn_time_limit_seconds: 0,
        solo: Some(SoloConfig {
            bots,
            skill: Skill::Normal,
            ladder_hands: 8,
        }),
    }
}

fn solo_room(bots: u8, seed: u64) -> RoomState {
    let mut room = RoomState::new(
        "ABCD".into(),
        config(bots),
        "Dimath",
        "h".into(),
        "s".into(),
        0,
    )
    .unwrap();
    room.seat_bots(seed).unwrap();
    room
}

fn set_chips(room: &mut RoomState, id: &str, chips: u64) {
    let seat = room
        .game
        .table
        .seats
        .iter_mut()
        .find(|s| s.player_id.as_str() == id)
        .unwrap();
    seat.chips = Chips::new(chips).unwrap();
}

fn sweep(room: &mut RoomState) -> Result<(), ErrorCode> {
    room.apply(Op::SoloSweep { at_ms: 1 }, &Timings::default())
        .map(|_| ())
        .map_err(|e| e.code)
}

#[test]
fn solo_needs_virtual_cards_and_one_to_nine_bots() {
    let new = |c: RoomConfig| RoomState::new("ABCD".into(), c, "Dimath", "h".into(), "s".into(), 0);
    let mut physical = config(3);
    physical.card_mode = CardMode::Physical;
    assert!(new(physical).is_err());
    assert!(new(config(0)).is_err());
    assert!(new(config(10)).is_err());
    assert!(new(config(1)).is_ok());
    assert!(new(config(9)).is_ok());
    let mut no_ladder = config(3);
    no_ladder.solo.as_mut().unwrap().ladder_hands = 0;
    assert!(new(no_ladder).is_err());
}

#[test]
fn bots_fill_distinct_seats_with_distinct_names_and_profiles() {
    for bots in 1..=9_u8 {
        let room = solo_room(bots, 42 + u64::from(bots));
        assert_eq!(room.game.table.seats.len(), usize::from(bots) + 1);
        assert_eq!(room.bots.len(), usize::from(bots));
        let mut names: Vec<String> = room
            .players
            .values()
            .map(|p| p.name.to_lowercase())
            .collect();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), usize::from(bots) + 1, "names collide");
        assert!(room.players.values().all(|p| p.seat.is_some()));
        assert_eq!(room.players.get("p_1").unwrap().seat, Some(0));
    }
}

#[test]
fn a_bot_never_takes_the_humans_name() {
    for seed in 0..60 {
        let mut room =
            RoomState::new("ABCD".into(), config(9), "maya", "h".into(), "s".into(), 0).unwrap();
        room.seat_bots(seed).unwrap();
        let same = room
            .players
            .values()
            .filter(|p| p.name.eq_ignore_ascii_case("maya"))
            .count();
        assert_eq!(same, 1);
    }
}

#[test]
fn same_seed_same_table() {
    assert_eq!(solo_room(5, 7).bots, solo_room(5, 7).bots);
    assert_ne!(solo_room(5, 7).bots, solo_room(5, 8).bots);
}

#[test]
fn the_state_survives_a_snapshot_round_trip() {
    let room = solo_room(4, 3);
    let json = serde_json::to_string(&room).unwrap();
    let back: RoomState = serde_json::from_str(&json).unwrap();
    assert_eq!(room, back);
}

#[test]
fn two_busts_in_one_hand_rank_by_starting_stack() {
    let mut room = solo_room(4, 9);
    let ids: Vec<String> = room.players.keys().cloned().collect();
    // Hand dealt with five funded players; two of the bots lose everything.
    room.hand_start_chips = ids.iter().map(|id| (id.clone(), 1000)).collect();
    room.hand_start_chips.insert(ids[1].clone(), 300);
    room.hand_start_chips.insert(ids[2].clone(), 700);
    set_chips(&mut room, &ids[1], 0);
    set_chips(&mut room, &ids[2], 0);
    room.game.table.phase = Phase::NextHandPrep;
    room.game.table.hand_number = 1;
    sweep(&mut room).unwrap();
    let places: Vec<(&str, u8)> = room
        .finish_order
        .iter()
        .map(|f| (f.player_id.as_str(), f.place))
        .collect();
    assert_eq!(places, vec![(ids[1].as_str(), 5), (ids[2].as_str(), 4)]);
    // They have left the table; everyone else is still there.
    assert_eq!(room.game.table.seats.len(), 3);
    assert!(!room.players.contains_key(&ids[1]));
    assert!(!room.bots.contains_key(&ids[2]));
    assert!(!room.solo_over());
}

#[test]
fn the_last_player_standing_wins_and_the_game_is_over() {
    let mut room = solo_room(2, 5);
    let ids: Vec<String> = room.players.keys().cloned().collect();
    room.hand_start_chips = ids.iter().map(|id| (id.clone(), 1000)).collect();
    set_chips(&mut room, &ids[1], 0);
    set_chips(&mut room, &ids[2], 0);
    set_chips(&mut room, &ids[0], 3000);
    room.game.table.phase = Phase::NextHandPrep;
    room.game.table.hand_number = 1;
    sweep(&mut room).unwrap();
    let human = room.finish_order.last().unwrap();
    assert_eq!((human.player_id.as_str(), human.place), ("p_1", 1));
    assert!(room.solo_over());
    assert!(!room.solo_ready_for_hand());
    assert_eq!(sweep(&mut room), Err(ErrorCode::IllegalState));
}

#[test]
fn a_busted_human_keeps_the_seat_and_ends_the_game() {
    let mut room = solo_room(2, 5);
    let ids: Vec<String> = room.players.keys().cloned().collect();
    room.hand_start_chips = ids.iter().map(|id| (id.clone(), 1000)).collect();
    set_chips(&mut room, "p_1", 0);
    room.game.table.phase = Phase::NextHandPrep;
    room.game.table.hand_number = 1;
    sweep(&mut room).unwrap();
    assert_eq!(room.finish_order.len(), 1);
    assert_eq!(room.finish_order[0].place, 3);
    assert!(room.players.contains_key("p_1"));
    assert!(room.solo_over());
    assert!(!room.solo_ready_for_hand());
}

#[test]
fn rebuy_and_new_players_are_refused_in_solo() {
    let mut room = solo_room(2, 5);
    let join = Op::Join {
        player_id: "p_9".into(),
        name: "Guest".into(),
        spectator: false,
        seat: None,
        token_hash: "x".into(),
        at_ms: 1,
    };
    assert!(room.apply(join, &Timings::default()).is_err());
    let rebuy = Op::RequestRebuy {
        player_id: "p_1".into(),
        amount: 500,
        at_ms: 1,
    };
    assert_eq!(
        room.apply(rebuy, &Timings::default()).unwrap_err().code,
        ErrorCode::BadRequest
    );
}

#[test]
fn an_ordinary_room_has_no_solo_behaviour() {
    let mut c = config(3);
    c.solo = None;
    c.card_mode = CardMode::Physical;
    let room = RoomState::new("ABCD".into(), c, "Dimath", "h".into(), "s".into(), 0).unwrap();
    assert!(!room.is_solo());
    assert!(!room.needs_solo_sweep());
    assert!(!room.solo_ready_for_hand());
    assert!(room.bots.is_empty());
    let json = serde_json::to_string(&room).unwrap();
    assert!(!json.contains("bots") && !json.contains("finishOrder") && !json.contains("solo"));
}

#[test]
fn configure_can_neither_change_a_solo_room_nor_make_one() {
    use poker_server_core::room::state::HostCommand;
    let host = |config: RoomConfig| Op::Host {
        by: "p_1".into(),
        command: HostCommand::Configure { config },
        at_ms: 1,
    };
    // A solo room refuses every Configure.
    let mut solo = solo_room(2, 5);
    assert_eq!(
        solo.apply(host(config(2)), &Timings::default())
            .unwrap_err()
            .code,
        ErrorCode::BadRequest
    );
    // An ordinary room refuses a Configure that carries `solo`.
    let mut c = config(2);
    c.solo = None;
    c.card_mode = CardMode::Physical;
    let mut plain = RoomState::new("ABCD".into(), c, "Dimath", "h".into(), "s".into(), 0).unwrap();
    let mut sneaky = config(2);
    sneaky.card_mode = CardMode::Physical;
    assert_eq!(
        plain
            .apply(host(sneaky), &Timings::default())
            .unwrap_err()
            .code,
        ErrorCode::BadRequest
    );
    assert!(!plain.is_solo());
}
