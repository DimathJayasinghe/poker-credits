import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/util/strings.dart';

import '../support/fakes.dart';
import '../support/store_shot.dart';

/// Makes the desktop screenshots of the Microsoft Store listing from the real screens (the same
/// fakes and fonts as the golden tests). Skipped unless `STORE_SHOTS_DIR` is set; the table shot is
/// made in `test/pages/solo_table_test.dart`, which owns the table fixtures.
void main() {
  setUpAll(loadFonts);

  final skip = storeShotsDir == null ? 'set STORE_SHOTS_DIR to make the Store screenshots' : null;

  for (final tab in <String>[Strings.navPlay, Strings.navGuide, Strings.navSettings]) {
    testWidgets('store screenshot, ${tab.toLowerCase()} tab', (tester) async {
      final harness = TestHarness();
      harness.settings.value = harness.settings.value.copyWith(theme: ThemeChoice.light);
      tester.view
        ..physicalSize = storeShotSize
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
      await tester.pumpAndSettle();
      if (tab != Strings.navPlay) {
        await tester.tap(find.text(tab.toUpperCase()).first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await saveStoreShot(tester, 'windows-${tab.toLowerCase()}');
    }, skip: skip != null);
  }
}
