import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/guide_page.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/guide/guide_sheet.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

void _size(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openGuideTab(WidgetTester tester, {Size size = const Size(390, 844), double scale = 1}) async {
  _size(tester, size);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: TestHarness().scope(const PokerCreditsApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('GUIDE').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  group('content', () {
    test('there are exactly ten hands, ranked 1 to 10 in order, each with a plain example', () {
      expect(guideHands.map((h) => h.rank), <int>[for (var i = 1; i <= 10; i++) i]);
      expect(guideHands.map((h) => h.name).toSet(), hasLength(10));
      for (final hand in guideHands) {
        expect(hand.line.trim(), isNotEmpty);
        expect(hand.example.trim(), isNotEmpty);
      }
      expect(guideHands.first.name, 'Royal flush');
      expect(guideHands.last.name, 'High card');
    });

    test('the order of the stronger hands is the standard one', () {
      final order = guideHands.map((h) => h.name).toList();
      expect(order.indexOf('Straight flush'), lessThan(order.indexOf('Four of a kind')));
      expect(order.indexOf('Four of a kind'), lessThan(order.indexOf('Full house')));
      expect(order.indexOf('Full house'), lessThan(order.indexOf('Flush')));
      expect(order.indexOf('Flush'), lessThan(order.indexOf('Straight')));
      expect(order.indexOf('Straight'), lessThan(order.indexOf('Three of a kind')));
      expect(order.indexOf('Three of a kind'), lessThan(order.indexOf('Two pair')));
      expect(order.indexOf('Two pair'), lessThan(order.indexOf('One pair')));
    });

    test('no list is empty and no text is blank', () {
      for (final steps in <List<GuideStep>>[guideNight, guideHandFlow, guideDrops]) {
        expect(steps, isNotEmpty);
        for (final s in steps) {
          expect(s.title.trim(), isNotEmpty);
          expect(s.body.trim(), isNotEmpty);
        }
      }
      for (final t in guideTerms) {
        expect(t.term.trim(), isNotEmpty);
        expect(t.meaning.trim(), isNotEmpty);
      }
      expect(guideRules.every((r) => r.trim().isNotEmpty), isTrue);
      expect(guideManners.every((r) => r.trim().isNotEmpty), isTrue);
    });

    test('the street names match the streets the engine plays, in order', () {
      expect(guideHandFlow.map((s) => s.title), <String>['Blinds', 'Pre-flop', 'Flop', 'Turn', 'River', 'Showdown']);
    });
  });

  group('the Guide tab', () {
    testWidgets('sits between Play and Settings and shows the ranking with rank 1 first', (tester) async {
      await _openGuideTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GuideView), findsOneWidget);
      final nav = <String>['PLAY', 'GUIDE', 'SETTINGS'].map((l) => tester.getTopLeft(find.text(l).last).dx).toList();
      expect(nav[0], lessThan(nav[1]));
      expect(nav[1], lessThan(nav[2]));
      await tester.scrollUntilVisible(find.text('ROYAL FLUSH'), 400, scrollable: find.byType(Scrollable).first);
      final royal = tester.getTopLeft(find.text('ROYAL FLUSH')).dy;
      await tester.scrollUntilVisible(find.text('STRAIGHT FLUSH'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('ROYAL FLUSH'), findsOneWidget);
      expect(royal, isNotNull);
    });

    testWidgets('every hand, every section heading and the beginner entry points are there', (tester) async {
      await _openGuideTab(tester, size: const Size(1280, 4000));
      for (final hand in guideHands) {
        expect(find.text(hand.name.toUpperCase()), findsOneWidget, reason: hand.name);
      }
      for (final heading in <String>[
        'HOW A NIGHT WORKS',
        'HAND RANKINGS',
        'HOW A HAND PLAYS',
        'WORDS ON THE BUTTONS',
        'RULES THE APP KEEPS',
        'IF THE CONNECTION DROPS',
        'TABLE MANNERS',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text('NEW TO POKER? START HERE.'), findsOneWidget);
    });

    testWidgets('a jump cell scrolls to its section', (tester) async {
      await _openGuideTab(tester);
      expect(find.text('IF THE CONNECTION DROPS').hitTestable(), findsNothing, reason: 'far below the fold at first');
      await tester.tap(find.text('DROPS'));
      await tester.pumpAndSettle();
      expect(find.text('IF THE CONNECTION DROPS').hitTestable(), findsOneWidget);
    });

    testWidgets('works with no network and no game: it is static text', (tester) async {
      await _openGuideTab(tester);
      expect(find.text('NEW TO POKER? START HERE.'), findsOneWidget);
    });

    for (final scale in <double>[1.0, 2.0, 3.0]) {
      for (final size in <Size>[const Size(320, 640), const Size(390, 844), const Size(1280, 800)]) {
        testWidgets('holds at text scale $scale on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _openGuideTab(tester, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          // Walk the whole page: any section that overflows throws while it is built.
          for (var i = 0; i < 40; i++) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: 'while scrolling, step $i');
          }
        });
      }
    }
  });

  group('quick access from a game screen', () {
    Future<TestHarness> joined(WidgetTester tester) async {
      _size(tester, const Size(390, 844));
      final harness = TestHarness();
      await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
      await tester.pump();
      await tester.tap(find.text('JOIN A GAME'));
      await tester.pumpAndSettle();
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
        ..serverSends(
          snapshot(
            version: 1,
            serverTime: harness.clock.millisecondsSinceEpoch,
            nextActionSeq: 4,
            view: roomView(
              hand: 3,
              activeSeat: 2,
              pot: 60,
              seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice', chips: 940), seatView(2, 'Bob', chips: 1200)],
            ),
          ),
        );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return harness;
    }

    testWidgets('the player screen has a ? that opens the ranked hands first', (tester) async {
      await joined(tester);
      expect(find.byType(GuideCell), findsOneWidget);
      await tester.tap(find.byType(GuideCell));
      await tester.pumpAndSettle();
      expect(find.text('QUICK GUIDE'), findsOneWidget);
      expect(find.text('ROYAL FLUSH'), findsOneWidget, reason: 'the ranking is the first tab');
      expect(find.text('STRAIGHT FLUSH'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The game screen is still there underneath: nothing was left or sent.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('QUICK GUIDE'), findsNothing);
      expect(find.text('YOUR CHIPS · ALICE'), findsOneWidget);
    });

    testWidgets('the tabs switch between hands, a hand, words and rules', (tester) async {
      await joined(tester);
      await tester.tap(find.byType(GuideCell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A HAND'));
      await tester.pumpAndSettle();
      expect(find.text('PRE-FLOP'), findsOneWidget);
      await tester.tap(find.text('WORDS'));
      await tester.pumpAndSettle();
      expect(find.text('SIDE POT'), findsOneWidget);
      await tester.tap(find.text('RULES'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You may check only when nobody has bet'), findsOneWidget);
    });

    testWidgets('the full guide opens from the sheet, with a back arrow that returns to the game', (tester) async {
      await joined(tester);
      await tester.tap(find.byType(GuideCell));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OPEN THE FULL GUIDE'));
      await tester.tap(find.text('OPEN THE FULL GUIDE'));
      await tester.pumpAndSettle();
      expect(find.byType(GuidePage), findsOneWidget);
      await tester.tap(find.byType(BackCell));
      await tester.pumpAndSettle();
      expect(find.byType(GuidePage), findsNothing);
      expect(find.text('YOUR CHIPS · ALICE'), findsOneWidget, reason: 'back to the game, still seated');
    });
  });

  group('tours', () {
    testWidgets('the Guide tab offers the app tour and the poker lesson, and both open', (tester) async {
      await _openGuideTab(tester);
      for (final (row, title) in <(String, String)>[
        (Strings.guideLearnRow, Strings.learnTitle),
        (Strings.guideTourRow, Strings.tourTitle),
      ]) {
        await tester.ensureVisible(find.text(row.toUpperCase()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(row.toUpperCase()));
        await tester.pumpAndSettle();
        expect(find.byType(WalkthroughPage), findsOneWidget, reason: row);
        expect(find.text(title.toUpperCase()), findsWidgets);
        await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
        await tester.pumpAndSettle();
        expect(find.byType(WalkthroughPage), findsNothing);
      }
    });
  });
}
