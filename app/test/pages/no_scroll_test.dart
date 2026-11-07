import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/tour_content.dart';

import '../support/devices.dart';
import '../support/fakes.dart';
import '../support/no_scroll.dart';

/// A game never scrolls, and neither does any screen around it except Settings, the Guide and
/// the terms (a document). On every phone, upright and on its side, on tablets and in a desktop
/// window, at the normal text size and a big one, with the keyboard closed, everything on these
/// screens is on screen at once. (Bigger text than that, or an open keyboard, may scroll.)

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  for (final scale in <double>[1.0, 1.3]) {
    for (final d in allDevices) {
      testWidgets('menus: ${d.name} ${d.width.toInt()}x${d.height.toInt()}, text x$scale', (tester) async {
        final misfits = Misfits();
        await launchOn(tester, TestHarness(), d, scale: scale);
        misfits.check(tester, 'home', find.text('HOST A GAME'), d, scale);

        await tester.ensureVisible(find.text('PLAY ALONE'));
        await tester.tap(find.text('PLAY ALONE'));
        await tester.pumpAndSettle();
        misfits.check(tester, 'play alone setup', find.byType(TextField).first, d, scale);
        await _back(tester);

        await tester.ensureVisible(find.text('JOIN A GAME'));
        await tester.tap(find.text('JOIN A GAME'));
        await tester.pumpAndSettle();
        misfits.check(tester, 'join', find.byType(TextField).first, d, scale);
        await _back(tester);

        // The same page on a phone that can scan a QR code (the test machine cannot).
        unawaited(
          Navigator.of(tester.element(find.byType(Scaffold).last)).push(MaterialPageRoute<void>(builder: (_) => const JoinPage(scanSupported: true))),
        );
        await tester.pumpAndSettle();
        misfits.check(tester, 'join with the QR button', find.byType(TextField).first, d, scale);
        await _back(tester);

        await tester.ensureVisible(find.text('HOST A GAME'));
        await tester.tap(find.text('HOST A GAME'));
        await tester.pumpAndSettle();
        misfits.check(tester, 'host setup', find.byType(TextField).first, d, scale);
        await _back(tester);

        await tester.tap(find.text('SETTINGS'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(Strings.supportRow.toUpperCase()));
        await tester.tap(find.text(Strings.supportRow.toUpperCase()));
        await tester.pumpAndSettle();
        misfits.check(tester, 'support', find.text(Strings.supportThanks.toUpperCase()), d, scale);
        await tester.pumpWidget(const SizedBox());

        await launchOn(tester, TestHarness(firstRun: true, splash: const Duration(seconds: 30)), d, scale: scale);
        await tester.tap(find.byType(Scaffold).first);
        await tester.pumpAndSettle();
        // The terms are a document and scroll; their agree switch and buttons must not.
        expect(find.text(Strings.termsAccept.toUpperCase()), findsOneWidget);
        misfits.check(tester, 'terms buttons', find.text(Strings.termsAccept.toUpperCase()), d, scale);
        await tester.ensureVisible(find.text(Strings.termsAgree));
        await tester.tap(find.text(Strings.termsAgree));
        await tester.pump();
        await tester.ensureVisible(find.text(Strings.termsAccept.toUpperCase()));
        await tester.tap(find.text(Strings.termsAccept.toUpperCase()));
        await tester.pumpAndSettle();
        misfits.check(tester, 'intro', find.text(Strings.introSkip.toUpperCase()), d, scale);
        await tester.tap(find.text(Strings.introTour.toUpperCase()));
        await tester.pumpAndSettle();
        for (var i = 1; i <= appTourSteps.length; i++) {
          misfits.check(tester, 'app tour step $i', find.text(Strings.walkStep(i, appTourSteps.length).toUpperCase()), d, scale);
          if (i < appTourSteps.length) {
            await tester.tap(find.text(Strings.walkNext.toUpperCase()));
            await tester.pumpAndSettle();
          }
        }
        await tester.pumpWidget(const SizedBox());
        misfits.done(d, scale);
      });
    }
  }
}
