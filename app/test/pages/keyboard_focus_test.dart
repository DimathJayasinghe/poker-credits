import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/devices.dart';
import '../support/fakes.dart';

/// A text field must keep its focus (and what was typed) when the on-screen keyboard comes up.
///
/// The pages outside a game pick a tier from the height they have and draw denser as it shrinks.
/// The keyboard takes a third of the screen, so it used to push a page into a denser tier at the
/// very moment the person tapped a field: the field was rebuilt in another place of the tree, lost
/// its focus, and the keyboard closed again. The no-scroll tests missed it because they start with
/// the keyboard already open. Found on an Android emulator.
void main() {
  setUpAll(loadFonts);

  const devices = <Device>[
    Device('Pixel-sized phone', 412, 915, top: 24, bottom: 24),
    Device('Android budget', 360, 640, top: 24, bottom: 48),
    Device('iPhone 14', 390, 844, top: 47, bottom: 34),
    Device('iPhone SE', 375, 667, top: 20),
    // Wide and tall enough that the keyboard alone would push it into the side-by-side layout.
    Device('Tablet landscape', 1024, 700, top: 24, bottom: 24),
  ];

  // A real window shrinks `padding` as the keyboard rises (`viewPadding` stays), a bare
  // MediaQuery does not: both must hold.
  for (final windowLike in <bool>[true, false]) {
    for (final d in devices) {
      testWidgets('a field keeps its focus and text when the keyboard opens: ${d.name}${windowLike ? ', like a real window' : ''}', (tester) async {
        final keyboard = ValueNotifier<double>(0);
        addTearDown(keyboard.dispose);
        tester.view
          ..physicalSize = d.size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = TestHarness().scope(const PokerCreditsApp());
        await tester.pumpWidget(
          ValueListenableBuilder<double>(
            valueListenable: keyboard,
            builder: (context, inset, _) => MediaQuery(
              data: MediaQueryData(
                size: d.size,
                padding: windowLike ? d.insets.copyWith(bottom: (d.insets.bottom - inset).clamp(0.0, double.infinity)) : d.insets,
                viewPadding: d.insets,
                viewInsets: EdgeInsets.only(bottom: inset),
              ),
              child: app,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        for (final entry in <(String, String)>[('PLAY ALONE', 'play alone'), ('JOIN A GAME', 'join'), ('HOST A GAME', 'host')]) {
          await tester.ensureVisible(find.text(entry.$1));
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();

          final field = find.byType(TextField).first;
          await tester.tap(field);
          await tester.pumpAndSettle();
          EditableTextState editable() => tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)).first);
          expect(editable().widget.focusNode.hasFocus, isTrue, reason: '${entry.$2}: tapped field has focus');

          // The keyboard comes up, as the system does it: after the tap, over a few frames.
          for (final inset in <double>[60, 150, 240, 310]) {
            keyboard.value = inset;
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pumpAndSettle();
          expect(editable().widget.focusNode.hasFocus, isTrue, reason: '${entry.$2}: the field still has focus with the keyboard open');

          await tester.enterText(field, 'Ana');
          await tester.pumpAndSettle();
          keyboard.value = 0;
          await tester.pumpAndSettle();
          expect(find.text('Ana'), findsOneWidget, reason: '${entry.$2}: what was typed survives the keyboard closing');

          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('the first-run name field keeps its focus when the keyboard opens: ${d.name}${windowLike ? ', like a real window' : ''}', (
        tester,
      ) async {
        final keyboard = ValueNotifier<double>(0);
        addTearDown(keyboard.dispose);
        tester.view
          ..physicalSize = d.size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = TestHarness(askName: true).scope(const PokerCreditsApp());
        await tester.pumpWidget(
          ValueListenableBuilder<double>(
            valueListenable: keyboard,
            builder: (context, inset, _) => MediaQuery(
              data: MediaQueryData(
                size: d.size,
                padding: windowLike ? d.insets.copyWith(bottom: (d.insets.bottom - inset).clamp(0.0, double.infinity)) : d.insets,
                viewPadding: d.insets,
                viewInsets: EdgeInsets.only(bottom: inset),
              ),
              child: app,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        for (final inset in <double>[60, 150, 240, 310]) {
          keyboard.value = inset;
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        final editable = tester.state<EditableTextState>(find.descendant(of: find.byType(TextField), matching: find.byType(EditableText)).first);
        expect(editable.widget.focusNode.hasFocus, isTrue, reason: 'the name field still has focus with the keyboard open');
        await tester.enterText(find.byType(TextField), 'Ana');
        await tester.pumpAndSettle();
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text(Strings.nameStepSave.toUpperCase()), findsOneWidget, reason: 'the button that goes on stays on screen');
      });
    }
  }
}
