import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

/// Layout sweep: every game screen must hold, without a single overflow, at the biggest text
/// sizes the operating systems allow (docs/UI_DESIGN.md section 6), on a small phone, a normal
/// phone and a tablet. A scaled screen may scroll; it may never clip or throw.

const List<double> _scales = <double>[1.0, 2.0, 3.0];
const List<Size> _sizes = <Size>[Size(320, 640), Size(390, 844), Size(1280, 800)];

final List<SeatView> _seats = <SeatView>[
  seatView(0, 'Dimath', chips: 1500),
  seatView(1, 'Alice', chips: 940, bet: 20),
  seatView(2, 'Bob', chips: 1200),
  seatView(3, 'Cara', chips: 0, allIn: true),
  seatView(4, 'Dan', chips: 75, folded: true),
  seatView(5, 'Eve', chips: 500, away: true),
  seatView(6, 'Gus', chips: 880, connected: false),
  seatView(7, 'Hal', chips: 123456),
];

RoomView _betting({int active = 1}) => roomView(hand: 12, activeSeat: active, pot: 98765, seats: _seats, deadline: 1730000021000).copyWith(
  currentHighBet: 20,
  minRaiseTo: 40,
  dealerSeat: 0,
  smallBlindSeat: 1,
  bigBlindSeat: 2,
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

void _noOverflow(WidgetTester tester, [String where = '']) {
  final error = tester.takeException();
  if (error != null) fail('$where: ${error is FlutterError ? error.toStringDeep() : error}');
}

Future<void> _pump(WidgetTester tester, Size size, double scale, TestHarness harness) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: harness.scope(const PokerCreditsApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openJoin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('JOIN A GAME'));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
}

Future<void> _joinAsAlice(WidgetTester tester, TestHarness harness, {required RoomView view, TurnPrompt? prompt}) async {
  await _openJoin(tester);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'KQ7M');
  await tester.enterText(fields.at(1), 'Alice');
  await tester.ensureVisible(find.text('JOIN'));
  await tester.tap(find.text('JOIN'));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  harness.network.last
    ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
    ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: view));
  if (prompt != null) harness.network.last.serverSends(prompt);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _hostAs(WidgetTester tester, TestHarness harness, RoomView view) async {
  await tester.ensureVisible(find.text('HOST A GAME'));
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
  // A tap that lands outside its widget is a test that proves nothing: fail instead of warning.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('sanity: the sweep really scales the text', (tester) async {
    await _pump(tester, const Size(390, 844), 1, TestHarness());
    final normal = tester.getSize(find.text('HOST A GAME')).height;
    await _pump(tester, const Size(390, 844), 3, TestHarness());
    expect(tester.getSize(find.text('HOST A GAME')).height, greaterThan(normal * 2));
  });

  testWidgets('the host table stops growing the text at 200 %', (tester) async {
    final harness = TestHarness();
    await _pump(tester, const Size(1280, 800), 3, harness);
    await _hostAs(tester, harness, _betting());
    final scaler = MediaQuery.textScalerOf(tester.element(find.byType(SeatPlate).first));
    expect(scaler.scale(10), 20);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scale in _scales) {
    for (final size in _sizes) {
      final where = 'text scale $scale on ${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('join page holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await _openJoin(tester);
        _noOverflow(tester);
        // Submit empty: every field error shows at once.
        await tester.ensureVisible(find.text('JOIN'));
        await tester.tap(find.text('JOIN'));
        await tester.pump();
        _noOverflow(tester, 'with the validation messages shown');
        // The address field and the long "not found" banner.
        await tester.ensureVisible(find.text('ENTER HOST ADDRESS INSTEAD'));
        await tester.tap(find.text('ENTER HOST ADDRESS INSTEAD'));
        await tester.pump();
        _noOverflow(tester, 'with the address field');
      });

      testWidgets('host page holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await tester.ensureVisible(find.text('HOST A GAME'));
        await tester.pump();
        await tester.tap(find.text('HOST A GAME'));
        await tester.pumpAndSettle();
        _noOverflow(tester);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.ensureVisible(find.text('START HOSTING'));
        await tester.tap(find.text('START HOSTING'));
        await tester.pump();
        _noOverflow(tester, 'with the name error shown');
      });

      testWidgets('player page, waiting, holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await _joinAsAlice(tester, harness, view: _betting(active: 2));
        _noOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('player page, virtual hand with a full board and a showdown, holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        final board = <PokerCard>[card('9c'), card('Jh'), card('2d'), card('Ks'), card('3c')];
        final seats = <SeatView>[
          for (final seat in _seats)
            SeatView(
              seatIndex: seat.seatIndex,
              playerId: seat.playerId,
              name: seat.name,
              chips: seat.chips,
              streetBet: seat.streetBet,
              hasFolded: seat.hasFolded,
              isAllIn: seat.isAllIn,
              isSittingOut: seat.isSittingOut,
              isConnected: seat.isConnected,
              hasCards: !seat.hasFolded,
            ),
        ];
        await _joinAsAlice(
          tester,
          harness,
          view: _betting().copyWith(seats: seats, board: board),
        );
        harness.network.last.serverSends(holeCards('As', 'Kd', hand: 12));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byType(HoleCardsDock), warnIfMissed: false);
        await tester.pumpAndSettle();
        _noOverflow(tester, 'cards face up');

        Reveal reveal(String id, String name) => Reveal(
          playerId: id,
          name: name,
          cards: <PokerCard>[card('As'), card('Kd')],
          category: HandCategory.pair,
          bestFive: <PokerCard>[card('Kd'), card('Ks'), card('Jh'), card('9c'), card('3c')],
        );
        harness.network.last.serverSends(
          StateUpdate(
            stateVersion: 2,
            view: _betting().copyWith(
              seats: seats,
              board: board,
              phase: WirePhase.showdown,
              reveals: <Reveal>[for (final seat in seats.where((s) => !s.hasFolded)) reveal(seat.playerId, seat.name)],
              result: const HandResult(
                uncontested: false,
                pots: <PotResult>[
                  PotResult(
                    potIndex: 0,
                    amount: 98765,
                    winnerPlayerIds: <String>['p_1'],
                    shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 98765)],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        _noOverflow(tester, 'showdown');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('player page, my turn, with the raise sheet, holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await _joinAsAlice(
          tester,
          harness,
          view: _betting(),
          prompt: const TurnPrompt(playerId: 'p_1', seatIndex: 1, nextActionSeq: 4, legal: _legal),
        );
        _noOverflow(tester, 'your turn');
        await tester.ensureVisible(find.text('RAISE'));
        await tester.pump();
        await tester.tap(find.text('RAISE'));
        await tester.pumpAndSettle();
        _noOverflow(tester, 'raise sheet');
        expect(find.text('RAISE TO 40'), findsOneWidget, reason: 'the tap reached RAISE and opened the sheet');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('host table, betting with eight seats, holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await _hostAs(tester, harness, _betting());
        _noOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('host table, lobby with the QR code, holds at $where', (tester) async {
        final harness = TestHarness();
        await _pump(tester, size, scale, harness);
        await _hostAs(tester, harness, roomView(seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice')]));
        _noOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
