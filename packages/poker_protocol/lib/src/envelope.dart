import 'dart:convert';

import 'client_message.dart';
import 'server_message.dart';

/// Protocol version carried in the `v` field of every message.
const int protocolVersion = 1;

/// A message plus the envelope fields `v` and `reqId`.
class Envelope<T> {
  const Envelope({required this.body, this.reqId, this.version = protocolVersion});

  /// The typed message.
  final T body;

  /// Client-chosen id; the server echoes it on its answer.
  final String? reqId;

  /// Protocol version.
  final int version;
}

/// A frame that is not a valid protocol message.
class ProtocolFormatException implements Exception {
  const ProtocolFormatException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolFormatException: $message';
}

/// Encodes one client frame (one JSON object per WebSocket text message).
String encodeClient(ClientMessage message, {String? reqId}) {
  final map = message.toMap();
  map['v'] = protocolVersion;
  if (reqId != null) {
    map['reqId'] = reqId;
  }
  return jsonEncode(map);
}

/// Decodes one server frame.
///
/// Throws [ProtocolFormatException] when the text is not a JSON object with a `type`. A `type`
/// this client does not know gives an [UnknownServerMessage].
Envelope<ServerMessage> decodeServer(String text) {
  final (map, reqId, version) = _open(text);
  try {
    return Envelope(body: ServerMessageMapper.fromMap(map), reqId: reqId, version: version);
  } on Object catch (error) {
    throw ProtocolFormatException('bad server message: $error');
  }
}

/// Decodes one client frame (used by tests and by a Dart-side server stub).
Envelope<ClientMessage> decodeClient(String text) {
  final (map, reqId, version) = _open(text);
  try {
    return Envelope(body: ClientMessageMapper.fromMap(map), reqId: reqId, version: version);
  } on Object catch (error) {
    throw ProtocolFormatException('bad client message: $error');
  }
}

/// Encodes a server message the way the Rust server does (for tests and stubs).
String encodeServer(ServerMessage message, {String? reqId}) {
  final map = message.toMap();
  map['v'] = protocolVersion;
  if (reqId != null) {
    map['reqId'] = reqId;
  }
  return jsonEncode(map);
}

(Map<String, dynamic>, String?, int) _open(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (error) {
    throw ProtocolFormatException('not JSON: ${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ProtocolFormatException('expected a JSON object');
  }
  final version = decoded['v'];
  if (version is! int) {
    throw const ProtocolFormatException('missing protocol version');
  }
  if (decoded['type'] is! String) {
    throw const ProtocolFormatException('missing message type');
  }
  final reqId = decoded['reqId'];
  return (decoded, reqId is String ? reqId : null, version);
}
