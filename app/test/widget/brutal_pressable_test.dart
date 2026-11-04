import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';

import '../support/test_app.dart';

/// The fill colour of the first [AnimatedContainer] under [of], as painted right now.
Color? _fill(WidgetTester tester, Finder of) {
  final container = tester.widget<AnimatedContainer>(find.descendant(of: of, matching: find.byType(AnimatedContainer)).first);
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  setUpAll(loadBrutalFonts);

  group('BrutalPressable', () {
    Widget probe(VoidCallback onTap, List<bool> seen, {bool enabled = true}) => brutalHost(
      Center(
        child: BrutalPressable(
          onTap: onTap,
          enabled: enabled,
          builder: (context, pressed) {
            seen.add(pressed);
            return const SizedBox(key: Key('probe'), width: 80, height: 80);
          },
        ),
      ),
    );

    testWidgets('a quick tap keeps the pressed look for the minimum hold, then lets go', (tester) async {
      var taps = 0;
      final seen = <bool>[];
      await tester.pumpWidget(probe(() => taps++, seen));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('probe'))));
      await tester.pump();
      expect(seen.last, isTrue, reason: 'pressed as soon as the finger is down');
      await gesture.up();
      await tester.pump();
      expect(taps, 1, reason: 'the tap itself is never delayed');
      expect(seen.last, isTrue, reason: 'still shown pressed right after a quick tap');
      await tester.pump(BrutalPressable.minHold + const Duration(milliseconds: 10));
      expect(seen.last, isFalse);
    });

    testWidgets('a long press releases the moment the finger lifts', (tester) async {
      final seen = <bool>[];
      await tester.pumpWidget(probe(() {}, seen));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('probe'))));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();
      expect(seen.last, isFalse);
    });

    testWidgets('a cancelled press (finger dragged away) also lets go', (tester) async {
      var taps = 0;
      final seen = <bool>[];
      await tester.pumpWidget(probe(() => taps++, seen));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('probe'))));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pump(BrutalPressable.minHold + const Duration(milliseconds: 10));
      expect(taps, 0);
      expect(seen.last, isFalse);
    });

    testWidgets('a disabled one never looks pressed and never fires', (tester) async {
      var taps = 0;
      final seen = <bool>[];
      await tester.pumpWidget(probe(() => taps++, seen, enabled: false));
      await tester.tap(find.byKey(const Key('probe')), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      expect(seen.every((p) => !p), isTrue);
    });

    testWidgets('leaving the page mid-press leaves no timer behind', (tester) async {
      final seen = <bool>[];
      await tester.pumpWidget(probe(() {}, seen));
      await tester.startGesture(tester.getCenter(find.byKey(const Key('probe'))));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      // The test fails on its own if a Timer is still pending here.
    });
  });

  group('every tappable cell shows the press', () {
    testWidgets('button: the fill inverts while pressed and eases back', (tester) async {
      await tester.pumpWidget(
        brutalHost(
          Center(
            child: BrutalButton(label: 'Go', onPressed: () {}),
          ),
        ),
      );
      final button = find.byType(BrutalButton);
      final before = _fill(tester, button);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 200));
      final during = _fill(tester, button);
      expect(during, isNot(before));
      await gesture.up();
      await tester.pump(BrutalPressable.minHold + const Duration(milliseconds: 200));
      expect(_fill(tester, button), before);
    });

    testWidgets('row, back cell, segmented cell and switch row all change while pressed', (tester) async {
      var value = false;
      await tester.pumpWidget(
        brutalHost(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: <Widget>[
                BrutalRow(label: 'Row', onTap: () {}),
                BackCell(onTap: () {}),
                BrutalSegmented<int>(value: 1, options: const <(int, String)>[(1, 'One'), (2, 'Two')], onChanged: (_) {}),
                BrutalSwitchRow(label: 'Switch', value: value, onChanged: (v) => setState(() => value = v)),
              ],
            ),
          ),
        ),
      );
      // Where to press, and the animated cell whose fill must change.
      final cells = <(Finder, Finder)>[
        (find.byType(BrutalRow), find.descendant(of: find.byType(BrutalRow), matching: find.byType(AnimatedContainer)).first),
        (find.byType(BackCell), find.descendant(of: find.byType(BackCell), matching: find.byType(AnimatedContainer)).first),
        (find.text('TWO'), find.ancestor(of: find.text('TWO'), matching: find.byType(AnimatedContainer)).first),
        (find.byType(BrutalSwitchRow), find.descendant(of: find.byType(BrutalSwitchRow), matching: find.byType(AnimatedContainer)).first),
      ];
      for (final (press, cell) in cells) {
        Color? fill() => ((tester.widget<AnimatedContainer>(cell)).decoration as BoxDecoration?)?.color;
        final before = fill();
        final gesture = await tester.startGesture(tester.getCenter(press));
        await tester.pump(const Duration(milliseconds: 200));
        expect(fill(), isNot(before), reason: '$press shows no pressed state');
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(value, isTrue, reason: 'the switch toggled');
    });

    testWidgets('reduced motion still shows the pressed state, just without easing', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: brutalHost(
            Center(
              child: BrutalButton(label: 'Go', onPressed: () {}),
            ),
          ),
        ),
      );
      final button = find.byType(BrutalButton);
      final before = _fill(tester, button);
      await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      expect(_fill(tester, button), isNot(before));
      expect(BrutalTheme.duration(tester.element(button), const Duration(milliseconds: 90)), Duration.zero);
    });
  });
}
