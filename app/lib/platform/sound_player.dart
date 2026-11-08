/// Platform seam: plays the bundled sound clips (ADR-014).
library;

export 'sound_player_stub.dart' if (dart.library.io) 'sound_player_io.dart';

/// Plays a clip from the asset bundle. Implementations never throw: a device with no audio output
/// must not stop a game, so a failure is logged and the call returns.
abstract interface class SoundPlayer {
  /// Plays the clip at [asset] (a path in the asset bundle) once, at [volume] from 0 to 1.
  Future<void> play(String asset, {double volume = 1});
}

/// Plays nothing (web for now, and tests that do not care about sound).
class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> play(String asset, {double volume = 1}) async {}
}
