import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/solo_result.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

HandResult _paid(Map<String, int> shares) => HandResult(
  uncontested: false,
  pots: <PotResult>[
    PotResult(
      potIndex: 0,
      amount: shares.values.fold(0, (a, b) => a + b),
      winnerPlayerIds: shares.keys.toList(),
      shares: <Share>[for (final e in shares.entries) Share(playerId: e.key, name: e.key, amount: e.value)],
    ),
  ],
);

Reveal _showed(String id, HandCategory category) => Reveal(
  playerId: id,
  name: id,
  cards: <PokerCard>[card('As'), card('Kd')],
  category: category,
  bestFive: <PokerCard>[card('As'), card('Kd'), card('9c'), card('4h'), card('2d')],
);

void main() {
  group('SoloStats', () {
    test('counts a paid hand once, however often the view is repeated', () {
      var stats = const SoloStats();
      final view = roomView(hand: 4, result: _paid(<String, int>{'p_1': 300}), reveals: <Reveal>[_showed('p_1', HandCategory.flush)]);
      stats = stats.observe(view, 'p_1');
      expect((stats.handsPlayed, stats.handsWon, stats.biggestWin, stats.bestHand), (1, 1, 300, HandCategory.flush));
      expect(stats.observe(view, 'p_1'), same(stats), reason: 'the same hand is not counted again');
      expect(stats.observe(roomView(hand: 3, result: _paid(<String, int>{'p_1': 999})), 'p_1'), same(stats), reason: 'an older hand is ignored');
    });

    test('a lost hand counts as played, keeps the best hand and the biggest win', () {
      var stats = const SoloStats();
      stats = stats.observe(
        roomView(hand: 1, result: _paid(<String, int>{'p_1': 500}), reveals: <Reveal>[_showed('p_1', HandCategory.fullHouse)]),
        'p_1',
      );
      stats = stats.observe(
        roomView(
          hand: 2,
          result: _paid(<String, int>{'p_2': 80}),
          reveals: <Reveal>[_showed('p_1', HandCategory.pair), _showed('p_2', HandCategory.twoPair)],
        ),
        'p_1',
      );
      stats = stats.observe(roomView(hand: 3, result: _paid(<String, int>{'p_1': 120})), 'p_1');
      expect((stats.handsPlayed, stats.handsWon, stats.biggestWin, stats.bestHand), (3, 2, 500, HandCategory.fullHouse));
    });

    test('a view without a payout, or without knowing who I am, changes nothing', () {
      const stats = SoloStats();
      expect(stats.observe(roomView(hand: 1), 'p_1'), same(stats));
      expect(stats.observe(roomView(hand: 1, result: _paid(<String, int>{'p_1': 5})), null), same(stats));
    });

    test('shares from several pots add up for one hand', () {
      const result = HandResult(
        uncontested: false,
        pots: <PotResult>[
          PotResult(
            potIndex: 0,
            amount: 100,
            winnerPlayerIds: <String>['p_1'],
            shares: <Share>[Share(playerId: 'p_1', name: 'a', amount: 100)],
          ),
          PotResult(
            potIndex: 1,
            amount: 60,
            winnerPlayerIds: <String>['p_1'],
            shares: <Share>[Share(playerId: 'p_1', name: 'a', amount: 60)],
          ),
        ],
      );
      final stats = const SoloStats().observe(roomView(hand: 2, result: result), 'p_1');
      expect(stats.biggestWin, 160);
      expect(stats.handsWon, 1);
    });
  });

  group('SoloResult', () {
    final order = <Finish>[
      const Finish(playerId: 'p_3', name: 'Liam', place: 3),
      const Finish(playerId: 'p_1', name: 'Dimath', place: 2),
      const Finish(playerId: 'p_2', name: 'Maya', place: 1),
    ];

    test('is absent while I am still in, and gives my place of everyone who started when I am out', () {
      final view = roomView(hand: 9).copyWith(finishOrder: order.take(1).toList());
      expect(SoloResult.from(view, 'p_1', const SoloStats()), isNull);
      final done = roomView(hand: 9).copyWith(finishOrder: order);
      final result = SoloResult.from(done, 'p_1', const SoloStats())!;
      expect((result.place, result.of, result.won), (2, 3, false));
      expect(SoloResult.from(done, 'p_2', const SoloStats())!.won, isTrue);
      expect(SoloResult.from(done, null, const SoloStats()), isNull);
    });

    test('counts everyone who started when only I have gone out: the first out takes the last place', () {
      // The server lists a player when they go out: at my exit the order holds just me, third of three.
      final view =
          roomView(
            hand: 9,
            seats: <SeatView>[seatView(0, 'Maya', chips: 2500), seatView(1, 'Dimath', chips: 0), seatView(2, 'Liam', chips: 500)],
          ).copyWith(
            finishOrder: const <Finish>[Finish(playerId: 'p_1', name: 'Dimath', place: 3)],
          );
      final result = SoloResult.from(view, 'p_1', const SoloStats())!;
      expect((result.place, result.of), (3, 3));
    });
  });

  test('newlyOut returns only the places not announced yet', () {
    final order = <Finish>[const Finish(playerId: 'a', name: 'A', place: 4), const Finish(playerId: 'b', name: 'B', place: 3)];
    expect(newlyOut(order, 0).map((f) => f.name), <String>['A', 'B']);
    expect(newlyOut(order, 1).map((f) => f.name), <String>['B']);
    expect(newlyOut(order, 2), isEmpty);
    expect(newlyOut(order, 5), isEmpty, reason: 'a shorter list than seen is nothing new');
  });
}
