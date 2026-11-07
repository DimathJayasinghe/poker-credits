import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/pages/name_page.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/devices.dart';
import '../support/fakes.dart';
import '../support/no_scroll.dart';

/// The first run asks once for a default name: after the terms and the intro (and any tour or
/// lesson), before Home. It is filled in on every form from then on, and skipping is one tap.
void main() {
  setUpAll(loadFonts);

  const phone = Device('Pixel-sized phone', 412, 915, top: 24, bottom: 24);

  Future<void> startFresh(WidgetTester tester, TestHarness harness) async {
    await launchOn(tester, harness, phone);
    await tester.tap(find.byType(Scaffold).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(Strings.termsAgree));
    await tester.tap(find.text(Strings.termsAgree));
    await tester.pump();
    await tester.tap(find.text(Strings.termsAccept.toUpperCase()));
    await tester.pumpAndSettle();
  }

  testWidgets('after the intro the name is asked before Home, and the name is kept and prefilled', (tester) async {
    final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 30));
    await startFresh(tester, harness);
    expect(find.text(Strings.introSkip.toUpperCase()), findsOneWidget, reason: 'the intro comes first');
    expect(find.byType(NamePage), findsNothing);

    await tester.tap(find.text(Strings.introSkip.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(NamePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing, reason: 'not yet on Home');
    expect(find.text(Strings.nameStepHeadline.toUpperCase()), findsWidgets);

    await tester.enterText(find.byType(TextField), '  Dimath ');
    await tester.tap(find.text(Strings.nameStepSave.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(harness.settings.value.defaultName, 'Dimath');
    expect(harness.settings.value.nameAsked, isTrue);

    await tester.tap(find.text('HOST A GAME'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Dimath'), findsOneWidget, reason: 'the host form already has the name');
  });

  testWidgets('a name the server would refuse is not kept: the page says why and stays', (tester) async {
    final harness = TestHarness(askName: true);
    await launchOn(tester, harness, phone);
    expect(find.byType(NamePage), findsOneWidget);

    await tester.tap(find.text(Strings.nameStepSave.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsOneWidget, reason: 'empty');
    await tester.enterText(find.byType(TextField), 'Dimath!');
    await tester.tap(find.text(Strings.nameStepSave.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(NamePage), findsOneWidget);
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsOneWidget);
    expect(harness.settings.value.defaultName, '');
    expect(harness.settings.value.nameAsked, isFalse);

    await tester.enterText(find.byType(TextField), 'Dimath_2');
    await tester.pump();
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsNothing, reason: 'the error goes away as soon as the name is fine');
  });

  testWidgets('skipping goes to Home and the question is not asked again', (tester) async {
    final harness = TestHarness(askName: true);
    await launchOn(tester, harness, phone);
    await tester.tap(find.text(Strings.nameStepSkip.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(harness.settings.value.defaultName, '');
    expect(harness.settings.value.nameAsked, isTrue);

    // The next start: same settings, no question.
    await tester.pumpWidget(const SizedBox());
    await launchOn(tester, harness, phone);
    expect(find.byType(NamePage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the keyboard submit key saves the name too', (tester) async {
    final harness = TestHarness(askName: true);
    await launchOn(tester, harness, phone);
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(harness.settings.value.defaultName, 'Ana');
  });
}
