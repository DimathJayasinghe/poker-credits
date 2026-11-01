/// Wire models for the Poker Credits WebSocket protocol (see docs/API_AND_EVENTS.md).
///
/// Pure Dart and web-safe: never import dart:io or dart:ffi here (ADR-014).
/// Real models arrive in Phase 3; Rust is the schema source of truth.
library;

/// Protocol version carried in the `v` field of every message.
const int protocolVersion = 1;

/// Largest chip amount allowed on the wire. Below 2^53 so JavaScript clients stay exact.
const int maxChips = 1000000000000;
