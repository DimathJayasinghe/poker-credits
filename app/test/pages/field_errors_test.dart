import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/fakes.dart';

/// A message about a field must go away as soon as the field is fixed. It used to stay until the
/// next press of the button, because nothing redrew the page while typing (found on an Android
/// emulator: the room code was right and still marked wrong).
void main() {
  setUpAll(loadFonts);

  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester, String entry) async {
    await tester.pumpWidget(TestHarness().scope(const PokerCreditsApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text(entry));
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('join: the room code message goes away when the code is fixed', (tester) async {
    phone(tester);
    await open(tester, 'JOIN A GAME');
    await press(tester, 'JOIN');
    expect(find.text(Strings.codeInvalid.toUpperCase()), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'KQ7M');
    await tester.pump();
    expect(find.text(Strings.codeInvalid.toUpperCase()), findsNothing);
  });

  testWidgets('join: the name message goes away when the name is fixed', (tester) async {
    phone(tester);
    await open(tester, 'JOIN A GAME');
    await tester.enterText(find.byType(TextField).first, 'KQ7M');
    await tester.enterText(find.byType(TextField).at(1), '');
    await press(tester, 'JOIN');
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Ana');
    await tester.pump();
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsNothing);
  });

  testWidgets('host: the name message goes away when the name is fixed', (tester) async {
    phone(tester);
    await open(tester, 'HOST A GAME');
    await tester.enterText(find.byType(TextField).first, '');
    await press(tester, Strings.startHosting.toUpperCase());
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pump();
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsNothing);
  });

  testWidgets('play alone: the name message goes away when the name is fixed', (tester) async {
    phone(tester);
    await open(tester, 'PLAY ALONE');
    await tester.enterText(find.byType(TextField).first, '');
    await press(tester, 'START GAME');
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pump();
    expect(find.text(Strings.nameInvalid.toUpperCase()), findsNothing);
  });
}
