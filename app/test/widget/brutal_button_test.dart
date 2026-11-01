import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders the label uppercased and calls onPressed on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(BrutalButton(label: 'Call 20', onPressed: () => taps++)));

    expect(find.text('CALL 20'), findsOneWidget);
    await tester.tap(find.byType(BrutalButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('does not react when disabled', (tester) async {
    await tester.pumpWidget(_host(const BrutalButton(label: 'Fold', onPressed: null)));

    await tester.tap(find.byType(BrutalButton));
    await tester.pump();
    expect(tester.getSemantics(find.byType(BrutalButton)).flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('exposes button semantics with its label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(BrutalButton(label: 'Raise', onPressed: () {})));

    final node = tester.getSemantics(find.byType(BrutalButton));
    expect(node.label, 'Raise');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('has a minimum tap target of 48 logical pixels', (tester) async {
    await tester.pumpWidget(_host(BrutalButton(label: 'OK', onPressed: () {})));

    final size = tester.getSize(find.byType(BrutalButton));
    expect(size.height, greaterThanOrEqualTo(BrutalMetrics.tap));
    expect(size.width, greaterThanOrEqualTo(BrutalMetrics.tap));
  });
}
