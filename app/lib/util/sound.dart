import 'package:poker_credits/model/sound_cues.dart';
import 'package:poker_credits/platform/sound_player.dart';

/// Plays the sound effects, when the Settings switch is on and the app is in front.
///
/// The one switch is all the user configures: on or off. The platform's own volume decides how
/// loud. Nothing here throws, and a cue that comes again within [minGap] is dropped rather than
/// queued, so a burst of messages (a reconnect, an all-in runout) never turns into a pile of sound.
class Sound {
  Sound({
    required this.player,
    this.enabled = _always,
    this.foreground = _always,
    DateTime Function() now = DateTime.now,
    this.minGap = const Duration(milliseconds: 120),
  }) : _now = now;

  final SoundPlayer player;

  /// Asked every time, so the Settings switch takes effect at once.
  final bool Function() enabled;

  /// Whether the app is in front; a phone in a pocket stays quiet.
  final bool Function() foreground;
  final Duration minGap;
  final DateTime Function() _now;

  final Map<SoundCue, DateTime> _last = <SoundCue, DateTime>{};
  final Map<SoundCue, int> _turn = <SoundCue, int>{};

  static bool _always() => true;

  Future<void> play(SoundCue cue) async {
    if (!enabled() || !foreground()) return;
    final now = _now();
    final last = _last[cue];
    if (last != null && now.difference(last) < minGap) return;
    _last[cue] = now;
    final index = (_turn[cue] ?? 0) % cue.clips.length;
    _turn[cue] = index + 1;
    await player.play(SoundCue.assetOf(cue.clips[index]));
  }

  /// The alert for the player whose turn it is (the pages call this).
  Future<void> yourTurn() => play(SoundCue.turn);
}
