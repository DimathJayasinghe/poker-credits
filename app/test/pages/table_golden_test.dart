import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

final _seats = <SeatView>[
  seatView(0, 'Alice', chips: 940, bet: 60),
  seatView(1, 'Bob', chips: 1200, bet: 60),
  seatView(2, 'Cara', chips: 0, allIn: true),
  seatView(3, 'Dan', chips: 75, folded: true),
  seatView(4, 'Eve', chips: 500, away: true),
  seatView(5, 'Fay', chips: 310),
  seatView(6, 'Gus', chips: 880, connected: false),
  seatView(8, 'Hal', chips: 1500),
  seatView(9, 'Ivy', chips: 640),
];

const _sizes = <String, Size>{'phone_portrait': Size(390, 844), 'tablet_landscape': Size(1280, 800), 'tv': Size(1920, 1080)};

Future<void> _open(WidgetTester tester, TestHarness harness, RoomView view, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  harness.network.last.serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: view));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  final betting = roomView(hand: 7, activeSeat: 1, pot: 210, seats: _seats, deadline: 1730000021000).copyWith(
    dealerSeat: 6,
    smallBlindSeat: 8,
    bigBlindSeat: 9,
    currentHighBet: 60,
    minRaiseTo: 120,
    pots: const <PotView>[],
  );
  final lobby = roomView(seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice'), seatView(2, 'Bob')]).copyWith(phase: WirePhase.lobby);

  for (final entry in _sizes.entries) {
    testWidgets('table during betting, ${entry.key}', (tester) async {
      await _open(tester, TestHarness(), betting, entry.value);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/table_betting_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lobby with QR, ${entry.key}', (tester) async {
      await _open(tester, TestHarness(), lobby, entry.value);
      expect(tester.takeException(), isNull, reason: 'no layout overflow');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/table_lobby_${entry.key}.png'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
