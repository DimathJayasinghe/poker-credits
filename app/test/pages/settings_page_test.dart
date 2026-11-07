import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/pages/support_page.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/haptics.dart';
import 'package:poker_credits/util/sound.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

Future<void> _openSettings(WidgetTester tester, TestHarness harness) async {
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('SETTINGS'));
  await tester.pumpAndSettle();
}

ThemeMode _themeMode(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  setUpAll(loadBrutalFonts);

  testWidgets('the theme choice changes the app at once and is saved', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    expect(_themeMode(tester), ThemeMode.system);

    await tester.tap(find.text('DARK'));
    await tester.pump();
    expect(_themeMode(tester), ThemeMode.dark);
    expect(harness.settings.value.theme, ThemeChoice.dark);

    await tester.tap(find.text('LIGHT'));
    await tester.pump();
    expect(_themeMode(tester), ThemeMode.light);
    expect(harness.settings.value.theme, ThemeChoice.light);
  });

  testWidgets('Settings leads to the Support screen and back', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    await tester.scrollUntilVisible(find.text('SUPPORT THE DEVELOPER'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('SUPPORT THE DEVELOPER'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportPage), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportPage), findsNothing);
  });

  testWidgets('the home bar toggles between light and dark', (tester) async {
    final harness = TestHarness();
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Switch light and dark'));
    await tester.pump();
    expect(_themeMode(tester), ThemeMode.dark);
    await tester.tap(find.bySemanticsLabel('Switch light and dark'));
    await tester.pump();
    expect(_themeMode(tester), ThemeMode.light);
  });

  testWidgets('a saved theme is applied on the first frame', (tester) async {
    final harness = TestHarness();
    harness.settings.value = harness.settings.value.copyWith(theme: ThemeChoice.dark);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    expect(_themeMode(tester), ThemeMode.dark);
  });

  testWidgets('the texture switch turns the paper grain off and on', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    bool grain() => BrutalTexture.of(tester.element(find.byType(Scaffold).first));
    expect(grain(), isTrue);
    await tester.tap(find.text('Paper texture'));
    await tester.pump();
    expect(grain(), isFalse);
    expect(harness.settings.value.texture, isFalse);
    await tester.tap(find.text('Paper texture'));
    await tester.pump();
    expect(grain(), isTrue);
  });

  testWidgets('the card switches are off by default and save when changed', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    expect(harness.settings.value.fourColourDeck, isFalse);
    expect(harness.settings.value.cardsFaceUp, isFalse);
    await tester.ensureVisible(find.text('Four-colour deck'));
    await tester.tap(find.text('Four-colour deck'));
    await tester.pump();
    await tester.ensureVisible(find.text('Show my cards at once'));
    await tester.tap(find.text('Show my cards at once'));
    await tester.pump();
    expect(harness.settings.value.fourColourDeck, isTrue);
    expect(harness.settings.value.cardsFaceUp, isTrue);
  });

  testWidgets('every switch reports its state to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _openSettings(tester, TestHarness());
    for (final label in <String>['Sound', 'Vibration', 'Keep screen on', 'Paper texture']) {
      final node = tester.getSemantics(find.ancestor(of: find.text(label), matching: find.byType(BrutalSwitchRow)).first);
      expect(node, isSemantics(hasToggledState: true, isToggled: true), reason: label);
    }
    handle.dispose();
  });

  testWidgets('a valid default name is saved and prefills the join form; a bad one is refused', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    await tester.enterText(find.byType(TextField).first, 'Ana_2');
    await tester.pump();
    expect(harness.settings.value.defaultName, 'Ana_2');

    await tester.enterText(find.byType(TextField).first, 'Ana<>');
    await tester.pump();
    expect(find.text('USE 1 TO 20 LETTERS, DIGITS, SPACES, - OR _'), findsOneWidget);
    expect(harness.settings.value.defaultName, 'Ana_2', reason: 'the last good name is kept');

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JOIN A GAME'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinPage), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.any((f) => f.controller?.text == 'Ana_2'), isTrue);
  });

  testWidgets('forgetting the saved game asks first, then clears it and the home offer', (tester) async {
    final harness = TestHarness();
    await harness.tokens.write(const StoredSession(serverUri: 'ws://127.0.0.1:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 's', hostToken: 'h'));
    await _openSettings(tester, harness);
    expect(find.text('Stop offering to go back to the last game on this device.'), findsOneWidget, reason: 'saved game is known');
    await tester.tap(find.text('FORGET SAVED GAME'));
    await tester.pumpAndSettle();
    expect(find.text('FORGET THE SAVED GAME?'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(await harness.tokens.read(), isNotNull, reason: 'cancel keeps the game');

    await tester.tap(find.text('FORGET SAVED GAME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FORGET'));
    await tester.pumpAndSettle();
    expect(await harness.tokens.read(), isNull);
    expect(find.text('Saved game forgotten.'), findsOneWidget);

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    expect(find.textContaining('RESUME HOSTED GAME'), findsNothing);
  });

  testWidgets('with no saved game the forget row says so and does nothing', (tester) async {
    await _openSettings(tester, TestHarness());
    expect(find.text('No saved game on this device.'), findsOneWidget);
    await tester.tap(find.text('FORGET SAVED GAME'));
    await tester.pumpAndSettle();
    expect(find.text('FORGET THE SAVED GAME?'), findsNothing);
  });

  testWidgets('the about section shows the protocol version and opens the licences', (tester) async {
    await _openSettings(tester, TestHarness());
    await tester.scrollUntilVisible(find.text('Protocol'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('0.1.0+1'), findsOneWidget);
  });

  group('the switches really gate the cues', () {
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add('${call.method} ${call.arguments}');
        return null;
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    test('vibration off: no haptic feedback at all', () async {
      var on = false;
      final haptics = Haptics(enabled: () => on);
      await haptics.tap();
      await haptics.yourTurn();
      expect(calls, isEmpty);
      on = true;
      await haptics.tap();
      expect(calls, isNotEmpty);
    });

    test('sound off: no alert beep', () async {
      var on = false;
      final sound = Sound(enabled: () => on);
      await sound.yourTurn();
      expect(calls, isEmpty);
      on = true;
      await sound.yourTurn();
      expect(calls.single, contains('SystemSound.play'));
    });
  });

  testWidgets('a Help section opens the app tour and the poker lesson again', (tester) async {
    final harness = TestHarness();
    await _openSettings(tester, harness);
    expect(find.text('HELP'), findsOneWidget);
    for (final (label, title) in <(String, String)>[(Strings.helpTourRow, Strings.tourTitle), (Strings.helpLearnRow, Strings.learnTitle)]) {
      await tester.ensureVisible(find.text(label.toUpperCase()));
      await tester.pump();
      await tester.tap(find.text(label.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(WalkthroughPage), findsOneWidget, reason: label);
      expect(find.text(title.toUpperCase()), findsWidgets);
      await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.byType(WalkthroughPage), findsNothing);
    }
  });
}
