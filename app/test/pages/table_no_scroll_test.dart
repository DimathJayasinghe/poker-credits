import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/player/action_buttons.dart';
import 'package:poker_credits/widget/table/action_ticker.dart';
import 'package:poker_credits/widget/table/host_controls.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/qr_panel.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/devices.dart';
import '../support/fakes.dart';
import '../support/no_scroll.dart';

/// The host's table never scrolls: the pot, every seat and every control are on screen at once,
/// on every phone upright and on its side, at the normal text size and a big one.

List<SeatView> _table(int count, {bool cards = false, bool hostSeated = false}) => <SeatView>[
  for (var i = 0; i < count; i++)
    seatView(
      i,
      const <String>['Dimath', 'Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Fay', 'Gus', 'Hal', 'Ivy'][i],
      chips: i == 3 ? 0 : 940 + i * 37,
      bet: i == 1 ? 20 : 0,
      allIn: i == 3,
      folded: i == 4,
      away: i == 5,
      connected: i != 7,
      hasCards: cards && i != 4,
    ).copyWith(playerId: i == 0 && hostSeated ? 'p_host' : 'p_$i'),
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

class _Scene {
  const _Scene(this.name, this.build, {this.hostTurn = false, this.cards = false, this.seatsMayScroll = false});

  final String name;
  final RoomView Function() build;

  /// The same scene with [count] players at the table.
  _Scene copyWithSeats(int count) => _Scene(
    name,
    () => build().copyWith(seats: _table(count)),
    hostTurn: hostTurn,
    cards: cards,
    seatsMayScroll: seatsMayScroll,
  );
  final bool hostTurn;
  final bool cards;

  /// The one combination that may not fit on the smallest phones: a seated host with cards in the
  /// app, on their turn, at a full table. The pot, the cards and every button still stay put; only
  /// the list of seats scrolls inside its own box.
  final bool seatsMayScroll;
}

final List<_Scene> _scenes = <_Scene>[
  _Scene('lobby 6 players', () => roomView(hand: 0, seats: _table(6), phase: WirePhase.lobby)),
  _Scene('betting 10 seats, real cards', () => roomView(hand: 3, activeSeat: 2, pot: 210, seats: _table(10), deadline: 1730000021000)),
  _Scene(
    'betting 10 seats, cards in the app',
    () => roomView(
      hand: 3,
      activeSeat: 2,
      pot: 210,
      seats: _table(10, cards: true),
      deadline: 1730000021000,
      phase: WirePhase.flop,
      board: <PokerCard>[card('Kd'), card('9c'), card('6c')],
    ),
    cards: true,
  ),
  _Scene(
    'host seated, on turn, 10 seats, real cards',
    () => roomView(hand: 3, activeSeat: 0, pot: 210, seats: _table(10, hostSeated: true), deadline: 1730000021000),
    hostTurn: true,
  ),
  _Scene(
    'host seated, on turn, 6 seats, cards in the app',
    () => roomView(
      hand: 3,
      activeSeat: 0,
      pot: 210,
      seats: _table(6, cards: true, hostSeated: true),
      deadline: 1730000021000,
      phase: WirePhase.flop,
      board: <PokerCard>[card('Kd'), card('9c'), card('6c')],
    ),
    hostTurn: true,
    cards: true,
  ),
  _Scene(
    'host seated, on turn, 10 seats, cards in the app',
    () => roomView(
      hand: 3,
      activeSeat: 0,
      pot: 210,
      seats: _table(10, cards: true, hostSeated: true),
      deadline: 1730000021000,
      phase: WirePhase.flop,
      board: <PokerCard>[card('Kd'), card('9c'), card('6c')],
    ),
    hostTurn: true,
    cards: true,
    seatsMayScroll: true,
  ),
  _Scene('between hands 8 seats', () => roomView(hand: 3, pot: 0, seats: _table(8), phase: WirePhase.nextHandPrep)),
  _Scene(
    'showdown, two pots, cards in the app',
    () => roomView(
      hand: 3,
      pot: 0,
      seats: _table(8, cards: true),
      phase: WirePhase.nextHandPrep,
      board: <PokerCard>[card('Kd'), card('9c'), card('6c'), card('2h'), card('As')],
      result: const HandResult(
        uncontested: false,
        pots: <PotResult>[
          PotResult(
            potIndex: 0,
            amount: 120,
            winnerPlayerIds: <String>['p_1'],
            shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 120)],
          ),
          PotResult(
            potIndex: 1,
            amount: 60,
            winnerPlayerIds: <String>['p_2'],
            shares: <Share>[Share(playerId: 'p_2', name: 'Bob', amount: 60)],
          ),
        ],
      ),
    ),
    cards: true,
  ),
];

final _Scene _showdown = _Scene(
  'showdown to resolve, two pots, four players',
  () => roomView(hand: 3, pot: 210, seats: _table(8), phase: WirePhase.showdown).copyWith(
    pots: const <PotView>[
      PotView(tierIndex: 0, amount: 150, eligiblePlayerIds: <String>['p_0', 'p_1', 'p_2', 'p_3']),
      PotView(tierIndex: 1, amount: 60, eligiblePlayerIds: <String>['p_0', 'p_1']),
    ],
  ),
);

Future<void> openScene(WidgetTester tester, TestHarness harness, Device d, double scale, int scene) =>
    _open(tester, harness, d, scale, _scenes[scene]);

Future<void> _open(WidgetTester tester, TestHarness harness, Device d, double scale, _Scene scene) async {
  await launchOn(tester, harness, d, scale: scale);
  await tester.ensureVisible(find.text('HOST A GAME'));
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Dimath');
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final view = scene.build();
  harness.network.last.serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: view));
  if (scene.cards) harness.network.last.serverSends(holeCards('As', 'Kh', hand: view.handNumber));
  if (scene.hostTurn) harness.network.last.serverSends(const TurnPrompt(playerId: 'p_host', seatIndex: 0, nextActionSeq: 7, legal: _legal));
  await tester.pump();
  await tester.pump();
}

double _tableExtent(WidgetTester tester, {required bool seats}) {
  var most = 0.0;
  for (final finder in <Finder>[
    if (seats) find.byType(SeatPlate),
    find.byType(ActionTicker),
    find.byType(HostControls),
    find.byType(PotDisplay),
    find.byType(QrPanel),
    find.byType(ActionButtons),
    find.byType(HoleCardsDock),
  ]) {
    if (finder.evaluate().isEmpty) continue;
    final extent = extentAround(tester, finder);
    if (extent > most) most = extent;
  }
  return most;
}

void main() {
  setUpAll(loadFonts);

  // The sheets and dialogs the table opens hold their content without scrolling.
  Future<double> sheetExtent(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) throw TestFailure('EXCEPTION ${error.toString().split('\n').first}');
    var most = 0.0;
    for (final e in tester.elementList(find.descendant(of: find.byType(BrutalSheet), matching: find.byType(Scrollable)))) {
      final position = ((e as StatefulElement).state as ScrollableState).position;
      if (position.axis == Axis.vertical && position.maxScrollExtent > most) most = position.maxScrollExtent;
    }
    return most;
  }

  Future<void> closeTop(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
  }

  for (final scale in <double>[1.0, 1.3]) {
    for (final d in <Device>[...phones, ...phonesOnTheirSide, ...bigScreens]) {
      testWidgets('table sheets: ${d.name} ${d.width.toInt()}x${d.height.toInt()}, text x$scale', (tester) async {
        final lines = <String>[];
        Future<void> measure(String what, Future<void> Function() open) async {
          try {
            await open();
            final extent = await sheetExtent(tester);
            if (extent > 0.5) lines.add('$what scrolls by ${extent.toStringAsFixed(0)} px');
          } on TestFailure catch (e) {
            lines.add('$what: ${e.message}');
          }
          await closeTop(tester);
        }

        // Seat order: a full lobby.
        var harness = TestHarness();
        await _open(tester, harness, d, scale, _scenes.first.copyWithSeats(10));
        await measure('seat order', () async {
          await tester.tap(find.text(Strings.seatsButton.toUpperCase()));
        });
        await measure('end game dialog', () async {
          await tester.tap(find.text(Strings.endGame.toUpperCase()));
        });
        await tester.pumpWidget(const SizedBox());

        // The raise sheet, from the seated host's own turn.
        harness = TestHarness();
        await _open(tester, harness, d, scale, _scenes[3]);
        await measure('raise sheet', () async {
          await tester.tap(find.text(Strings.raise.toUpperCase()));
        });
        await tester.pumpWidget(const SizedBox());

        // Choosing winners of two pots at a showdown.
        harness = TestHarness();
        await _open(tester, harness, d, scale, _showdown);
        await measure('winners sheet', () async {
          await tester.tap(find.text(Strings.resolveShowdown.toUpperCase()));
        });
        await tester.pumpWidget(const SizedBox());
        if (lines.isNotEmpty) fail('${d.name} (usable ${d.usable.toInt()}), text x$scale:\n  ${lines.join('\n  ')}');
      });
    }
  }

  for (final scale in <double>[1.0, 1.3]) {
    for (final d in <Device>[...phones, ...phonesOnTheirSide, ...bigScreens]) {
      testWidgets('table: ${d.name} ${d.width.toInt()}x${d.height.toInt()}, text x$scale', (tester) async {
        final lines = <String>[];
        for (final scene in _scenes) {
          final harness = TestHarness();
          await _open(tester, harness, d, scale, scene);
          final error = tester.takeException();
          if (error != null) lines.add('${scene.name}: EXCEPTION ${error.toString().split('\n').first}');
          final extent = _tableExtent(tester, seats: !scene.seatsMayScroll);
          if (extent > 0.5) lines.add('${scene.name} scrolls by ${extent.toStringAsFixed(0)} px');
          // Everything the host presses is inside the screen, below the system bars.
          for (final control in <Finder>[
            find.byType(HostControls),
            find.byType(ActionButtons),
            find.byType(HoleCardsDock),
            find.byType(PotDisplay),
            find.byType(QrPanel),
          ]) {
            if (control.evaluate().isEmpty) continue;
            final rect = tester.getRect(control.first);
            if (rect.top < d.top - 0.5 || rect.bottom > d.height - d.bottom + 0.5 || rect.right > d.width + 0.5) {
              lines.add('${scene.name}: ${control.first.evaluate().first.widget.runtimeType} is off screen: $rect');
            }
          }
          if (scene.seatsMayScroll) {
            final seatScroll = extentAround(tester, find.byType(SeatPlate));
            if (seatScroll > 80) lines.add('${scene.name}: the seats scroll by ${seatScroll.toStringAsFixed(0)} px, more than the allowed 80');
          }
          await tester.pumpWidget(const SizedBox());
        }
        if (lines.isNotEmpty) fail('${d.name} (usable ${d.usable.toInt()}), text x$scale:\n  ${lines.join('\n  ')}');
      });
    }
  }
}
