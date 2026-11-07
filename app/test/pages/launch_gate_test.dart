import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/pages/intro_page.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/pages/splash_page.dart';
import 'package:poker_credits/pages/terms_page.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/terms_content.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

Future<void> _launch(WidgetTester tester, TestHarness harness, {Size size = const Size(390, 844)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
}

void main() {
  setUpAll(loadBrutalFonts);

  group('splash', () {
    testWidgets('shows first, then gives way to the terms on a first run', (tester) async {
      final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 2));
      await _launch(tester, harness);
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.byType(TermsPage), findsNothing);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(SplashView), findsNothing);
      expect(find.byType(TermsPage), findsOneWidget);
    });

    testWidgets('a tap skips the wait', (tester) async {
      final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 30));
      await _launch(tester, harness);
      await tester.tap(find.byType(SplashView));
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
    });

    testWidgets('a returning player waits only half as long and lands on Home', (tester) async {
      final harness = TestHarness(splash: const Duration(seconds: 2));
      await _launch(tester, harness);
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(TermsPage), findsNothing);
    });

    testWidgets('with reduced motion it still finishes and shows every card face up at once', (tester) async {
      final harness = TestHarness(firstRun: true, splash: const Duration(seconds: 2));
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
      await tester.pump();
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
    });
  });

  group('terms', () {
    testWidgets('ACCEPT stays off until the box is ticked, then saves the version and opens Home', (tester) async {
      final harness = TestHarness(firstRun: true);
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
      // The trusted Wi-Fi advice is on the page.
      expect(find.text(termsSections.first.title.toUpperCase()), findsOneWidget);
      expect(termsSections.first.title, contains('Wi-Fi you trust'));

      final acceptButton = find.text(Strings.termsAccept.toUpperCase());
      await tester.ensureVisible(acceptButton);
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget, reason: 'nothing happens until the box is ticked');
      expect(harness.settings.value.termsAccepted, isFalse);

      await tester.ensureVisible(find.byType(BrutalSwitchRow));
      await tester.tap(find.byType(BrutalSwitchRow));
      await tester.pump();
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();
      expect(harness.settings.value.acceptedTerms, currentTermsVersion);
      expect(find.byType(TermsPage), findsNothing);
      expect(find.byType(IntroPage), findsOneWidget, reason: 'a first run is offered the tour next');
    });

    testWidgets('declining leaves the app and saves nothing', (tester) async {
      final harness = TestHarness(firstRun: true);
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      final decline = find.text(Strings.termsDecline.toUpperCase());
      await tester.ensureVisible(decline);
      await tester.tap(decline);
      await tester.pump();
      expect(calls, contains('SystemNavigator.pop'));
      expect(harness.settings.value.termsAccepted, isFalse);
    });

    testWidgets('a notice accepted for an older version is asked for again', (tester) async {
      final harness = TestHarness(firstRun: true);
      harness.settings.value = const AppSettings(acceptedTerms: currentTermsVersion - 1, introDone: true);
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
    });

    testWidgets('read from Settings it has no accept controls and goes back', (tester) async {
      final harness = TestHarness();
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(Strings.termsRow.toUpperCase()), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(Strings.termsRow.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
      expect(find.byType(BrutalSwitchRow), findsNothing);
      expect(find.text(Strings.termsAccept.toUpperCase()), findsNothing);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsNothing);
    });
  });

  group('intro', () {
    Future<void> pastTerms(WidgetTester tester, TestHarness harness) async {
      harness.settings.value = harness.settings.value.copyWith(acceptedTerms: currentTermsVersion);
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      expect(find.byType(IntroPage), findsOneWidget);
    }

    testWidgets('skipping goes straight to Home and is remembered', (tester) async {
      final harness = TestHarness(firstRun: true);
      await pastTerms(tester, harness);
      await tester.tap(find.text(Strings.introSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(WalkthroughPage), findsNothing);
      expect(harness.settings.value.introDone, isTrue);
    });

    testWidgets('the app tour opens over Home, and leaving it lands on Home', (tester) async {
      final harness = TestHarness(firstRun: true);
      await pastTerms(tester, harness);
      await tester.tap(find.text(Strings.introTour.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(WalkthroughPage), findsOneWidget);
      expect(find.text(Strings.tourTitle.toUpperCase()), findsWidgets);
      expect(harness.settings.value.introDone, isTrue, reason: 'asked once, even if the app closes mid-tour');
      await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('the poker lesson opens from the intro', (tester) async {
      final harness = TestHarness(firstRun: true);
      await pastTerms(tester, harness);
      await tester.tap(find.text(Strings.introLearn.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(Strings.learnTitle.toUpperCase()), findsWidgets);
    });

    testWidgets('finishing the lesson from the intro offers the app tour, and the other way round', (tester) async {
      for (final (first, followLabel, secondTitle) in <(String, String, String)>[
        (Strings.introLearn, Strings.followToTour, Strings.tourTitle),
        (Strings.introTour, Strings.followToLesson, Strings.learnTitle),
      ]) {
        final harness = TestHarness(firstRun: true);
        await pastTerms(tester, harness);
        await tester.tap(find.text(first.toUpperCase()));
        await tester.pumpAndSettle();
        for (var i = 0; i < 12 && find.text(followLabel.toUpperCase()).evaluate().isEmpty; i++) {
          await tester.tap(find.text(Strings.walkNext.toUpperCase()));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(followLabel.toUpperCase()));
        await tester.pumpAndSettle();
        expect(find.text(secondTitle.toUpperCase()), findsWidgets, reason: 'the other walkthrough opened');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('once answered, the intro never comes back', (tester) async {
      final harness = TestHarness();
      await _launch(tester, harness);
      await tester.pumpAndSettle();
      expect(find.byType(IntroPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
