import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/widget/table/felt_layout.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

/// A full table: all ten seats, the host (seat 0) on turn.
final List<SeatView> _full = <SeatView>[
  seatView(0, 'Dimath', chips: 980).copyWith(playerId: 'p_host'),
  seatView(1, 'Alice', chips: 940, bet: 20),
  seatView(2, 'Bob', chips: 1200),
  seatView(3, 'Cara', chips: 0, allIn: true),
  seatView(4, 'Dan', chips: 75, folded: true),
  seatView(5, 'Eve', chips: 500, away: true),
  seatView(6, 'Fay', chips: 310),
  seatView(7, 'Gus', chips: 880, connected: false),
  seatView(8, 'Hal', chips: 1500),
  seatView(9, 'Ivy', chips: 640),
];

const LegalActions _legal = LegalActions(
  canFold: true,
  canCheck: false,
  canCall: true,
  callAmount: 20,
  canRaise: true,
  minRaiseTo: 40,
  maxRaiseTo: 940,
);

Future<void> _openTable(WidgetTester tester, TestHarness harness, Size size, {required bool hostOnTurn, double textScale = 1}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.ensureVisible(find.text('HOST A GAME'));
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Dimath');
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final view = roomView(
    hand: 3,
    activeSeat: hostOnTurn ? 0 : 2,
    pot: 210,
    seats: _full,
    deadline: 1730000021000,
  ).copyWith(dealerSeat: 5, smallBlindSeat: 6, bigBlindSeat: 7, currentHighBet: 20, minRaiseTo: 40);
  harness.network.last.serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: view));
  if (hostOnTurn) harness.network.last.serverSends(const TurnPrompt(playerId: 'p_host', seatIndex: 0, nextActionSeq: 7, legal: _legal));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  const sizes = <String, Size>{
    'tv 1920x1080': Size(1920, 1080),
    'tablet landscape 1280x800': Size(1280, 800),
    'small tablet 1024x600': Size(1024, 600),
    'phone landscape 844x390': Size(844, 390),
    'short window 700x420': Size(700, 420),
    'phone portrait 390x844': Size(390, 844),
    'small phone 320x568': Size(320, 568),
  };

  for (final entry in sizes.entries) {
    for (final hostOnTurn in <bool>[false, true]) {
      for (final scale in <double>[1, 2]) {
        testWidgets('${entry.key}, host ${hostOnTurn ? 'on turn' : 'waiting'}, text x$scale: no plate hides another or the pot', (tester) async {
          await _openTable(tester, TestHarness(), entry.value, hostOnTurn: hostOnTurn, textScale: scale);
          expect(tester.takeException(), isNull, reason: 'no overflow');

          final plates = find.byType(SeatPlate);
          expect(plates, findsNWidgets(10), reason: 'every player has a plate');
          final rects = <Rect>[for (var i = 0; i < 10; i++) tester.getRect(plates.at(i))];
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse, reason: 'plates $i and $j overlap: ${rects[i]} ${rects[j]}');
            }
          }
          final pot = tester.getRect(find.byType(PotDisplay));
          for (var i = 0; i < rects.length; i++) {
            expect(rects[i].overlaps(pot), isFalse, reason: 'plate $i covers the pot: ${rects[i]} $pot');
          }
          // The player's own buttons are on screen whenever it is their turn.
          if (hostOnTurn) {
            await tester.ensureVisible(find.text('CALL 20'));
            final screen = Offset.zero & entry.value;
            expect(screen.contains(tester.getCenter(find.text('CALL 20'))), isTrue, reason: 'CALL is reachable');
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  test('the oval is only chosen when ten plates fit around the pot', () {
    expect(FeltLayout.ovalFits(const Size(1280, 640), 100), isTrue);
    expect(FeltLayout.ovalFits(const Size(1280, 400), 100), isFalse, reason: 'too short');
    expect(FeltLayout.ovalFits(const Size(500, 900), 100), isFalse, reason: 'too narrow');
    expect(FeltLayout.ovalFits(const Size(1280, 640), 200), isFalse, reason: 'big text needs more room');
  });

  test('slots run clockwise from the bottom centre', () {
    final first = FeltLayout.slot(0, 10);
    expect(first.dx, closeTo(0, 1e-9));
    expect(first.dy, closeTo(1, 1e-9));
    expect(FeltLayout.slot(5, 10).dy, closeTo(-1, 1e-9), reason: 'seat 6 is opposite seat 1');
    expect(FeltLayout.slot(1, 10).dx, lessThan(0), reason: 'seat 2 is clockwise (left) of seat 1 as seen from the bottom');
  });
}
