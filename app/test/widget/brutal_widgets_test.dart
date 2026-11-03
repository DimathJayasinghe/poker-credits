import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_dialog.dart';
import 'package:poker_credits/widget/brutal/brutal_keypad.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/brutal/brutal_slider.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('tag uppercases its label and exposes it to accessibility', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(brutalHost(const Center(child: BrutalTag('all-in', kind: BrutalTagKind.danger))));
    expect(find.text('ALL-IN'), findsOneWidget);
    expect(tester.getSemantics(find.byType(BrutalTag)).label, 'all-in');
    handle.dispose();
  });

  testWidgets('banner shows the message and runs its action', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      brutalHost(BrutalBanner(message: 'Reconnecting', kind: BrutalBannerKind.warning, actionLabel: 'Retry', onAction: () => retried++)),
    );
    expect(find.text('RECONNECTING'), findsOneWidget);
    await tester.tap(find.text('RETRY'));
    expect(retried, 1);
  });

  group('slider', () {
    testWidgets('tapping a tick selects its value, clamped to the range', (tester) async {
      var value = 40;
      await tester.pumpWidget(
        brutalHost(
          StatefulBuilder(
            builder: (context, setState) => BrutalSlider(
              value: value,
              min: 20,
              max: 500,
              ticks: const <BrutalTick>[BrutalTick('Min', 20), BrutalTick('All-in', 900)],
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ALL-IN'));
      await tester.pump();
      expect(value, 500);
      await tester.tap(find.text('MIN'));
      await tester.pump();
      expect(value, 20);
    });

    testWidgets('dragging maps the position to a value between min and max', (tester) async {
      var value = 0;
      await tester.pumpWidget(
        brutalHost(
          Center(
            child: SizedBox(
              width: 432,
              child: BrutalSlider(value: value, min: 0, max: 400, onChanged: (v) => value = v),
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(GestureDetector).first);
      await tester.tapAt(Offset(box.left + 16, box.center.dy));
      expect(value, 0);
      await tester.tapAt(Offset(box.right - 16, box.center.dy));
      expect(value, 400);
    });

    testWidgets('semantic increase and decrease move by one step', (tester) async {
      final handle = tester.ensureSemantics();
      var value = 100;
      await tester.pumpWidget(brutalHost(BrutalSlider(value: value, min: 0, max: 200, step: 10, onChanged: (v) => value = v)));
      tester.semantics.increase(find.semantics.byAction(SemanticsAction.increase));
      await tester.pump();
      expect(value, 110);
      handle.dispose();
    });
  });

  testWidgets('keypad reports digits, backspace and clear', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      brutalHost(
        BrutalKeypad(onDigit: (d) => pressed.add('$d'), onBackspace: () => pressed.add('<'), onClear: () => pressed.add('C')),
      ),
    );
    for (final label in <String>['7', '0', '<', 'C']) {
      await tester.tap(find.text(label));
    }
    expect(pressed, <String>['7', '0', '<', 'C']);
  });

  testWidgets('text field shows its label, forwards input and shows the error strip', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      brutalHost(
        Center(
          child: BrutalTextField(label: 'Room code', errorText: 'Unknown room', onChanged: changes.add),
        ),
      ),
    );
    expect(find.text('ROOM CODE'), findsOneWidget);
    expect(find.text('UNKNOWN ROOM'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'KQ7M');
    expect(changes, <String>['KQ7M']);
  });

  testWidgets('dialog returns the confirm result', (tester) async {
    bool? result;
    await tester.pumpWidget(
      brutalHost(
        Builder(
          builder: (context) => BrutalButton(
            label: 'Open',
            onPressed: () async => result = await confirmBrutal(
              context: context,
              title: 'Kick',
              message: 'Remove Bob?',
              confirmLabel: 'Kick',
              cancelLabel: 'Cancel',
              danger: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('REMOVE BOB?'), findsNothing); // message keeps its case
    expect(find.text('Remove Bob?'), findsOneWidget);
    await tester.tap(find.text('KICK').last);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('sheet shows its title and content', (tester) async {
    await tester.pumpWidget(
      brutalHost(
        Builder(
          builder: (context) => BrutalButton(
            label: 'Open',
            onPressed: () => showBrutalSheet<void>(context: context, title: 'Raise', builder: (_) => const Text('content')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('RAISE'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });
}
