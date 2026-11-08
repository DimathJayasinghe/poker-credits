import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/tour_content.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
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
      expect(appTourSteps.map((s) => s.title), contains('Play alone'));
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

    test('the flush example uses 9 different cards and Alice really holds five hearts', () {
      final all = <String>[...flushBoard, ...flushAlice, ...flushBob];
      expect(all.map(PokerCard.parse).toSet(), hasLength(9));
      final hearts = <String>[...flushBoard, ...flushAlice].where((c) => c.endsWith('h'));
      expect(hearts.length, greaterThanOrEqualTo(5), reason: 'Alice has a flush');
      expect(<String>[...flushBoard, ...flushBob].where((c) => c.endsWith('h')).length, lessThan(5), reason: 'Bob has no flush');
    });

    test('the two side-by-side pictures use 10 different cards each', () {
      for (final rows in <List<(String, List<String>, bool)>>[tieBreakRows, kickerRows]) {
        expect(rows, hasLength(2));
        expect(rows.where((r) => r.$3), hasLength(1), reason: 'exactly one winner is marked');
        expect(<PokerCard>{for (final r in rows) ...r.$2.map(PokerCard.parse)}, hasLength(10));
      }
    });

    test('the lesson is a gentle one: many short steps, short sentences, each idea once', () {
      expect(pokerLessonSteps.length, greaterThanOrEqualTo(20), reason: 'one idea per step');
      for (final step in pokerLessonSteps) {
        expect(step.body.length, lessThanOrEqualTo(300), reason: '${step.title} is too long to read at a glance');
        for (final sentence in step.body.split(RegExp(r'[.!?\n]')).where((s) => s.trim().isNotEmpty)) {
          expect(sentence.trim().split(RegExp(r'\s+')).length, lessThanOrEqualTo(24), reason: '"$sentence" in ${step.title}');
        }
      }
      expect(pokerLessonSteps.map((s) => s.title).toSet(), hasLength(pokerLessonSteps.length), reason: 'no two steps share a title');
    });

    test('the ten hands are taught weakest first, two a step, each named in the words beside its picture', () {
      expect(lessonHandPairs, hasLength(5));
      final seen = <int>[];
      for (final (art, weaker, stronger) in lessonHandPairs) {
        final step = pokerLessonSteps.firstWhere((s) => s.art == art);
        expect(weaker, greaterThan(stronger), reason: 'handExamples lists the strongest first');
        for (final index in <int>[weaker, stronger]) {
          expect(step.body.toLowerCase(), contains(handExamples[index].$1.toLowerCase()), reason: step.title);
        }
        seen
          ..add(weaker)
          ..add(stronger);
      }
      expect(seen, <int>[9, 8, 7, 6, 5, 4, 3, 2, 1, 0], reason: 'every hand once, from high card to royal flush');
      final order = <StepArt>[for (final (art, _, _) in lessonHandPairs) art];
      final positions = <int>[for (final art in order) pokerLessonSteps.indexWhere((s) => s.art == art)];
      expect(positions, orderedEquals(<int>[...positions]..sort()), reason: 'in the lesson in that order');
    });

    test('each word the lesson relies on is explained somewhere in it', () {
      final all = pokerLessonSteps.map((s) => s.body.toLowerCase()).join('\n');
      for (final word in <String>[
        'pot',
        'hole cards',
        'board',
        'pre-flop',
        'flop',
        'turn',
        'river',
        'dealer button',
        'blinds',
        'fold',
        'check',
        'call',
        'raise',
        'all-in',
        'showdown',
        'kicker',
      ]) {
        expect(all, contains(word));
      }
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

  group('follow-up', () {
    Future<void> openWithFollowUp(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        brutalHost(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WalkthroughPage(
                    title: 'Lesson',
                    steps: pokerLessonSteps,
                    followUp: const WalkthroughFollowUp(label: 'Next: see how the app works', title: 'App tour', steps: appTourSteps),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on the last step only', (tester) async {
      await openWithFollowUp(tester);
      expect(find.text('NEXT: SEE HOW THE APP WORKS'), findsNothing);
      for (var i = 0; i < pokerLessonSteps.length - 1; i++) {
        await tester.tap(find.text(Strings.walkNext.toUpperCase()));
        await tester.pumpAndSettle();
      }
      expect(find.text('NEXT: SEE HOW THE APP WORKS'), findsOneWidget);
    });

    testWidgets('opens the other walkthrough in place of this one', (tester) async {
      await openWithFollowUp(tester);
      for (var i = 0; i < pokerLessonSteps.length - 1; i++) {
        await tester.tap(find.text(Strings.walkNext.toUpperCase()));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('NEXT: SEE HOW THE APP WORKS'));
      await tester.pumpAndSettle();
      expect(find.text('APP TOUR'), findsOneWidget, reason: 'the tour is open');
      expect(find.text(appTourSteps.first.title.toUpperCase()), findsOneWidget);
      // Leaving the tour goes back to where the lesson was opened from, not to the lesson.
      await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('with skipOpensIt, Skip, the back arrow, the back gesture and Escape all open the other walkthrough', (tester) async {
      Future<void> openSkipping() async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          brutalHost(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WalkthroughPage(
                      title: 'Tour',
                      steps: appTourSteps,
                      followUp: const WalkthroughFollowUp(label: 'Next: learn poker', title: 'Lesson', steps: pokerLessonSteps, skipOpensIt: true),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      final leaves = <String, Future<void> Function()>{
        'Skip': () => tester.tap(find.text(Strings.walkSkip.toUpperCase())),
        'back arrow': () => tester.tap(find.descendant(of: find.byType(AppTopBar), matching: find.bySemanticsLabel(Strings.back))),
        'back gesture': () => tester.binding.handlePopRoute(),
        'Escape': () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      };
      for (final MapEntry(key: how, value: leave) in leaves.entries) {
        await openSkipping();
        await leave();
        await tester.pumpAndSettle();
        expect(find.text('LESSON'), findsOneWidget, reason: '$how opens the lesson');
        expect(find.text(pokerLessonSteps.first.title.toUpperCase()), findsOneWidget, reason: how);
        // The lesson has no follow-up of its own: Skip returns to where the tour was opened from.
        await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget, reason: '$how, then Skip in the lesson');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('without skipOpensIt, Skip still just leaves', (tester) async {
      await openWithFollowUp(tester);
      await tester.tap(find.text(Strings.walkSkip.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.text('APP TOUR'), findsNothing);
    });

    testWidgets('a walkthrough opened without one shows no extra button', (tester) async {
      await _open(tester, pokerLessonSteps, (_) {});
      for (var i = 0; i < pokerLessonSteps.length - 1; i++) {
        await tester.tap(find.text(Strings.walkNext.toUpperCase()));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('NEXT:'), findsNothing);
    });
  });
}
