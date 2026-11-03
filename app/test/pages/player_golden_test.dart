import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

const Map<String, Size> _sizes = <String, Size>{'phone_portrait': Size(390, 844), 'tablet_landscape': Size(1280, 800), 'tv': Size(1920, 1080)};

final List<SeatView> _seats = <SeatView>[
  seatView(0, 'Dimath', chips: 1500),
  seatView(1, 'Alice', chips: 940, bet: 20),
  seatView(2, 'Bob', chips: 1200),
];

RoomView _view({required int active}) => roomView(hand: 3, activeSeat: active, pot: 60, seats: _seats, deadline: 1730000021000).copyWith(
  currentHighBet: 20,
  minRaiseTo: 40,
  dealerSeat: 0,
);

const LegalActions _legal = LegalActions(
  canFold: true,
  canCheck: false,
  canCall: true,
  callAmount: 20,
  canRaise: true,
  minRaiseTo: 40,
  maxRaiseTo: 940,
);

Future<TestHarness> _open(WidgetTester tester, Size size, {required bool myTurn}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = TestHarness();
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'KQ7M');
  await tester.enterText(fields.at(1), '192.168.1.5');
  await tester.enterText(fields.at(2), 'Alice');
  await tester.ensureVisible(find.text('JOIN'));
  await tester.tap(find.text('JOIN'));
  await tester.pump();
  await tester.pump();
  harness.network.last
    ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
    ..serverSends(
      snapshot(
        version: 1,
        serverTime: harness.clock.millisecondsSinceEpoch,
        nextActionSeq: 4,
        view: _view(active: myTurn ? 1 : 2),
      ),
    );
  if (myTurn) harness.network.last.serverSends(const TurnPrompt(playerId: 'p_1', seatIndex: 1, nextActionSeq: 4, legal: _legal));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return harness;
}

void main() {
  setUpAll(loadFonts);

  for (final entry in _sizes.entries) {
    testWidgets('player waiting, ${entry.key}', (tester) async {
      await _open(tester, entry.value, myTurn: false);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_waiting_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('player your turn, ${entry.key}', (tester) async {
      await _open(tester, entry.value, myTurn: true);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_turn_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('player raise sheet, ${entry.key}', (tester) async {
      await _open(tester, entry.value, myTurn: true);
      await tester.tap(find.text('RAISE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_raise_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
