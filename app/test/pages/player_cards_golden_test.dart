import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

const Map<String, Size> _sizes = <String, Size>{'phone_portrait': Size(390, 844), 'tablet_landscape': Size(1280, 800)};

final List<SeatView> _seats = <SeatView>[
  seatView(0, 'Dimath', chips: 1500, hasCards: true),
  seatView(1, 'Alice', chips: 940, bet: 20, hasCards: true),
  seatView(2, 'Bob', chips: 1200, folded: true),
  seatView(3, 'Cara', chips: 610, hasCards: true),
];

final List<PokerCard> _board = <PokerCard>[card('Kd'), card('9c'), card('6c'), card('Jh')];

const LegalActions _legal = LegalActions(
  canFold: true,
  canCheck: false,
  canCall: true,
  callAmount: 20,
  canRaise: true,
  minRaiseTo: 40,
  maxRaiseTo: 940,
);

Future<TestHarness> _open(WidgetTester tester, Size size, RoomView view, {bool myTurn = false}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = TestHarness();
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'KQ7M');
  await tester.enterText(find.byType(TextField).at(1), 'Alice');
  await tester.ensureVisible(find.text('JOIN'));
  await tester.tap(find.text('JOIN'));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  harness.network.last
    ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
    ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: view))
    ..serverSends(holeCards('As', 'Kh', hand: 3));
  if (myTurn) harness.network.last.serverSends(const TurnPrompt(playerId: 'p_1', seatIndex: 1, nextActionSeq: 4, legal: _legal));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return harness;
}

void main() {
  setUpAll(loadFonts);

  for (final entry in _sizes.entries) {
    testWidgets('virtual player, my turn, cards face up, ${entry.key}', (tester) async {
      final view = roomView(
        hand: 3,
        activeSeat: 1,
        pot: 90,
        seats: _seats,
        deadline: 1730000021000,
        board: _board,
      ).copyWith(currentHighBet: 20, minRaiseTo: 40);
      await _open(tester, entry.value, view, myTurn: true);
      await tester.tap(find.byType(HoleCardsDock));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_virtual_turn_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('virtual player, showdown, ${entry.key}', (tester) async {
      final board = <PokerCard>[..._board, card('2d')];
      Reveal reveal(String id, String name, List<PokerCard> hole, HandCategory category, List<PokerCard> best) =>
          Reveal(playerId: id, name: name, cards: hole, category: category, bestFive: best);
      final view = roomView(
        hand: 3,
        phase: WirePhase.showdown,
        pot: 0,
        seats: _seats,
        board: board,
        reveals: <Reveal>[
          reveal(
            'p_0',
            'Dimath',
            <PokerCard>[card('Kc'), card('Ks')],
            HandCategory.threeOfAKind,
            <PokerCard>[card('Kc'), card('Ks'), card('Kd'), card('Jh'), card('9c')],
          ),
          reveal(
            'p_1',
            'Alice',
            <PokerCard>[card('As'), card('Kh')],
            HandCategory.pair,
            <PokerCard>[card('Kh'), card('Kd'), card('As'), card('Jh'), card('9c')],
          ),
        ],
        result: const HandResult(
          uncontested: false,
          pots: <PotResult>[
            PotResult(
              potIndex: 0,
              amount: 150,
              winnerPlayerIds: <String>['p_0'],
              shares: <Share>[Share(playerId: 'p_0', name: 'Dimath', amount: 150)],
            ),
          ],
        ),
      );
      await _open(tester, entry.value, view);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await tester.pump(const Duration(seconds: 4)); // the cards finish turning over
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_virtual_showdown_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
