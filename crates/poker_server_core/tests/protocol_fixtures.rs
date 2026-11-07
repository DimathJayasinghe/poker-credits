//! Golden protocol fixtures: every file in `protocol/fixtures/v1/` parses into the typed message,
//! serialises back to the same JSON, and every message type has a fixture.
#![allow(
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::fs;
use std::path::PathBuf;

use poker_server_core::PROTOCOL_VERSION;
use poker_server_core::protocol::{
    ClientMessage, Envelope, ErrorCode, ParseError, ServerMessage, encode_server, parse_client,
};
use serde_json::{Value, json};

fn fixtures() -> Vec<(String, Value)> {
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../protocol/fixtures/v1");
    let mut files: Vec<(String, Value)> = fs::read_dir(dir)
        .unwrap()
        .map(|entry| {
            let path = entry.unwrap().path();
            let name = path.file_name().unwrap().to_string_lossy().into_owned();
            (
                name,
                serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap(),
            )
        })
        .collect();
    files.sort_by(|a, b| a.0.cmp(&b.0));
    files
}

#[test]
fn client_fixtures_round_trip() {
    let mut count = 0;
    for (name, value) in fixtures()
        .into_iter()
        .filter(|(n, _)| n.starts_with("client_"))
    {
        let parsed: Envelope<ClientMessage> =
            serde_json::from_value(value.clone()).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_ne!(
            parsed.body,
            ClientMessage::Unknown,
            "{name} must be a known type"
        );
        assert_eq!(
            serde_json::to_value(&parsed).unwrap(),
            value,
            "{name} did not round-trip"
        );
        assert!(
            parse_client(&value.to_string()).is_ok(),
            "{name} must pass parse_client"
        );
        count += 1;
    }
    assert_eq!(count, 27);
}

#[test]
fn server_fixtures_round_trip() {
    let mut count = 0;
    for (name, value) in fixtures()
        .into_iter()
        .filter(|(n, _)| n.starts_with("server_"))
    {
        let parsed: Envelope<ServerMessage> =
            serde_json::from_value(value.clone()).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(
            serde_json::to_value(&parsed).unwrap(),
            value,
            "{name} did not round-trip"
        );
        let encoded = encode_server(parsed.req_id.as_deref(), &parsed.body).unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&encoded).unwrap(),
            value,
            "{name} encode_server differs"
        );
        count += 1;
    }
    assert_eq!(count, 22);
}

#[test]
fn every_client_message_type_has_a_fixture() {
    let types: Vec<String> = fixtures()
        .iter()
        .filter(|(n, _)| n.starts_with("client_"))
        .map(|(_, v)| v["type"].as_str().unwrap().to_owned())
        .collect();
    for expected in [
        "CREATE_ROOM",
        "JOIN_ROOM",
        "RESUME",
        "START_HAND",
        "GAME_ACTION",
        "BEGIN_SHOWDOWN",
        "RESOLVE_SHOWDOWN",
        "UNDO",
        "PAUSE",
        "RESUME_GAME",
        "APPROVE_REBUY",
        "KICK",
        "MOVE_SEAT",
        "CHOOSE_SEAT",
        "ROOM_CONFIGURE",
        "END_GAME",
        "REQUEST_REBUY",
        "SET_SITTING_OUT",
        "LEAVE_TABLE",
        "PRESENCE_VOTE",
        "PRESENCE_ACK",
        "PING",
    ] {
        assert!(
            types.iter().any(|t| t == expected),
            "no client fixture for {expected}"
        );
    }
}

#[test]
fn every_server_message_type_has_a_fixture() {
    let types: Vec<String> = fixtures()
        .iter()
        .filter(|(n, _)| n.starts_with("server_"))
        .map(|(_, v)| v["type"].as_str().unwrap().to_owned())
        .collect();
    for expected in [
        "ROOM_CREATED",
        "JOINED",
        "SNAPSHOT",
        "STATE_UPDATE",
        "TURN_PROMPT",
        "ACTION_PERFORMED",
        "ACK",
        "ERROR",
        "PLAYER_CONNECTION",
        "GAME_PAUSED",
        "GAME_RESUMED",
        "ROOM_RECOVERED",
        "ROOM_CRASHED",
        "ROOM_EXPIRED",
        "PONG",
        "PLAYER_AWAY",
        "PRESENCE_CHECK",
        "PRESENCE_RESOLVED",
        "HOLE_CARDS",
    ] {
        assert!(
            types.iter().any(|t| t == expected),
            "no server fixture for {expected}"
        );
    }
}

#[test]
fn unknown_type_is_not_a_parse_error() {
    let parsed = parse_client(r#"{"v":1,"type":"DANCE","reqId":"c-9"}"#).unwrap();
    assert_eq!(parsed.body, ClientMessage::Unknown);
    assert_eq!(parsed.req_id.as_deref(), Some("c-9"));
}

#[test]
fn unknown_fields_are_ignored() {
    let parsed = parse_client(r#"{"v":1,"type":"PING","t":5,"future":"x"}"#).unwrap();
    assert_eq!(parsed.body, ClientMessage::Ping { t: 5 });
}

#[test]
fn wrong_version_is_reported_before_the_body_is_read() {
    let failure =
        parse_client(r#"{"v":2,"type":"SOMETHING_NEW","reqId":"c-1","x":[1]}"#).unwrap_err();
    assert_eq!(failure.error, ParseError::VersionMismatch);
    assert_eq!(failure.req_id.as_deref(), Some("c-1"));
    assert!(matches!(
        failure.error.to_message(),
        ServerMessage::Error {
            code: ErrorCode::VersionMismatch,
            ..
        }
    ));
}

#[test]
fn malformed_frames_are_bad_requests() {
    for text in [
        "",
        "not json",
        "[]",
        "null",
        r#"{"type":"PING","t":1}"#,
        r#"{"v":"1","type":"PING"}"#,
    ] {
        let failure = parse_client(text).unwrap_err();
        assert!(
            matches!(failure.error, ParseError::BadRequest(_)),
            "{text:?} -> {failure:?}"
        );
    }
    // Known type with a bad field.
    let failure =
        parse_client(r#"{"v":1,"type":"GAME_ACTION","actionSeq":"x","action":{"kind":"FOLD"}}"#)
            .unwrap_err();
    assert!(matches!(failure.error, ParseError::BadRequest(_)));
    let failure =
        parse_client(r#"{"v":1,"type":"GAME_ACTION","actionSeq":1,"action":{"kind":"RAISE"}}"#)
            .unwrap_err();
    assert!(
        matches!(failure.error, ParseError::BadRequest(_)),
        "raise needs toAmount"
    );
}

#[test]
fn oversized_frames_are_rejected_without_parsing() {
    let padding = "x".repeat(poker_server_core::protocol::MAX_MESSAGE_BYTES);
    let text = format!(r#"{{"v":1,"type":"PING","t":1,"pad":"{padding}"}}"#);
    assert_eq!(parse_client(&text).unwrap_err().error, ParseError::TooLarge);
}

#[test]
fn engine_errors_map_to_codes_and_carry_numbers() {
    use poker_engine::{Chips, PokerError};
    let message = poker_server_core::protocol::error_from_engine(&PokerError::BelowMinRaise {
        min_raise_to: Chips::new(40).unwrap(),
    });
    assert_eq!(
        serde_json::to_value(&message).unwrap(),
        json!({"type":"ERROR","code":"BELOW_MIN_RAISE","message":"minimum raise is to 40","details":{"minRaiseTo":40}})
    );
    assert_eq!(
        ErrorCode::from(&PokerError::CannotCheck),
        ErrorCode::InvalidCheck
    );
    assert_eq!(PROTOCOL_VERSION, 1);
}

#[test]
fn physical_messages_without_card_fields_still_parse_and_stay_unchanged() {
    let old = r#"{"v":1,"type":"JOIN_ROOM","roomCode":"KQ7M","name":"Al","spectator":false}"#;
    let parsed = parse_client(old).unwrap();
    let ClientMessage::JoinRoom { features, .. } = parsed.body else {
        panic!("not a join");
    };
    assert!(features.is_empty());
    let config = fixtures()
        .into_iter()
        .find(|(n, _)| n == "client_create_room.json")
        .unwrap()
        .1;
    assert!(config["config"].get("cardMode").is_none());
}

#[test]
fn card_mode_defaults_to_physical_and_virtual_is_explicit() {
    use poker_server_core::protocol::{CardMode, RoomConfig};
    let json = fixtures()
        .into_iter()
        .find(|(n, _)| n == "client_create_room.json")
        .unwrap()
        .1["config"]
        .clone();
    let physical: RoomConfig = serde_json::from_value(json).unwrap();
    assert_eq!(physical.card_mode, CardMode::Physical);
    let virtual_json = fixtures()
        .into_iter()
        .find(|(n, _)| n == "client_create_room_virtual.json")
        .unwrap()
        .1["config"]
        .clone();
    let virtual_config: RoomConfig = serde_json::from_value(virtual_json).unwrap();
    assert_eq!(virtual_config.card_mode, CardMode::Virtual);
}
