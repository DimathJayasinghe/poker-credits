import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/fakes.dart';

const _sizes = <String, Size>{'phone': Size(390, 844), 'tablet': Size(1280, 800)};

Future<void> _launch(WidgetTester tester, TestHarness harness, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  for (final entry in _sizes.entries) {
    for (final dark in <bool>[false, true]) {
      final name = '${entry.key}_${dark ? 'dark' : 'light'}';

      testWidgets('splash, $name', (tester) async {
        final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 2));
        harness.settings.value = harness.settings.value.copyWith(theme: dark ? ThemeChoice.dark : ThemeChoice.light);
        await _launch(tester, harness, entry.value);
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/splash_$name.png'));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      });

      testWidgets('terms, $name', (tester) async {
        final harness = TestHarness(firstRun: true);
        harness.settings.value = harness.settings.value.copyWith(theme: dark ? ThemeChoice.dark : ThemeChoice.light);
        await _launch(tester, harness, entry.value);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/terms_$name.png'));
      });

      testWidgets('support, $name', (tester) async {
        final harness = TestHarness();
        harness.settings.value = harness.settings.value.copyWith(theme: dark ? ThemeChoice.dark : ThemeChoice.light);
        await _launch(tester, harness, entry.value);
        await tester.pumpAndSettle();
        await tester.tap(find.text(Strings.navSettings.toUpperCase()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(Strings.supportRow.toUpperCase()), 200, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text(Strings.supportRow.toUpperCase()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/support_$name.png'));
      });
    }
  }
}
