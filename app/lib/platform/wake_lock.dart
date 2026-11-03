/// Platform seam: keep the screen awake while a table is shown (ADR-014).
library;

export 'wake_lock_stub.dart' if (dart.library.io) 'wake_lock_io.dart';

/// Keeps the display on while enabled. Failures are logged, never thrown: a missing wake lock
/// must not stop a game.
abstract interface class WakeLock {
  Future<void> enable();
  Future<void> disable();
}
