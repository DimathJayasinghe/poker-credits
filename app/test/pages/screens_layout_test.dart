import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/fakes.dart';

/// Layout sweep for every screen outside a game: Home, Settings, Guide, Support, the terms, the
/// intro and the splash. At every size and every text size the operating systems allow, nothing may
/// overflow and the screen's main action must be on the screen or one scroll away.

const List<double> _scales = <double>[1.0, 2.0, 3.0];
const Map<String, Size> _sizes = <String, Size>{
  'small phone': Size(320, 568),
  'phone': Size(390, 844),
  'phone landscape': Size(844, 390),
  'tablet': Size(1280, 800),
  'tv': Size(1920, 1080),
};

Future<void> _launch(WidgetTester tester, TestHarness harness, Size size, double scale, {bool dark = false}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: harness.scope(const PokerCreditsApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void _clean(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error != null) fail('$where: $error');
}

/// Whether the centre of [finder] is on the screen once any scrolling is done.
Future<void> _reachable(WidgetTester tester, Finder finder, Size size, String what) async {
  expect(finder, findsWidgets, reason: what);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  final centre = tester.getCenter(finder.first);
  expect((Offset.zero & size).contains(centre), isTrue, reason: '$what is off the screen at $centre');
}

void main() {
  setUpAll(loadFonts);

  for (final dark in <bool>[false, true]) {
    for (final scale in _scales) {
      for (final entry in _sizes.entries) {
        final where = '${entry.key}, text x$scale${dark ? ', dark' : ''}';
        final size = entry.value;

        testWidgets('home holds ($where)', (tester) async {
          await _launch(tester, TestHarness(), size, scale, dark: dark);
          _clean(tester, 'home');
          await _reachable(tester, find.text('HOST A GAME'), size, 'HOST A GAME');
          await _reachable(tester, find.text('JOIN A GAME'), size, 'JOIN A GAME');
        });

        testWidgets('settings holds ($where)', (tester) async {
          await _launch(tester, TestHarness(), size, scale, dark: dark);
          await tester.tap(find.text('SETTINGS'));
          await tester.pumpAndSettle();
          _clean(tester, 'settings');
          await _reachable(tester, find.text(Strings.termsRow.toUpperCase()), size, 'terms row');
          await _reachable(tester, find.text(Strings.supportRow.toUpperCase()), size, 'support row');
        });

        testWidgets('guide holds ($where)', (tester) async {
          await _launch(tester, TestHarness(), size, scale, dark: dark);
          await tester.tap(find.text('GUIDE').first);
          await tester.pumpAndSettle();
          _clean(tester, 'guide');
          await _reachable(tester, find.text(Strings.guideLearnRow.toUpperCase()), size, 'learn row');
          await _reachable(tester, find.text(Strings.guideSupportRow.toUpperCase()), size, 'support row');
          _clean(tester, 'guide after scrolling');
        });

        testWidgets('support holds ($where)', (tester) async {
          await _launch(tester, TestHarness(), size, scale, dark: dark);
          await tester.tap(find.text('SETTINGS'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(Strings.supportRow.toUpperCase()));
          await tester.tap(find.text(Strings.supportRow.toUpperCase()));
          await tester.pumpAndSettle();
          _clean(tester, 'support');
          await _reachable(tester, find.text(Strings.supportStar.toUpperCase()), size, 'star row');
          await _reachable(tester, find.text(Strings.supportFollow.toUpperCase()), size, 'follow row');
          await _reachable(tester, find.text(Strings.supportIssues.toUpperCase()), size, 'issues row');
          await _reachable(tester, find.text(Strings.supportThanks.toUpperCase()), size, 'thanks line');
        });

        testWidgets('first run: splash, terms and intro hold ($where)', (tester) async {
          final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 30));
          await _launch(tester, harness, size, scale, dark: dark);
          _clean(tester, 'splash');
          await tester.tap(find.byType(Scaffold).first);
          await tester.pumpAndSettle();
          _clean(tester, 'terms');
          await _reachable(tester, find.text(Strings.termsAccept.toUpperCase()), size, 'ACCEPT');
          await _reachable(tester, find.text(Strings.termsAgree), size, 'agree switch');
          await tester.tap(find.text(Strings.termsAgree));
          await tester.pump();
          await tester.tap(find.text(Strings.termsAccept.toUpperCase()));
          await tester.pumpAndSettle();
          _clean(tester, 'intro');
          await _reachable(tester, find.text(Strings.introTour.toUpperCase()), size, 'tour choice');
          await _reachable(tester, find.text(Strings.introLearn.toUpperCase()), size, 'learn choice');
          await _reachable(tester, find.text(Strings.introSkip.toUpperCase()), size, 'skip');
        });
      }
    }
  }
}
