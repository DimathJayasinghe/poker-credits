import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(loadBrutalFonts);

  testWidgets('every cell of a top bar puts its label and value on the same lines, however long the value', (tester) async {
    // A narrow phone: the long phase name has to shrink to fit its cell.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      brutalHost(
        const SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TopBarStat(label: 'Room', value: 'QSKX'),
              ),
              Expanded(
                flex: 2,
                child: TopBarStat(label: 'Hand', value: '5'),
              ),
              Expanded(
                flex: 3,
                child: TopBarStat(label: 'Phase', value: 'Showdown'),
              ),
              Expanded(
                flex: 3,
                child: TopBarStat(label: 'Street', value: 'Between hands'),
              ),
            ],
          ),
        ),
      ),
    );

    double top(String text) => tester.getTopLeft(find.text(text.toUpperCase())).dy;
    double bottom(String text) => tester.getBottomLeft(find.text(text.toUpperCase())).dy;

    // Labels share one line.
    expect(top('Room'), top('Hand'));
    expect(top('Hand'), top('Phase'));
    // Values share one baseline-ish band: their vertical centres match even when one is scaled down.
    double mid(String text) => (top(text) + bottom(text)) / 2;
    expect((mid('5') - mid('QSKX')).abs(), lessThan(0.5));
    expect((mid('Showdown') - mid('QSKX')).abs(), lessThan(0.5));
    expect((mid('Between hands') - mid('QSKX')).abs(), lessThan(0.5));
  });
}
