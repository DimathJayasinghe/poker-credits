import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';

import '../support/devices.dart';
import '../support/fakes.dart';
import '../support/no_scroll.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// More of the screens around a game that must not scroll (see no_scroll_test.dart): the poker
/// lesson, and the home page with a game to resume. And the screens with a text field when the
/// on-screen keyboard is open: they may scroll then, but nothing breaks and the main button stays
/// reachable.

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  for (final scale in <double>[1.0, 1.3]) {
    for (final d in allDevices) {
      testWidgets('lesson and resume rows: ${d.name} ${d.width.toInt()}x${d.height.toInt()}, text x$scale', (tester) async {
        final misfits = Misfits();

        // Home with a game this device was hosting, and one it was playing in.
        final hosting = MemoryTokenStore();
        await hosting.write(const StoredSession(serverUri: 'ws://127.0.0.1:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 's', hostToken: 'h'));
        await launchOn(tester, TestHarness(tokens: hosting), d, scale: scale);
        await tester.pump();
        expect(find.textContaining('RESUME HOSTED GAME KQ7M'), findsOneWidget);
        misfits.check(tester, 'home with a hosted game to resume', find.textContaining('RESUME HOSTED GAME KQ7M'), d, scale);
        await tester.pumpWidget(const SizedBox());

        final playing = MemoryTokenStore();
        await playing.write(const StoredSession(serverUri: 'wss://10.0.0.2:7878/v1/ws#pin=$testPin', roomCode: 'KQ7M', sessionToken: 's'));
        await launchOn(tester, TestHarness(tokens: playing), d, scale: scale);
        await tester.pump();
        misfits.check(tester, 'home with a game to rejoin', find.text('HOST A GAME'), d, scale);
        await tester.pumpWidget(const SizedBox());

        // The poker lesson, step by step.
        await launchOn(tester, TestHarness(), d, scale: scale);
        unawaited(
          Navigator.of(tester.element(find.byType(Scaffold).last)).push<WalkthroughEnd>(
            MaterialPageRoute<WalkthroughEnd>(
              builder: (_) => WalkthroughPage(title: Strings.learnTitle, steps: pokerLessonSteps),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 1; i <= pokerLessonSteps.length; i++) {
          misfits.check(tester, 'lesson step $i', find.text(Strings.walkStep(i, pokerLessonSteps.length).toUpperCase()), d, scale);
          if (i < pokerLessonSteps.length) {
            await tester.tap(find.text(Strings.walkNext.toUpperCase()));
            await tester.pumpAndSettle();
          }
        }
        await tester.pumpWidget(const SizedBox());
        misfits.done(d, scale);
      });
    }
  }

  // Somebody who joined to watch sees the whole table, no controls, no scrolling.
  for (final scale in <double>[1.0, 1.3]) {
    for (final d in allDevices) {
      testWidgets('spectator: ${d.name} ${d.width.toInt()}x${d.height.toInt()}, text x$scale', (tester) async {
        final harness = TestHarness();
        await launchOn(tester, harness, d, scale: scale);
        await tester.ensureVisible(find.text('JOIN A GAME'));
        await tester.tap(find.text('JOIN A GAME'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), 'kq7m');
        await tester.enterText(find.byType(TextField).at(1), 'Wanda');
        await tester.ensureVisible(find.text('WATCH ONLY'));
        await tester.tap(find.text('WATCH ONLY'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final seats = <SeatView>[
          for (var i = 0; i < 10; i++)
            seatView(
              i,
              const <String>['Dimath', 'Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Fay', 'Gus', 'Hal', 'Ivy'][i],
              chips: 940 + i * 37,
              bet: i == 1 ? 20 : 0,
              folded: i == 4,
            ),
        ];
        harness.network.last
          ..serverSends(const Joined(playerId: 'p_w', role: Role.spectator, sessionToken: 'watch-token'))
          ..serverSends(
            snapshot(
              version: 1,
              serverTime: harness.clock.millisecondsSinceEpoch,
              view: roomView(
                hand: 3,
                activeSeat: 2,
                pot: 210,
                seats: seats,
                deadline: 1730000021000,
                phase: WirePhase.flop,
                board: <PokerCard>[card('Kd'), card('9c'), card('6c')],
              ),
            ),
          );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(TablePage), findsOneWidget);
        final misfits = Misfits()..check(tester, 'spectator table', find.byType(SeatPlate), d, scale);
        final error = tester.takeException();
        expect(error, isNull);
        expect(extentAround(tester, find.byType(PotDisplay)), lessThanOrEqualTo(0.5));
        misfits.done(d, scale);
      });
    }
  }

  // The keyboard takes about a third of the screen: the pages may scroll then, but they must not
  // break, and the button that goes on must still be on screen once the field is in view.
  const keyboardDevices = <Device>[
    Device('Android budget', 360, 640, top: 24, bottom: 48),
    Device('iPhone 14', 390, 844, top: 47, bottom: 34),
    Device('iPhone SE landscape', 667, 375),
  ];
  for (final d in keyboardDevices) {
    testWidgets('keyboard open: ${d.name}', (tester) async {
      final keyboard = d.width > d.height ? 180.0 : 300.0;
      await launchOn(tester, TestHarness(), d, keyboard: keyboard);

      for (final entry in <(String, String, Finder?)>[
        ('PLAY ALONE', 'play alone', null),
        ('JOIN A GAME', 'join', null),
        ('HOST A GAME', 'host', null),
      ]) {
        await tester.ensureVisible(find.text(entry.$1));
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${entry.$2} with the keyboard open');
        final field = find.byType(TextField).first;
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${entry.$2}: focusing the field');
        final area = Rect.fromLTWH(0, d.top, d.width, d.height - d.bottom - keyboard);
        final rect = tester.getRect(field);
        expect(rect.top, greaterThanOrEqualTo(area.top - 0.5), reason: '${entry.$2}: the field is not hidden behind the keyboard');
        expect(rect.bottom, lessThanOrEqualTo(area.bottom + 0.5), reason: '${entry.$2}: the field is not hidden behind the keyboard');
        await _back(tester);
      }
    });
  }
}
