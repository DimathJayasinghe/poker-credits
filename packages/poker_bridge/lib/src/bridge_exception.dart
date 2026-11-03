/// Why a bridge call failed, in terms the app can act on.
enum BridgeFailureKind {
  /// Rust panicked inside the call. The process survives; the server may need a restart.
  panic,

  /// The port is busy or not allowed.
  bind,

  /// The data folder could not be created.
  dataDir,

  /// The server refused the room; see [BridgeException.code].
  room,

  /// Anything else.
  unknown,
}

/// A failed bridge call. Every call in this package throws this and nothing else.
class BridgeException implements Exception {
  const BridgeException(this.kind, this.message, {this.nativeTrace, this.code});

  final BridgeFailureKind kind;
  final String message;

  /// Wire error code (for example `ROOM_FULL`) when [kind] is [BridgeFailureKind.room].
  final String? code;

  /// The Rust backtrace for a [BridgeFailureKind.panic], for the log. Never show it to players.
  final String? nativeTrace;

  @override
  String toString() => 'BridgeException(${kind.name}): $message';
}
