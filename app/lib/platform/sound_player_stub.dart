import 'package:poker_credits/platform/sound_player.dart';

/// Web: silent until the web build is taken up (ADR-014).
SoundPlayer createSoundPlayer() => const SilentSoundPlayer();
