import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/sound_cues.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

/// Which sound effect plays for which message, on which kind of device. Phones sit together at a
/// table, so a guest's phone plays only its own sounds and the table's phone plays the table's.
void main() {
  final seats = [seatView(0, 'Host'), seatView(1, 'Ana'), seatView(2, 'Bo')];

  const winOne = HandResult(
    uncontested: false,
    pots: [
      PotResult(
        potIndex: 0,
        amount: 100,
        winnerPlayerIds: ['p_1'],
        shares: [Share(playerId: 'p_1', name: 'Ana', amount: 100)],
      ),
    ],
  );
  final shown = [
    Reveal(
      playerId: 'p_1',
      name: 'Ana',
      cards: [card('As'), card('Ad')],
      category: HandCategory.pair,
      bestFive: [card('As'), card('Ad'), card('2c'), card('5d'), card('9h')],
    ),
  ];

  late SoundTracker tracker;
  setUp(() => tracker = SoundTracker());

  // `p_1` is the device under test unless said otherwise: a seated guest.
  List<SoundCue> feed(ServerMessage message, {String? me = 'p_1', bool host = false}) => tracker.onMessage(message, me: me, isHost: host);
  StateUpdate update(RoomView view, [int version = 2]) => StateUpdate(stateVersion: version, view: view);
  ActionPerformed acted(String id, ActionKind kind, {bool allIn = false}) =>
      ActionPerformed(playerId: id, playerName: id, kind: kind, amount: 10, chipsRemaining: 90, allIn: allIn, auto: false);

  group('baseline and replays', () {
    test('a snapshot is silent, and so is the hole cards message the server resends after it', () {
      expect(feed(snapshot(view: roomView(hand: 3, seats: seats))), isEmpty);
      expect(feed(holeCards('As', 'Kd', hand: 3)), isEmpty, reason: 'same hand as the snapshot: already dealt');
    });

    test('a repeated STATE_UPDATE makes no new sound', () {
      feed(snapshot(view: roomView(seats: seats)));
      final view = roomView(hand: 2, seats: seats);
      expect(feed(update(view), me: 'p_0', host: true), [SoundCue.shuffle]);
      expect(feed(update(view, 3), me: 'p_0', host: true), isEmpty);
    });

    test('coming back to a table in the middle of the flop does not replay the flop', () {
      final flop = roomView(phase: WirePhase.flop, board: [card('2c'), card('7d'), card('Kh')], seats: seats);
      feed(snapshot(view: flop));
      expect(feed(update(flop)), isEmpty);
    });

    test('nothing plays before the first snapshot, or after a reset', () {
      expect(feed(acted('p_2', ActionKind.call)), isEmpty);
      feed(snapshot(view: roomView(seats: seats)));
      expect(feed(acted('p_2', ActionKind.call), host: true), [SoundCue.call]);
      tracker.reset();
      expect(feed(acted('p_2', ActionKind.call), host: true), isEmpty);
    });
  });

  group('the table device (host or spectator)', () {
    setUp(
      () => feed(
        snapshot(
          view: roomView(hand: 1, seats: seats, phase: WirePhase.lobby),
        ),
        me: 'p_0',
        host: true,
      ),
    );

    List<SoundCue> host(ServerMessage message) => feed(message, me: 'p_0', host: true);

    test('a new hand is riffled, and the lobby is not', () {
      expect(host(update(roomView(hand: 2, seats: seats))), [SoundCue.shuffle]);
    });

    test('the flop, the turn and the river, from the board', () {
      host(update(roomView(hand: 1, seats: seats)));
      final board = [card('2c'), card('7d'), card('Kh'), card('9s'), card('3c')];
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.flop, board: board.take(3).toList()), 3)), [SoundCue.flop]);
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.turn, board: board.take(4).toList()), 4)), [SoundCue.street]);
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.river, board: board), 5)), [SoundCue.street]);
    });

    test('a room with real cards has an empty board, so the phase tells the street', () {
      host(update(roomView(hand: 1, seats: seats)));
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.flop), 3)), [SoundCue.flop]);
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.turn), 4)), [SoundCue.street]);
    });

    test('everybody\'s actions are heard', () {
      expect(host(acted('p_1', ActionKind.fold)), [SoundCue.fold]);
      expect(host(acted('p_2', ActionKind.check)), [SoundCue.check]);
      expect(host(acted('p_1', ActionKind.call)), [SoundCue.call]);
      expect(host(acted('p_1', ActionKind.bet)), [SoundCue.call]);
      expect(host(acted('p_2', ActionKind.raise)), [SoundCue.raise]);
      expect(host(acted('p_2', ActionKind.raise, allIn: true)), [SoundCue.allIn]);
      expect(host(acted('p_2', ActionKind.unknown)), isEmpty);
    });

    test('hands turned over, then the pot drawn in', () {
      host(update(roomView(hand: 1, seats: seats)));
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.showdown, reveals: shown), 3)), [SoundCue.reveal]);
      expect(host(update(roomView(hand: 1, seats: seats, phase: WirePhase.nextHandPrep, reveals: shown, result: winOne), 4)), [SoundCue.potWon]);
    });

    test('hands and pot in one update make one sound, not two on top of each other', () {
      host(update(roomView(hand: 1, seats: seats)));
      expect(host(update(roomView(hand: 1, seats: seats, reveals: shown, result: winOne), 3)), [SoundCue.potWon]);
    });

    test('somebody sitting down or leaving', () {
      expect(host(update(roomView(hand: 1, seats: [...seats, seatView(3, 'Cy')]))), [SoundCue.join]);
      expect(host(update(roomView(hand: 1, seats: seats), 3)), [SoundCue.leave]);
    });
  });

  group('a room that deals real cards (the view carries no board, reveals or result)', () {
    RoomView at(WirePhase phase, {int ana = 1000, int bo = 1000}) => roomView(
      hand: 1,
      phase: phase,
      seats: [
        seatView(0, 'Host'),
        seatView(1, 'Ana', chips: ana),
        seatView(2, 'Bo', chips: bo),
      ],
    );

    setUp(() => feed(snapshot(view: at(WirePhase.river)), me: 'p_0', host: true));

    test('the table hears the hands at showdown and the pot at the end of the hand', () {
      expect(feed(update(at(WirePhase.showdown), 3), me: 'p_0', host: true), [SoundCue.reveal]);
      expect(feed(update(at(WirePhase.nextHandPrep, ana: 1100, bo: 900), 4), me: 'p_0', host: true), [SoundCue.potWon]);
    });

    test('a guest hears a win when its own stack grew as the hand ended, and nothing when it did not', () {
      tracker.reset();
      feed(snapshot(view: at(WirePhase.river)));
      expect(feed(update(at(WirePhase.showdown), 3)), isEmpty, reason: 'the hands shown are the table\'s');
      expect(feed(update(at(WirePhase.nextHandPrep, ana: 1100, bo: 900), 4)), [SoundCue.win]);

      tracker.reset();
      feed(snapshot(view: at(WirePhase.river)));
      expect(feed(update(at(WirePhase.nextHandPrep, ana: 900, bo: 1100), 3)), isEmpty);
    });

    test('a snapshot taken at the end of a hand does not pay the pot again', () {
      tracker.reset();
      feed(snapshot(view: at(WirePhase.nextHandPrep, ana: 1100, bo: 900)), me: 'p_0', host: true);
      expect(feed(update(at(WirePhase.nextHandPrep, ana: 1100, bo: 900), 3), me: 'p_0', host: true), isEmpty);
    });
  });

  group('a seated guest', () {
    setUp(() => feed(snapshot(view: roomView(hand: 1, seats: seats))));

    test('hears its own cards, once per hand', () {
      expect(feed(holeCards('As', 'Kd', hand: 2)), [SoundCue.deal]);
      expect(feed(holeCards('As', 'Kd', hand: 2)), isEmpty);
      expect(feed(holeCards('2c', '7d', hand: 3)), [SoundCue.deal]);
    });

    test('hears its own actions but not the others\'', () {
      expect(feed(acted('p_1', ActionKind.call)), [SoundCue.call]);
      expect(feed(acted('p_2', ActionKind.call)), isEmpty);
    });

    test('does not hear the table: shuffle, board, reveal, join, leave', () {
      expect(feed(update(roomView(hand: 2, seats: [...seats, seatView(3, 'Cy')]))), isEmpty);
      final board = [card('2c'), card('7d'), card('Kh')];
      expect(feed(update(roomView(hand: 2, phase: WirePhase.flop, board: board, seats: seats), 3)), isEmpty);
      expect(feed(update(roomView(hand: 2, phase: WirePhase.showdown, reveals: shown, seats: seats), 4)), isEmpty);
    });

    test('hears its own win, and nothing when somebody else wins', () {
      expect(feed(update(roomView(hand: 1, seats: seats, result: winOne), 3)), [SoundCue.win]);
      feed(update(roomView(hand: 2, seats: seats), 4));
      expect(
        feed(
          update(roomView(hand: 2, seats: seats, result: winOne), 5),
          me: 'p_2',
        ),
        isEmpty,
      );
    });
  });

  group('a single-player game (the view carries blinds)', () {
    RoomView solo(
      int hand, {
      int small = 10,
      List<Finish> finish = const [],
      HandResult? result,
      List<Reveal> reveals = const [],
    }) =>
        roomView(
          hand: hand,
          seats: seats,
          result: result,
          reveals: reveals,
        ).copyWith(
          blinds: BlindsView(smallBlind: small, bigBlind: small * 2),
          finishOrder: finish,
        );

    setUp(() => feed(snapshot(view: solo(1))));

    test('hears everything on the one phone, but no riffle: the cards are dealt to you', () {
      expect(feed(update(solo(2))), isEmpty);
      expect(feed(holeCards('As', 'Kd', hand: 2)), [SoundCue.deal]);
      expect(feed(acted('p_2', ActionKind.raise)), [SoundCue.raise]);
      expect(feed(acted('p_1', ActionKind.check)), [SoundCue.check]);
    });

    test('the blinds going up', () {
      expect(feed(update(solo(2, small: 20))), [SoundCue.levelUp]);
      expect(feed(update(solo(2, small: 20), 3)), isEmpty);
    });

    test('winning a pot, and losing one', () {
      expect(feed(update(solo(1, result: winOne), 3)), [SoundCue.win]);
      feed(update(solo(2), 4));
      expect(feed(update(solo(2, result: winOne), 5), me: 'p_2'), [SoundCue.potWon]);
    });

    test('going out ends with one sound, and the pot does not play over it', () {
      final out = solo(
        1,
        result: winOne,
        finish: const [Finish(playerId: 'p_1', name: 'Ana', place: 3)],
      );
      expect(feed(update(out, 3)), [SoundCue.out]);
    });

    test('winning the game', () {
      final won = solo(
        1,
        result: winOne,
        finish: const [Finish(playerId: 'p_1', name: 'Ana', place: 1)],
      );
      expect(feed(update(won, 3)), [SoundCue.gameWon]);
    });

    test('a computer player going out is not your sound', () {
      final other = solo(
        1,
        finish: const [Finish(playerId: 'p_2', name: 'Bo', place: 3)],
      );
      expect(feed(update(other, 3)), isEmpty);
    });
  });

  test('every cue has at least one clip and no clip is shared', () {
    final clips = [for (final cue in SoundCue.values) ...cue.clips];
    expect(SoundCue.values.every((cue) => cue.clips.isNotEmpty), isTrue);
    expect(clips.toSet().length, clips.length);
  });
}
