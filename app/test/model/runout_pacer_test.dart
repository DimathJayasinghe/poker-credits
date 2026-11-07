import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/runout_pacer.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

PokerCard c(String t) => PokerCard.parse(t);

final flop = <PokerCard>[c('Kd'), c('9c'), c('6c')];
final turn = <PokerCard>[...flop, c('Jh')];
final river = <PokerCard>[...turn, c('2c')];

void main() {
  final t0 = DateTime(2026, 1, 1);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('the first sight of a hand shows its board at once, however far along it is', () {
    final pacer = RunoutPacer();
    expect(pacer.shown(4, river, at(0)), river);
    expect(pacer.settled(river), isTrue);
  });

  test('a normal street (flop, turn, river) appears at once', () {
    final pacer = RunoutPacer();
    expect(pacer.shown(4, const <PokerCard>[], at(0)), isEmpty);
    expect(pacer.shown(4, flop, at(10)), flop);
    expect(pacer.shown(4, turn, at(20)), turn);
    expect(pacer.shown(4, river, at(30)), river);
    expect(pacer.settled(river), isTrue);
  });

  test('a run-out from the flop shows the turn at once and the river 700 ms later', () {
    final pacer = RunoutPacer()..shown(4, flop, at(0));
    expect(pacer.shown(4, river, at(100)), turn);
    expect(pacer.settled(river), isFalse);
    expect(pacer.shown(4, river, at(799)), turn, reason: 'not yet');
    expect(pacer.shown(4, river, at(800)), river);
    expect(pacer.settled(river), isTrue);
  });

  test('a run-out from nothing deals flop, turn and river 700 ms apart', () {
    final pacer = RunoutPacer()..shown(4, const <PokerCard>[], at(0));
    expect(pacer.shown(4, river, at(1000)), flop);
    expect(pacer.shown(4, river, at(1700)), turn);
    expect(pacer.shown(4, river, at(2400)), river);
  });

  test('a slow frame never skips a street', () {
    final pacer = RunoutPacer()..shown(4, const <PokerCard>[], at(0));
    pacer.shown(4, river, at(1000));
    expect(pacer.shown(4, river, at(9000)), turn, reason: 'one street per call');
    expect(pacer.shown(4, river, at(9100)), turn);
    expect(pacer.shown(4, river, at(9700)), river);
  });

  test('a new hand starts from its own board with no pacing', () {
    final pacer = RunoutPacer()..shown(4, river, at(0));
    expect(pacer.shown(5, const <PokerCard>[], at(10)), isEmpty);
    expect(pacer.shown(5, flop, at(20)), flop);
  });

  test('a board that shrinks or changes under us (undo, resync) is taken as it is', () {
    final pacer = RunoutPacer()..shown(4, turn, at(0));
    expect(pacer.shown(4, flop, at(10)), flop);
    final other = <PokerCard>[c('As'), c('Ks'), c('Qs'), c('Js'), c('Ts')];
    expect(pacer.shown(4, other, at(20)), other);
  });

  test('instant skips every delay (reduced motion, a returning player)', () {
    final pacer = RunoutPacer()..shown(4, flop, at(0));
    expect(pacer.shown(4, river, at(10), instant: true), river);
  });

  test('settled is true when there is nothing to wait for', () {
    final pacer = RunoutPacer();
    expect(pacer.settled(const <PokerCard>[]), isTrue);
  });

  group('paced view (no spoiler while the run-out is dealt)', () {
    const payout = HandResult(
      uncontested: false,
      pots: <PotResult>[
        PotResult(
          potIndex: 0,
          amount: 200,
          winnerPlayerIds: <String>['p_1'],
          shares: <Share>[Share(playerId: 'p_1', name: 'B', amount: 200)],
        ),
      ],
    );

    // Before: both all in, 100 each, pot 200, flop on the table. After: the server has paid p_1.
    RoomView before() => roomView(
      hand: 4,
      pot: 200,
      board: flop,
      seats: <SeatView>[seatView(0, 'A', chips: 0, bet: 100, allIn: true), seatView(1, 'B', chips: 0, bet: 100, allIn: true)],
    );
    RoomView after() => roomView(
      hand: 4,
      pot: 0,
      board: river,
      reveals: <Reveal>[
        Reveal(playerId: 'p_1', name: 'B', cards: <PokerCard>[c('As'), c('Ad')], category: HandCategory.pair, bestFive: river),
      ],
      result: payout,
      seats: <SeatView>[seatView(0, 'A', chips: 0), seatView(1, 'B', chips: 200)],
    );

    test('chips, pot, winners and reveals stay as they were until the last card is down', () {
      final pacer = RunoutPacer();
      pacer.paced(before(), at(0));
      final mid = pacer.paced(after(), at(100));
      expect(mid.board, turn);
      expect(mid.totalPot, 200, reason: 'the pot has not been paid on screen yet');
      expect(mid.seats[1].chips, 0, reason: 'nor the winner\'s stack');
      expect(mid.seats[1].streetBet, 100);
      expect(mid.result, isNull);
      expect(mid.reveals, isEmpty);
      final done = pacer.paced(after(), at(900));
      expect(done.board, river);
      expect(done.totalPot, 0);
      expect(done.seats[1].chips, 200);
      expect(done.result, isNotNull);
      expect(done.reveals, hasLength(1));
    });

    test('a viewer who first sees the hand mid run-out gets the real numbers at once', () {
      final pacer = RunoutPacer();
      final view = pacer.paced(after(), at(0));
      expect(view.board, river);
      expect(view.seats[1].chips, 200);
      expect(view.result, isNotNull);
    });

    test('an ordinary street passes through untouched', () {
      final pacer = RunoutPacer();
      final raw = roomView(hand: 4, pot: 40, board: flop, seats: <SeatView>[seatView(0, 'A', chips: 480)]);
      expect(identical(pacer.paced(raw, at(0)), raw), isTrue);
    });
  });
}
