import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:poker_credits/platform/sound_player.dart';

final _log = Logger('Sound');

SoundPlayer createSoundPlayer() => _SoLoudPlayer();

/// Plays the clips through SoLoud. The engine starts on the first cue (so a silent game never opens
/// the audio device), each clip is loaded once and kept in memory (they are short), and the device
/// is released again after [_idleAfter] without a cue: SoLoud otherwise keeps an output stream
/// running for as long as it is initialised, which holds the audio route (and keeps a Bluetooth
/// speaker awake) while a phone just sits on the table.
final class _SoLoudPlayer implements SoundPlayer {
  /// SoLoud pans a mono clip into stereo at -3 dB (measured on Linux: every cue came out exactly
  /// 3 dB under its file). This puts the level the files were mixed at back.
  static const double _monoGain = 1.41;

  static const Duration _idleAfter = Duration(seconds: 45);

  Future<bool>? _starting;
  final Map<String, Future<AudioSource>> _clips = <String, Future<AudioSource>>{};
  Timer? _idle;
  int _inFlight = 0;

  @override
  Future<void> play(String asset, {double volume = 1}) async {
    _inFlight++;
    try {
      if (!await (_starting ??= _start())) return;
      final clip = await (_clips[asset] ??= SoLoud.instance.loadAsset(asset));
      SoLoud.instance.play(clip, volume: volume * _monoGain);
    } on Object catch (error) {
      // A clip that fails to load is tried again on its next cue; the engine itself is not.
      unawaited(_clips.remove(asset));
      _log.warning('could not play $asset', error);
    } finally {
      _inFlight--;
      _idle?.cancel();
      if (_starting != null) _idle = Timer(_idleAfter, _release);
    }
  }

  Future<bool> _start() async {
    try {
      await SoLoud.instance.init();
      return true;
    } on Object catch (error) {
      // Not retried and not released: no audio output stays no audio output.
      _log.warning('no audio output, sounds are off', error);
      return false;
    }
  }

  /// Gives the audio device back; the next cue starts the engine again.
  Future<void> _release() async {
    _idle = null;
    if (_inFlight > 0) {
      _idle = Timer(_idleAfter, _release);
      return;
    }
    final starting = _starting;
    if (starting == null || !await starting) return;
    _starting = null;
    _clips.clear();
    try {
      await SoLoud.instance.deinitAsync();
    } on Object catch (error) {
      _log.warning('could not release the audio output', error);
    }
  }
}
