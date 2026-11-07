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

  /// The certificate fingerprint guests pin, or `null` when no server runs or it is not on the
  /// network (ADR-019).
  String? get fingerprint;

  /// Starts the embedded server (rooms found on disk come back) and returns its port. Does
  /// nothing when it already runs. Used to re-attach to a room after the app was killed.
  ///
  /// Throws [HostException].
  Future<int> startServer();

  /// Starts the embedded server if needed and creates a room.
  ///
  /// Throws [HostException].
  Future<HostedRoom> hostGame({required String hostName, required RoomConfig config});

  /// Starts the server that only this device can reach (a single-player game) and returns its
  /// port. Stops a server that is open to the network first: the two never run together, and
  /// the caller makes sure no hosted game is running.
  ///
  /// Throws [HostException].
  Future<int> startSoloServer();

  /// Starts the solo server and creates a single-player game on it.
  ///
  /// Throws [HostException].
  Future<HostedRoom> hostSolo({required String hostName, required SoloConfig solo});

  /// Makes sure the server is up, restarting it if the OS or a panic stopped it. Rooms come
  /// back from disk. Call when the app returns to the foreground.
  ///
  /// Throws [HostException].
  Future<void> ensureRunning();

  /// Stops the server (its rooms stay on disk).
  Future<void> stop();
}
