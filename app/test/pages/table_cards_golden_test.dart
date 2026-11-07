import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

const Map<String, Size> _sizes = <String, Size>{'phone_portrait': Size(390, 844), 'tablet_landscape': Size(1280, 800), 'tv': Size(1920, 1080)};

List<SeatView> _seats() => <SeatView>[
  seatView(0, 'Dimath', chips: 940, hasCards: true).copyWith(playerId: 'p_host'),
  seatView(1, 'Alice', chips: 1200, bet: 60, hasCards: true),
  seatView(2, 'Bob', chips: 300, folded: true),
  seatView(3, 'Cara', chips: 610, bet: 60, hasCards: true),
  seatView(5, 'Dan', chips: 75, hasCards: true),
];

Future<void> _open(WidgetTester tester, Size size, RoomView view) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = TestHarness();
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Dimath');
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  harness.network.last
    ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: view))
    ..serverSends(holeCards('As', 'Kh', hand: 5));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  for (final entry in _sizes.entries) {
    testWidgets('virtual table, betting on the turn, ${entry.key}', (tester) async {
      final view = roomView(
        hand: 5,
        activeSeat: 1,
        pot: 240,
        seats: _seats(),
        deadline: 1730000021000,
        board: <PokerCard>[card('Kd'), card('9c'), card('6c'), card('Jh')],
      ).copyWith(dealerSeat: 0, currentHighBet: 60, minRaiseTo: 120);
      await _open(tester, entry.value, view);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await tester.pump(const Duration(seconds: 2)); // the cards finish turning over
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/table_virtual_betting_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('virtual table, showdown, ${entry.key}', (tester) async {
      Reveal reveal(String id, String name, List<PokerCard> hole, HandCategory category) =>
          Reveal(playerId: id, name: name, cards: hole, category: category, bestFive: const <PokerCard>[]);
      final view = roomView(
        hand: 5,
        phase: WirePhase.showdown,
        pot: 0,
        seats: _seats(),
        board: <PokerCard>[card('Kd'), card('9c'), card('6c'), card('Jh'), card('2c')],
        reveals: <Reveal>[
          reveal('p_1', 'Alice', <PokerCard>[card('Kh'), card('Kc')], HandCategory.threeOfAKind),
          reveal('p_3', 'Cara', <PokerCard>[card('As'), card('2h')], HandCategory.pair),
          reveal('p_5', 'Dan', <PokerCard>[card('Qs'), card('Td')], HandCategory.straight),
        ],
        result: const HandResult(
          uncontested: false,
          pots: <PotResult>[
            PotResult(
              potIndex: 0,
              amount: 180,
              winnerPlayerIds: <String>['p_1'],
              shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 180)],
            ),
            PotResult(
              potIndex: 1,
              amount: 60,
              winnerPlayerIds: <String>['p_5'],
              shares: <Share>[Share(playerId: 'p_5', name: 'Dan', amount: 60)],
            ),
          ],
        ),
      ).copyWith(dealerSeat: 0);
      await _open(tester, entry.value, view);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await tester.pump(const Duration(seconds: 4)); // the cards finish turning over
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/table_virtual_showdown_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
