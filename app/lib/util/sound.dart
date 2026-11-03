import 'package:flutter/services.dart';

/// Audible cues through the platform's own system sounds, so no audio plugin is needed.
///
/// `SystemSound` is limited: iOS and the desktop platforms play the alert beep, Android only
/// has a click. The vibration in `Haptics` is the primary turn cue on phones; a real audio
/// plugin can replace this class later without touching the callers.
class Sound {
  const Sound();

  Future<void> yourTurn() => SystemSound.play(SystemSoundType.alert);
}
