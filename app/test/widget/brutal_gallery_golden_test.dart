import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_keypad.dart';
import 'package:poker_credits/widget/brutal/brutal_slider.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';

import '../support/test_app.dart';

Widget _gallery() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          BrutalTag('D'),
          BrutalTag('SB', kind: BrutalTagKind.info),
          BrutalTag('All-in', kind: BrutalTagKind.danger),
          BrutalTag('Auto', kind: BrutalTagKind.signal),
          BrutalTag('Folded'),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: BrutalButton(label: 'Raise', kind: BrutalButtonKind.primary, heavy: true, onPressed: () {}),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: BrutalButton(label: 'Fold', kind: BrutalButtonKind.danger, onPressed: () {}),
          ),
          const SizedBox(width: 16),
          const Expanded(child: BrutalButton(label: 'Off', onPressed: null)),
        ],
      ),
      const SizedBox(height: 16),
      const BrutalBanner(message: 'Reconnecting', kind: BrutalBannerKind.warning),
      const SizedBox(height: 8),
      const BrutalBanner(message: 'Game paused by host'),
      const SizedBox(height: 8),
      const BrutalBanner(message: 'Not your turn', kind: BrutalBannerKind.error),
      const SizedBox(height: 16),
      const BrutalCard(header: 'Pot', child: Text('210')),
      const SizedBox(height: 16),
      const BrutalTextField(label: 'Name', hintText: 'Alice', errorText: 'Name taken'),
      const SizedBox(height: 16),
      BrutalSlider(
        value: 120,
        min: 20,
        max: 500,
        ticks: const <BrutalTick>[BrutalTick('Min', 20), BrutalTick('Pot', 210), BrutalTick('All-in', 500)],
        onChanged: (_) {},
      ),
      const SizedBox(height: 16),
      BrutalKeypad(onDigit: (_) {}, onBackspace: () {}, onClear: () {}),
    ],
  ),
);

void main() {
  setUpAll(loadBrutalFonts);

  for (final dark in <bool>[false, true]) {
    testWidgets('component gallery, ${dark ? 'dark' : 'light'}, phone portrait', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 1500)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(brutalHost(_gallery(), dark: dark));
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/gallery_${dark ? 'dark' : 'light'}.png'));
    });
  }
}
