/// Wire models for the Poker Credits WebSocket protocol (see docs/API_AND_EVENTS.md).
///
/// Pure Dart and web-safe: never import dart:io or dart:ffi here (ADR-014).
/// Rust (`crates/poker_server_core/src/protocol.rs`) is the schema source of truth; both sides
/// are tested against the golden files in `protocol/fixtures/v1/`.
library;

export 'src/client_message.dart';
export 'src/envelope.dart';
export 'src/error_code.dart';
export 'src/player_action.dart';
export 'src/room_config.dart';
export 'src/room_view.dart';
export 'src/server_message.dart';

/// Largest chip amount allowed on the wire. Below 2^53 so JavaScript clients stay exact.
const int maxChips = 1000000000000;
