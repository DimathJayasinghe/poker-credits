/// Platform seam: keep the hosting process alive while the app is in the background (ADR-014).
library;

export 'host_keep_alive_stub.dart' if (dart.library.io) 'host_keep_alive_io.dart';

/// Keeps a hosted game running when the host switches app or locks the phone. Only Android needs
/// it (a foreground service with a notification); elsewhere it does nothing. Failures are
/// logged, never thrown: a missing notification must not stop a game.
abstract interface class HostKeepAlive {
  /// Starts keeping the process alive for the game with [roomCode].
  Future<void> start(String roomCode);

  /// Stops it (the game ended or hosting was cancelled).
  Future<void> stop();
}
