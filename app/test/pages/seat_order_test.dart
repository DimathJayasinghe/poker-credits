import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/util/seat_order.dart';
import 'package:poker_credits/widget/table/seat_order_sheet.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

SeatView _seat(int index, String name, {String? id}) => seatView(index, name).copyWith(playerId: id ?? 'p_$index');

Map<int, SeatView> _table() => <int, SeatView>{0: _seat(0, 'Host'), 1: _seat(1, 'Alice'), 2: _seat(2, 'Bob')};

SeatTap _tap({
  bool host = false,
  int target = 5,
  String? selected,
  WirePhase phase = WirePhase.lobby,
  Map<int, SeatView>? seats,
}) => seatTap(isHost: host, myPlayerId: 'p_1', seats: seats ?? _table(), target: target, selected: selected, phase: phase);

void main() {
  group('seat tap rules', () {
    test('a guest moves to a free seat', () {
      final result = _tap(target: 5);
      expect(result, isA<SeatTapSend>());
      expect(((result as SeatTapSend).message as ChooseSeat).seatIndex, 5);
    });

    test('a guest cannot take a seat somebody holds, or their own', () {
      expect(_tap(target: 2), isA<SeatTapIgnored>());
      expect(_tap(target: 1), isA<SeatTapIgnored>());
    });

    test('nobody changes seats during a hand', () {
      for (final phase in <WirePhase>[
        WirePhase.preFlop,
        WirePhase.flop,
        WirePhase.turn,
        WirePhase.river,
        WirePhase.allInRunout,
        WirePhase.showdown,
      ]) {
        expect(seatsLocked(phase), isTrue, reason: '$phase');
        expect(_tap(phase: phase), isA<SeatTapIgnored>());
        expect(_tap(host: true, phase: phase, selected: 'p_2'), isA<SeatTapIgnored>());
      }
      expect(seatsLocked(WirePhase.lobby), isFalse);
      expect(seatsLocked(WirePhase.nextHandPrep), isFalse);
    });

    test('the host picks a player, then a seat', () {
      expect(_tap(host: true, target: 2), isA<SeatTapSelect>().having((t) => t.playerId, 'player', 'p_2'));
      expect(_tap(host: true, target: 5), isA<SeatTapIgnored>(), reason: 'an empty seat with nobody picked does nothing');
      final move = _tap(host: true, target: 5, selected: 'p_2') as SeatTapSend;
      expect((move.message as MoveSeat).playerId, 'p_2');
      expect((move.message as MoveSeat).seatIndex, 5);
    });

    test('the host swaps by tapping an occupied seat, and tapping the picked player again cancels', () {
      final swap = _tap(host: true, target: 0, selected: 'p_2') as SeatTapSend;
      expect((swap.message as MoveSeat).seatIndex, 0);
      expect(_tap(host: true, target: 2, selected: 'p_2'), isA<SeatTapClear>());
    });

    test('names read clockwise from seat 1, whatever order they arrive in', () {
      final shuffled = <SeatView>[_seat(7, 'Gus'), _seat(0, 'Host'), _seat(3, 'Cy')];
      expect(clockwiseNames(shuffled), <String>['Host', 'Cy', 'Gus']);
      expect(clockwiseNames(const <SeatView>[]), isEmpty);
      expect(seatNumber(0), 1);
      expect(seatNumber(9), 10);
    });
  });

  group('seat order sheet', () {
    Future<TestHarness> joined(WidgetTester tester, {WirePhase phase = WirePhase.lobby}) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = TestHarness();
      await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
      await tester.pump();
      await tester.tap(find.text('JOIN A GAME'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'kq7m');
      await tester.enterText(fields.at(1), 'Alice');
      await tester.ensureVisible(find.text('JOIN'));
      await tester.tap(find.text('JOIN'));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      final seats = <SeatView>[_seat(0, 'Host'), _seat(1, 'Alice', id: 'p_1'), _seat(2, 'Bob')];
      harness.network.last
        ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 't'))
        ..serverSends(
          snapshot(
            version: 1,
            serverTime: harness.clock.millisecondsSinceEpoch,
            view: roomView(seats: seats).copyWith(phase: phase),
          ),
        );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return harness;
    }

    testWidgets('a guest opens the sheet, sees the order, and a free seat sends CHOOSE_SEAT', (tester) async {
      final harness = await joined(tester);
      expect(find.byType(PlayerPage), findsOneWidget);
      await tester.tap(find.text('SEAT 2: CHANGE SEAT'));
      await tester.pumpAndSettle();
      expect(find.text('SEAT ORDER'), findsOneWidget);
      expect(find.text('HOST > ALICE > BOB'), findsNothing, reason: 'names keep their case');
      expect(find.text('Host > Alice > Bob'), findsOneWidget);
      expect(find.text('FREE'), findsWidgets);

      // Occupied seats do nothing for a guest.
      await tester.tap(find.bySemanticsLabel('Seat 3, Bob'));
      await tester.pump();
      expect(harness.network.last.sent.whereType<ChooseSeat>(), isEmpty);

      await tester.tap(find.bySemanticsLabel('Seat 6, Free'));
      await tester.pump(const Duration(milliseconds: 200));
      final sent = harness.network.last.sent.whereType<ChooseSeat>().single;
      expect(sent.seatIndex, 5);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the sheet follows the order the server sends next', (tester) async {
      final harness = await joined(tester);
      await tester.tap(find.text('SEAT 2: CHANGE SEAT'));
      await tester.pumpAndSettle();
      final moved = <SeatView>[_seat(0, 'Host'), _seat(2, 'Bob'), _seat(5, 'Alice', id: 'p_1')];
      harness.network.last.serverSends(
        snapshot(
          version: 2,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(seats: moved).copyWith(phase: WirePhase.lobby),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Host > Bob > Alice'), findsOneWidget);
      expect(find.bySemanticsLabel('Seat 6, Alice (You)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the host picks a player and a seat and sends MOVE_SEAT; a pick that disappears is dropped', (tester) async {
      final harness = await joined(tester);
      final context = tester.element(find.byType(PlayerPage));
      unawaited(showSeatOrderSheet(context, isHost: true));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Seat 3, Bob'));
      await tester.pump();
      expect(find.text('Now tap the seat they should take.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Seat 8, Free'));
      await tester.pump(const Duration(milliseconds: 200));
      final move = harness.network.last.sent.whereType<MoveSeat>().single;
      expect((move.playerId, move.seatIndex), ('p_2', 7));

      // Pick Bob, then Bob leaves before the second tap.
      await tester.tap(find.bySemanticsLabel('Seat 3, Bob'));
      await tester.pump();
      final gone = <SeatView>[_seat(0, 'Host'), _seat(1, 'Alice', id: 'p_1')];
      harness.network.last.serverSends(
        snapshot(
          version: 3,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(seats: gone).copyWith(phase: WirePhase.lobby),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Now tap the seat they should take.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('during a hand the change-seat button is gone and the sheet says why', (tester) async {
      final harness = await joined(tester, phase: WirePhase.preFlop);
      expect(find.text('SEAT 2: CHANGE SEAT'), findsNothing);
      final context = tester.element(find.byType(PlayerPage));
      unawaited(showSeatOrderSheet(context, isHost: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seats are locked'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Seat 6, Free'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(harness.network.last.sent.whereType<ChooseSeat>(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
