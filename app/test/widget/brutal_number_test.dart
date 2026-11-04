import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(loadBrutalFonts);

  Future<double> widthOf(WidgetTester tester, int value, {double size = 96}) async {
    await tester.pumpWidget(brutalHost(Center(child: BrutalNumber(value, size: size))));
    return tester.getSize(find.byType(BrutalNumber)).width;
  }

  testWidgets('digits are tabular: 1111 is as wide as 8888', (tester) async {
    expect(await widthOf(tester, 1111), await widthOf(tester, 8888));
  });

  testWidgets('a counting pot never shifts: every 4-digit number has one width', (tester) async {
    final widths = <double>{};
    for (final value in <int>[1000, 1111, 1234, 9999, 4711, 1010]) {
      widths.add(await widthOf(tester, value));
    }
    expect(widths, hasLength(1));
  });

  testWidgets('width grows with the number of digits and with the text size setting', (tester) async {
    final two = await widthOf(tester, 11);
    final four = await widthOf(tester, 1111);
    expect(four, closeTo(two * 2, 0.01));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: brutalHost(const Center(child: BrutalNumber(1111, size: 96))),
      ),
    );
    expect(tester.getSize(find.byType(BrutalNumber)).width, closeTo(four * 2, 0.01));
  });

  testWidgets('screen readers hear the number, not its digit boxes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(brutalHost(const Center(child: BrutalNumber(1205))));
    expect(find.bySemanticsLabel('1205'), findsOneWidget);
    handle.dispose();
  });
}
