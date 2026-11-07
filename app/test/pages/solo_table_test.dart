import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/pages/solo_result_page.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

/// The human is Dimath at seat 1 (the fake host answers `p_1`); the others are the table.
List<SeatView> _seats({int others = 4, bool cards = true}) => <SeatView>[
  seatView(0, 'Maya', chips: 1800, hasCards: cards),
  seatView(1, 'Dimath', chips: 1500, hasCards: cards),
  for (var i = 2; i < others + 1; i++) seatView(i, ['Liam', 'Zoe', 'Noor', 'Eli', 'Ava', 'Kai', 'Ben', 'Joy'][i - 2], chips: 1200, hasCards: cards),
];

RoomView _view({
  int hand = 3,
  int? active = 0,
  List<SeatView>? seats,
  BlindsView? blinds = const BlindsView(smallBlind: 25, bigBlind: 50, nextSmallBlind: 40, nextBigBlind: 80, handsLeft: 3),
  List<Finish> finish = const <Finish>[],
  bool paused = false,
  HandResult? result,
  List<Reveal> reveals = const <Reveal>[],
}) => roomView(
  hand: hand,
  activeSeat: active,
  pot: 90,
  seats: seats ?? _seats(),
  result: result,
  reveals: reveals,
).copyWith(blinds: blinds, finishOrder: finish, paused: paused);

void _phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Starts a game from Home (4 Normal opponents) and sends the first snapshot.
Future<TestHarness> _playing(
  WidgetTester tester, {
  RoomView? view,
  TestHarness? harness,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  _phone(tester, size: size);
  final h = harness ?? TestHarness();
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: h.scope(const PokerCreditsApp()),
    ),
  );
  await tester.pump();
  await tester.ensureVisible(find.text('PLAY ALONE'));
  await tester.tap(find.text('PLAY ALONE'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Dimath');
  await tester.ensureVisible(find.text('START GAME'));
  await tester.tap(find.text('START GAME'));
  await tester.pump();
  await tester.pump();
  h.network.last
    ..serverSends(snapshot(version: 1, serverTime: h.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: view ?? _view()))
    ..serverSends(holeCards('As', 'Kd', hand: (view ?? _view()).handNumber));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return h;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.pump();
  await tester.tap(find.text(label).first);
}

int _version = 1;
Future<void> _update(WidgetTester tester, TestHarness h, RoomView view) async {
  h.network.last.serverSends(StateUpdate(stateVersion: ++_version, view: view));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

const HandResult _iWon = HandResult(
  uncontested: false,
  pots: <PotResult>[
    PotResult(
      potIndex: 0,
      amount: 400,
      winnerPlayerIds: <String>['p_1'],
      shares: <Share>[Share(playerId: 'p_1', name: 'Dimath', amount: 400)],
    ),
  ],
);

final List<Reveal> _reveals = <Reveal>[
  Reveal(
    playerId: 'p_1',
    name: 'Dimath',
    cards: <PokerCard>[card('As'), card('Kd')],
    category: HandCategory.pair,
    bestFive: <PokerCard>[card('As'), card('Ad'), card('Kd'), card('9c'), card('4h')],
  ),
];

void main() {
  setUpAll(loadFonts);
  setUp(() => _version = 1);

  testWidgets('the solo table keeps the host-only and rebuy controls away and has pause and end', (tester) async {
    final h = await _playing(tester);
    expect(find.byType(SoloTablePage), findsOneWidget);
    for (final gone in <String>['TOP UP', 'SIT OUT', 'LEAVE', 'ROOM', 'CONNECTION']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.textContaining('MOVE'), findsNothing);
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('END GAME'), findsOneWidget);
    // Every other stack is in view.
    expect(find.text('1800'), findsOneWidget);
    expect(find.text('MAYA'), findsOneWidget);
    expect(h.host.soloStarted, 1);
    await _close(tester);
  });

  testWidgets('nothing at the table says the others are computer players', (tester) async {
    final semantics = tester.ensureSemantics();
    await _playing(tester);
    final bot = RegExp('bot|computer|\\bai\\b', caseSensitive: false);
    expect(find.textContaining(bot), findsNothing);
    expect(find.bySemanticsLabel(bot), findsNothing);
    semantics.dispose();
    await _close(tester);
  });

  testWidgets('the blinds and the countdown to the next rise come from the server', (tester) async {
    final h = await _playing(tester);
    expect(find.text('25/50'), findsOneWidget);
    expect(find.text('3 HANDS'), findsOneWidget);
    await _update(tester, h, _view(blinds: const BlindsView(smallBlind: 25, bigBlind: 50, nextSmallBlind: 40, nextBigBlind: 80, handsLeft: 1)));
    expect(find.text('1 HAND'), findsOneWidget);
    await _update(
      tester,
      h,
      _view(hand: 4, blinds: const BlindsView(smallBlind: 40, bigBlind: 80, nextSmallBlind: 60, nextBigBlind: 120, handsLeft: 3)),
    );
    expect(find.text('40/80'), findsOneWidget);
    expect(find.text('3 HANDS'), findsOneWidget);
    await _update(tester, h, _view(hand: 40, blinds: const BlindsView(smallBlind: 1500, bigBlind: 3000)));
    expect(find.text('FINAL LEVEL'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a player going out is announced with the place, once, and old ones are not', (tester) async {
    final already = <Finish>[const Finish(playerId: 'p_9', name: 'Ava', place: 6)];
    final h = await _playing(tester, view: _view(finish: already));
    expect(find.textContaining('IS OUT'), findsNothing, reason: 'places from before the screen opened are not news');
    await _update(
      tester,
      h,
      _view(
        finish: <Finish>[
          ...already,
          const Finish(playerId: 'p_5', name: 'Maya', place: 5),
        ],
      ),
    );
    expect(find.text('> MAYA IS OUT (5TH)'), findsOneWidget);
    // The same list again announces nothing new and does not duplicate the line.
    await _update(
      tester,
      h,
      _view(
        finish: <Finish>[
          ...already,
          const Finish(playerId: 'p_5', name: 'Maya', place: 5),
        ],
      ),
    );
    expect(find.text('> MAYA IS OUT (5TH)'), findsOneWidget);
    // The line is gone two hands later.
    await _update(
      tester,
      h,
      _view(
        hand: 6,
        finish: <Finish>[
          ...already,
          const Finish(playerId: 'p_5', name: 'Maya', place: 5),
        ],
      ),
    );
    expect(find.textContaining('IS OUT'), findsNothing);
    await _close(tester);
  });

  testWidgets('two players left is announced as heads-up', (tester) async {
    final h = await _playing(tester);
    expect(find.text('> HEADS-UP'), findsNothing);
    await _update(
      tester,
      h,
      _view(seats: <SeatView>[seatView(0, 'Maya', chips: 2000, hasCards: true), seatView(1, 'Dimath', chips: 4000, hasCards: true)]),
    );
    expect(find.text('> HEADS-UP'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('pause and resume are one button that follows the game', (tester) async {
    final h = await _playing(tester);
    await _tap(tester, 'PAUSE');
    await tester.pump();
    expect(h.network.last.sent.whereType<Pause>(), hasLength(1));
    await _update(tester, h, _view(paused: true));
    expect(find.text('RESUME'), findsOneWidget);
    await _tap(tester, 'RESUME');
    await tester.pump();
    expect(h.network.last.sent.whereType<ResumeGame>(), hasLength(1));
    await _close(tester);
  });

  testWidgets('back asks first and a saved game is offered again on Home', (tester) async {
    final h = await _playing(tester);
    await tester.tap(find.byType(BackCell).first);
    await tester.pumpAndSettle();
    expect(find.text('LEAVE THE GAME?'), findsOneWidget);
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(find.byType(SoloTablePage), findsOneWidget);

    await tester.tap(find.byType(BackCell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE AND EXIT'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect((await h.tokens.read(slot: TokenSlot.solo))?.roomCode, 'SOLO');
    expect(find.text('RESUME SOLO GAME'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('end game forgets the game after asking', (tester) async {
    final h = await _playing(tester);
    await _tap(tester, 'END GAME');
    await tester.pumpAndSettle();
    expect(find.text('END THIS GAME?'), findsOneWidget);
    await tester.tap(find.text('END GAME').last);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(await h.tokens.read(slot: TokenSlot.solo), isNull);
    expect(find.text('RESUME SOLO GAME'), findsNothing);
    await _close(tester);
  });

  group('the end of a game', () {
    const out = <Finish>[
      Finish(playerId: 'p_2', name: 'Liam', place: 5),
      Finish(playerId: 'p_3', name: 'Zoe', place: 4),
      Finish(playerId: 'p_1', name: 'Dimath', place: 3),
    ];

    testWidgets('going out shows See result, and the result shows the place, the stats and two ways on', (tester) async {
      final h = await _playing(tester);
      await _update(
        tester,
        h,
        _view(
          active: null,
          finish: out,
          seats: <SeatView>[seatView(0, 'Maya', chips: 4000), seatView(1, 'Dimath', chips: 0)],
          result: _iWon,
          reveals: _reveals,
        ),
      );
      expect(find.text('YOU ARE OUT'), findsOneWidget);
      expect(find.text('PAUSE'), findsNothing);
      expect(find.text('SEE RESULT'), findsOneWidget);

      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      expect(find.byType(SoloResultPage), findsOneWidget);
      expect(find.text('3RD'), findsOneWidget);
      expect(find.text('OF 3'), findsOneWidget);
      expect(find.text('HANDS PLAYED'), findsOneWidget);
      expect(find.text('BEST HAND'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('HOME'), findsWidgets);
      expect(find.text('THE HAND THAT DECIDED IT'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('the record is updated once, however many times the room view is sent again, and the saved game is let go', (tester) async {
      final h = await _playing(tester);
      final over = _view(active: null, finish: out, seats: <SeatView>[seatView(0, 'Maya', chips: 4000), seatView(1, 'Dimath', chips: 0)]);
      await _update(tester, h, over);
      await _update(tester, h, over.copyWith(totalPot: 1));
      await _update(tester, h, over.copyWith(totalPot: 2));
      final record = h.settings.value.recordFor(4, BotSkill.normal);
      expect((record?.played, record?.wins, record?.bestPlace), (1, 0, 3));
      expect(await h.tokens.read(slot: TokenSlot.solo), isNull, reason: 'a finished game cannot be resumed or counted again');
      await _close(tester);
    });

    testWidgets('a win says so and counts as a win', (tester) async {
      final h = await _playing(tester);
      await _update(
        tester,
        h,
        _view(
          active: null,
          finish: <Finish>[
            ...out.take(2),
            const Finish(playerId: 'p_1', name: 'Dimath', place: 1),
          ],
          seats: <SeatView>[seatView(1, 'Dimath', chips: 6000)],
          result: _iWon,
          reveals: _reveals,
        ),
      );
      expect(find.text('YOU WON'), findsOneWidget);
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      expect(find.text('1ST'), findsOneWidget);
      expect(find.text('YOU WON'), findsOneWidget);
      final record = h.settings.value.recordFor(4, BotSkill.normal);
      expect((record?.played, record?.wins, record?.bestPlace), (1, 1, 1));
      await _close(tester);
    });

    testWidgets('the stats count the hands the server paid, once each', (tester) async {
      final h = await _playing(tester);
      await _update(tester, h, _view(hand: 3, result: _iWon, reveals: _reveals));
      await _update(tester, h, _view(hand: 3, result: _iWon, reveals: _reveals).copyWith(totalPot: 5));
      await _update(tester, h, _view(hand: 4));
      await _update(tester, h, _view(hand: 5, result: _iWon, reveals: _reveals));
      await _update(
        tester,
        h,
        _view(active: null, hand: 6, finish: out, seats: <SeatView>[seatView(1, 'Dimath', chips: 0)]),
      );
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      // Two paid hands, both won, 400 the most, a pair the best hand shown.
      expect(find.text('HANDS PLAYED'), findsOneWidget);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(texts, containsAll(<String>['2', '400', 'PAIR']));
      await _close(tester);
    });

    testWidgets('play again starts the same kind of game and Home leaves', (tester) async {
      final h = await _playing(tester);
      await _update(tester, h, _view(active: null, finish: out, seats: <SeatView>[seatView(1, 'Dimath', chips: 0)]));
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      final first = h.host.lastSolo!;
      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(h.host.soloStarted, 2);
      final again = h.host.lastSolo!;
      expect((again.bots, again.skill, again.ladderHands), (first.bots, first.skill, first.ladderHands));
      expect(find.byType(SoloTablePage), findsOneWidget);
      expect((await h.tokens.read(slot: TokenSlot.solo))?.roomCode, 'SOLO');
      await _close(tester);
    });

    testWidgets('Home leaves for good', (tester) async {
      final h = await _playing(tester);
      await _update(tester, h, _view(active: null, finish: out, seats: <SeatView>[seatView(1, 'Dimath', chips: 0)]));
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOME').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(h.host.stopped, greaterThan(0));
      expect(find.text('RESUME SOLO GAME'), findsNothing);
      await _close(tester);
    });
  });

  group('layout', () {
    const sizes = <String, Size>{
      'small phone': Size(320, 568),
      'phone': Size(390, 844),
      'phone landscape': Size(844, 390),
      'tablet': Size(1280, 800),
    };
    const out = <Finish>[
      Finish(playerId: 'p_2', name: 'Liam', place: 5),
      Finish(playerId: 'p_3', name: 'Zoe', place: 4),
      Finish(playerId: 'p_1', name: 'Dimath', place: 3),
    ];
    const turn = TurnPrompt(
      playerId: 'p_1',
      seatIndex: 1,
      nextActionSeq: 4,
      legal: LegalActions(canFold: true, canCheck: false, canCall: true, callAmount: 50, canRaise: true, minRaiseTo: 100, maxRaiseTo: 1500),
    );

    for (final scale in <double>[1.0, 2.0, 3.0]) {
      for (final entry in sizes.entries) {
        final where = '${entry.key}, text x$scale';

        testWidgets('the solo table on my turn with nine opponents holds ($where)', (tester) async {
          final h = await _playing(
            tester,
            view: _view(active: 1, seats: _seats(others: 9)),
            size: entry.value,
            scale: scale,
          );
          h.network.last.serverSends(turn);
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _close(tester);
        });

        testWidgets('the result page holds ($where)', (tester) async {
          final h = await _playing(tester, size: entry.value, scale: scale);
          await _update(
            tester,
            h,
            _view(
              active: null,
              finish: out,
              seats: <SeatView>[seatView(0, 'Maya', chips: 4000), seatView(1, 'Dimath', chips: 0)],
              result: _iWon,
              reveals: _reveals,
            ),
          );
          await _tap(tester, 'SEE RESULT');
          await tester.pumpAndSettle();
          expect(find.byType(SoloResultPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('PLAY AGAIN'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _close(tester);
        });
      }
    }
  });

  group('goldens', () {
    for (final dark in <bool>[false, true]) {
      final mode = dark ? 'dark' : 'light';

      testWidgets('solo table with five opponents, $mode', (tester) async {
        final view = _view(
          active: 2,
          seats: <SeatView>[
            seatView(0, 'Maya', chips: 1800, hasCards: true),
            seatView(1, 'Dimath', chips: 1450, bet: 50, hasCards: true),
            seatView(2, 'Liam', chips: 1250, hasCards: true),
            seatView(3, 'Zoe', chips: 900, folded: true),
            seatView(4, 'Noor', chips: 2100, hasCards: true),
            seatView(5, 'Eli', chips: 600, allIn: true, hasCards: true),
          ],
        ).copyWith(board: <PokerCard>[card('9c'), card('Td'), card('2h')], currentHighBet: 50, minRaiseTo: 100);
        await _playing(tester, view: view, dark: dark);
        await tester.pump(const Duration(seconds: 2)); // the cards finish turning over
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/solo_table_five_phone_$mode.png'));
        await _close(tester);
      });
    }

    testWidgets('solo result, out', (tester) async {
      final h = await _playing(tester);
      await _update(
        tester,
        h,
        _view(
          active: null,
          finish: const <Finish>[
            Finish(playerId: 'p_2', name: 'Liam', place: 5),
            Finish(playerId: 'p_3', name: 'Zoe', place: 4),
            Finish(playerId: 'p_1', name: 'Dimath', place: 3),
          ],
          seats: <SeatView>[seatView(0, 'Maya', chips: 4000), seatView(1, 'Dimath', chips: 0)],
          result: _iWon,
          reveals: _reveals,
        ),
      );
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/solo_result_out.png'));
      await _close(tester);
    });

    testWidgets('solo result, won', (tester) async {
      final h = await _playing(tester);
      await _update(
        tester,
        h,
        _view(
          active: null,
          finish: const <Finish>[
            Finish(playerId: 'p_2', name: 'Liam', place: 3),
            Finish(playerId: 'p_3', name: 'Zoe', place: 2),
            Finish(playerId: 'p_1', name: 'Dimath', place: 1),
          ],
          seats: <SeatView>[seatView(1, 'Dimath', chips: 6000)],
          result: _iWon,
          reveals: _reveals,
        ),
      );
      await _tap(tester, 'SEE RESULT');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/solo_result_won.png'));
      await _close(tester);
    });
  });
}
