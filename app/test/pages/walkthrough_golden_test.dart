import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/pages/intro_page.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/tour_content.dart';

import '../support/test_app.dart';

Future<void> _show(WidgetTester tester, Widget page, Size size, {bool dark = false}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(brutalHost(page, dark: dark));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'no layout overflow');
}

Future<void> _next(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text(Strings.walkNext.toUpperCase()));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadBrutalFonts);

  testWidgets('intro, phone light', (tester) async {
    await _show(tester, IntroPage(onChoose: (_) {}), const Size(390, 844));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/intro_phone_light.png'));
  });

  testWidgets('intro, tablet dark', (tester) async {
    await _show(tester, IntroPage(onChoose: (_) {}), const Size(1280, 800), dark: true);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/intro_tablet_dark.png'));
  });

  testWidgets('app tour, "play on your phone", phone light', (tester) async {
    await _show(tester, WalkthroughPage(title: Strings.tourTitle, steps: appTourSteps), const Size(390, 844));
    await _next(tester, 4);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tour_turn_phone_light.png'));
  });

  testWidgets('learn poker, hands, phone dark', (tester) async {
    await _show(tester, WalkthroughPage(title: Strings.learnTitle, steps: pokerLessonSteps), const Size(390, 844), dark: true);
    await _next(tester, 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/learn_hands_phone_dark.png'));
  });

  testWidgets('learn poker, worked example, tablet light', (tester) async {
    await _show(tester, WalkthroughPage(title: Strings.learnTitle, steps: pokerLessonSteps), const Size(1280, 800));
    await _next(tester, pokerLessonSteps.indexWhere((s) => s.art == StepArt.workedExample));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/learn_example_tablet_light.png'));
  });
}
