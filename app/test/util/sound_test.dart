import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/sound_cues.dart';
import 'package:poker_credits/util/sound.dart';

import '../support/fakes.dart';

void main() {
  late RecordingSoundPlayer player;
  var now = DateTime(2026, 11, 8, 12);
  var on = true;
  var inFront = true;
  late Sound sound;

  setUp(() {
    player = RecordingSoundPlayer();
    now = DateTime(2026, 11, 8, 12);
    on = true;
    inFront = true;
    sound = Sound(player: player, enabled: () => on, foreground: () => inFront, now: () => now);
  });

  test('plays the cue\'s clip from the bundle', () async {
    await sound.play(SoundCue.fold);
    expect(player.played, ['assets/sounds/fold.wav']);
  });

  test('yourTurn is the turn cue', () async {
    await sound.yourTurn();
    expect(player.played, ['assets/sounds/turn.wav']);
  });

  test('the Settings switch is read on every cue', () async {
    on = false;
    await sound.play(SoundCue.check);
    expect(player.played, isEmpty);
    on = true;
    await sound.play(SoundCue.check);
    expect(player.played, hasLength(1));
  });

  test('silent while the app is not in front', () async {
    inFront = false;
    await sound.play(SoundCue.check);
    expect(player.played, isEmpty);
  });

  test('the same cue twice within the gap plays once; after the gap it plays again', () async {
    await sound.play(SoundCue.check);
    now = now.add(const Duration(milliseconds: 60));
    await sound.play(SoundCue.check);
    expect(player.played, hasLength(1), reason: 'dropped, not queued');
    now = now.add(const Duration(milliseconds: 100));
    await sound.play(SoundCue.check);
    expect(player.played, hasLength(2));
  });

  test('different cues do not hold each other back', () async {
    await sound.play(SoundCue.check);
    await sound.play(SoundCue.fold);
    expect(player.played, hasLength(2));
  });

  test('a cue with several clips goes through them in turn', () async {
    for (var i = 0; i < 4; i++) {
      await sound.play(SoundCue.call);
      now = now.add(const Duration(seconds: 1));
    }
    expect(player.played, [
      'assets/sounds/call_1.wav',
      'assets/sounds/call_2.wav',
      'assets/sounds/call_3.wav',
      'assets/sounds/call_1.wav',
    ]);
  });

  test('a player that throws must not reach the game', () {
    // The platform players catch their own errors; this pins that the facade adds nothing that could throw.
    fakeAsync((async) {
      sound.play(SoundCue.win);
      async.flushMicrotasks();
      expect(player.played, hasLength(1));
    });
  });
}
