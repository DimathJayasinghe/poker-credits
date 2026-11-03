/// Platform seam for hosting the embedded game server (ADR-014).
///
/// Native builds get the real implementation (the Rust bridge); web gets an "unsupported"
/// stub. Feature code only talks to [HostServer].
library;

import 'package:poker_credits/model/hosting.dart';
import 'package:poker_protocol/poker_protocol.dart';

export 'host_server_stub.dart' if (dart.library.io) 'host_server_io.dart';

/// Contract implemented by each platform variant of the host server.
abstract interface class HostServer {
  /// Whether this platform can host a game at all.
  bool get isSupported;

  /// Port of the running server, or `null` when none runs.
  int? get port;

  /// Starts the embedded server if needed and creates a room.
  ///
  /// Throws [HostException].
  Future<HostedRoom> hostGame({required String hostName, required RoomConfig config});

  /// Makes sure the server is up, restarting it if the OS or a panic stopped it. Rooms come
  /// back from disk. Call when the app returns to the foreground.
  ///
  /// Throws [HostException].
  Future<void> ensureRunning();

  /// Stops the server (its rooms stay on disk).
  Future<void> stop();
}
