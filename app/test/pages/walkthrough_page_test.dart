import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/tour_content.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/test_app.dart';

/// Opens a walkthrough over a home page and records how it ended.
class _Opener extends StatefulWidget {
  const _Opener(this.steps, this.onEnd);

  final List<WalkthroughStep> steps;
  final void Function(WalkthroughEnd? end) onEnd;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async {
        final end = await Navigator.of(context).push<WalkthroughEnd>(
          MaterialPageRoute<WalkthroughEnd>(
            builder: (_) => WalkthroughPage(title: 'Tour', steps: widget.steps),
          ),
        );
        widget.onEnd(end);
      },
      child: const Text('open'),
    ),
  );
}

Future<void> _open(WidgetTester tester, List<WalkthroughStep> steps, void Function(WalkthroughEnd?) onEnd, {Size size = const Size(390, 844)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(brutalHost(_Opener(steps, onEnd)));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadBrutalFonts);

  group('content', () {
    test('every step has a title, a body, a picture description and a picture', () {
      for (final step in <WalkthroughStep>[...appTourSteps, ...pokerLessonSteps]) {
        expect(step.title.trim(), isNotEmpty);
        expect(step.body.trim().length, greaterThan(40), reason: step.title);
        expect(step.artLabel.trim(), isNotEmpty, reason: step.title);
      }
      expect(appTourSteps.map((s) => s.art).toSet(), hasLength(appTourSteps.length), reason: 'one picture per step');
      expect(pokerLessonSteps.map((s) => s.art).toSet(), hasLength(pokerLessonSteps.length));
    });

    test('the ten example hands are in the order of the guide and are five different real cards each', () {
      expect(handExamples.map((h) => h.$1), guideHands.map((h) => h.name));
      for (final (name, cards) in handExamples) {
        final parsed = <PokerCard>[for (final c in cards) PokerCard.parse(c)];
        expect(parsed, hasLength(5), reason: name);
        expect(parsed.toSet(), hasLength(5), reason: '$name repeats a card');
      }
    });

    test('the worked example and the board use 9 different cards', () {
      final all = <String>[...exampleBoard, ...exampleAlice, ...exampleBob];
      expect(all.map(PokerCard.parse).toSet(), hasLength(9));
      expect(lessonBoard.map(PokerCard.parse).toSet(), hasLength(5));
    });
  });

  group('pager', () {
    testWidgets('starts on step 1 with Back off, and Next moves on', (tester) async {
      await _open(tester, appTourSteps, (_) {});
      expect(find.text(Strings.walkStep(1, appTourSteps.length).toUpperCase()), findsOneWidget);
      expect(find.text(appTourSteps[0].title.toUpperCase()), findsOneWidget);
      await tester.tap(find.text(Strings.walkNext.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(Strings.walkStep(2, appTourSteps.length).toUpperCase()), findsOneWidget);
      await tester.tap(find.text(Strings.back.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(Strings.walkStep(1, appTourSteps.length).toUpperCase()), findsOneWidget);
    });

    testWidgets('the last step says Done and finishing reports "finished"', (tester) async {
      WalkthroughEnd? ended;
      await _open(tester, appTourSteps, (e) => ended = e);
      for (var i = 1; i < appTourSteps.length; i++) {
        await tester.tap(find.text(Strings.walkNext.toUpperCase()));
        await tester.pumpAndSettle();
      }
      expect(find.text(Strings.walkNext.toUpperCase()), findsNothing);
      await tester.tap(find.text(Strings.walkDone.toUpperCase()));
      await tester.pumpAndSettle();
      expect(ended, WalkthroughEnd.finished);
      expect(find.byType(WalkthroughPage), findsNothing);
    });

    testWidgets('Skip works from any step and reports "skipped"', (tester) async {
      WalkthroughEnd? ended;
      await _open(tester, appTourSteps, (e) => ended = e);
      await tester.tap(find.text(Strings.walkNext.toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(ended, WalkthroughEnd.skipped);
    });

    testWidgets('the system back gesture counts as skipping', (tester) async {
      WalkthroughEnd? ended;
      await _open(tester, appTourSteps, (e) => ended = e);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(ended, WalkthroughEnd.skipped);
      expect(find.byType(WalkthroughPage), findsNothing);
    });

    testWidgets('swiping and the arrow keys move between steps', (tester) async {
      await _open(tester, pokerLessonSteps, (_) {});
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text(Strings.walkStep(2, pokerLessonSteps.length).toUpperCase()), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text(Strings.walkStep(3, pokerLessonSteps.length).toUpperCase()), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text(Strings.walkStep(2, pokerLessonSteps.length).toUpperCase()), findsOneWidget);
    });
  });

  group('layout', () {
    const sizes = <Size>[Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)];
    for (final scale in <double>[1, 2, 3]) {
      for (final size in sizes) {
        testWidgets('every step of both walkthroughs fits at ${size.width.toInt()}x${size.height.toInt()}, text scale $scale', (tester) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          for (final steps in <List<WalkthroughStep>>[appTourSteps, pokerLessonSteps]) {
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
                child: brutalHost(WalkthroughPage(key: ValueKey<List<WalkthroughStep>>(steps), title: 'Tour', steps: steps)),
              ),
            );
            for (var i = 0; i < steps.length; i++) {
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'step ${i + 1} of ${steps.length}');
              if (i < steps.length - 1) {
                await tester.tap(find.text(Strings.walkNext.toUpperCase()));
              }
            }
          }
        });
      }
    }
  });
}
