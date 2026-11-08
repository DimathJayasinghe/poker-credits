import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/pages/solo_result_page.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_credits/widget/player/opponent_strip.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';
import '../support/no_scroll.dart';
import '../support/store_shot.dart';

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
  EdgeInsets insets = EdgeInsets.zero,
}) async {
  _phone(tester, size: size);
  final h = harness ?? TestHarness();
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale), padding: insets, viewPadding: insets),
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

  testWidgets('a paused game says it is paused, also when it is my turn, and does not wait for anyone', (tester) async {
    final h = await _playing(tester);
    // Dimath is at seat 1: coming back from the background leaves the game paused on my turn.
    await _update(tester, h, _view(active: 1, paused: true));
    expect(find.textContaining('WAITING FOR'), findsNothing);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('RESUME'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a hand everyone folded to still shows what was won, with no hands to list', (tester) async {
    final h = await _playing(tester);
    await _update(
      tester,
      h,
      _view(
        active: null,
        result: const HandResult(
          uncontested: true,
          pots: <PotResult>[
            PotResult(
              potIndex: 0,
              amount: 30,
              winnerPlayerIds: <String>['p_1'],
              shares: <Share>[Share(playerId: 'p_1', name: 'Dimath', amount: 30)],
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Everyone else folded'), findsOneWidget);
    expect(find.text('Dimath +30'), findsOneWidget);
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
      expect(find.text('OF 5'), findsOneWidget, reason: 'the first to go out took 5th place: five started');
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

  // A game's controls must be on screen without scrolling: the buttons, my cards and the pause
  // row are budgeted for even while I am only waiting, so nothing jumps when my turn starts.
  group('everything I need fits without scrolling', () {
    // Logical sizes of phones people really own, with the status bar and the bottom bar (or the
    // home indicator) taken off by the system: (width, height, top, bottom). `min` is the text
    // scale up to which nothing may scroll; a screen too short for more is allowed to scroll as a whole.
    const devices = <(String, double, double, double, double, double)>[
      // Phones held on their side: the system bars sit on the sides, so only the bottom one counts.
      ('iPhone 14 landscape 844x390', 844, 390, 0, 21, 1.0),
      ('iPhone SE landscape 667x375', 667, 375, 0, 0, 1.0),
      ('Android landscape 800x360', 800, 360, 24, 0, 1.0),
      ('Pixel landscape 915x412', 915, 412, 24, 16, 1.3),
      // Android: three-button and gesture navigation.
      ('Android budget 360x640', 360, 640, 24, 48, 1.0),
      ('Android 360x720', 360, 720, 24, 48, 1.0),
      ('Android 360x800 buttons', 360, 800, 28, 48, 1.3),
      ('Android 360x800 gestures', 360, 800, 28, 16, 1.3),
      ('Galaxy S24 384x832', 384, 832, 32, 24, 1.3),
      ('Android 393x851', 393, 851, 28, 24, 1.3),
      ('Pixel 412x915', 412, 915, 36, 24, 1.3),
      ('Pixel 412x915 buttons', 412, 915, 36, 48, 1.3),
      // Apple.
      ('iPhone SE 375x667', 375, 667, 20, 0, 1.0),
      ('iPhone 8 Plus 414x736', 414, 736, 20, 0, 1.0),
      ('iPhone 13 mini 375x812', 375, 812, 50, 34, 1.3),
      ('iPhone 14 390x844', 390, 844, 47, 34, 1.3),
      ('iPhone 15 Pro 393x852', 393, 852, 59, 34, 1.3),
      ('iPhone 16 Pro 402x874', 402, 874, 62, 34, 1.3),
      ('iPhone 15 Plus 428x926', 428, 926, 47, 34, 1.3),
      ('iPhone 16 Pro Max 440x956', 440, 956, 62, 34, 1.3),
      // Bigger screens and a desktop window.
      ('iPad mini 744x1133', 744, 1133, 24, 20, 1.3),
      ('iPad landscape 1180x820', 1180, 820, 24, 20, 1.3),
      ('narrow desktop window 368x690', 368, 690, 0, 0, 1.0),
      ('desktop 1280x800', 1280, 800, 0, 0, 1.3),
    ];
    const turn = TurnPrompt(
      playerId: 'p_1',
      seatIndex: 1,
      nextActionSeq: 4,
      legal: LegalActions(canFold: true, canCheck: false, canCall: true, callAmount: 80, canRaise: true, minRaiseTo: 160, maxRaiseTo: 930),
    );
    final board = <PokerCard>[card('9c'), card('Td'), card('2h')];

    Rect rectOf(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(BrutalButton)).first);

    void insideScreen(Rect rect, Size size, EdgeInsets insets, String what) {
      expect(rect.top, greaterThanOrEqualTo(insets.top - 0.5), reason: '$what starts under the status bar');
      expect(
        rect.bottom,
        lessThanOrEqualTo(size.height - insets.bottom + 0.5),
        reason: '$what runs off the bottom (${rect.bottom} of ${size.height - insets.bottom})',
      );
    }

    for (final d in devices) {
      for (final scale in <double>[1.0, 1.3]) {
        for (final myTurn in <bool>[true, false]) {
          testWidgets('${d.$1}, text x$scale, ${myTurn ? 'my turn' : 'waiting'}', (tester) async {
            final size = Size(d.$2, d.$3);
            final insets = EdgeInsets.only(top: d.$4, bottom: d.$5);
            final view = _view(active: myTurn ? 1 : 2, seats: _seats(others: 5)).copyWith(board: board, currentHighBet: 80);
            final h = await _playing(tester, view: view, size: size, scale: scale, insets: insets);
            if (myTurn) h.network.last.serverSends(turn);
            h.network.last.serverSends(
              const ActionPerformed(
                playerId: 'p_3',
                playerName: 'Zoe',
                kind: ActionKind.fold,
                amount: 0,
                chipsRemaining: 900,
                allIn: false,
                auto: false,
              ),
            );
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(seconds: 3));
            expect(tester.takeException(), isNull, reason: 'no overflow at all');
            expect(find.byType(Scrollable), findsNothing, reason: 'a game does not scroll');
            // The middle of the screen may shrink to fit, but never into something unreadable.
            expect(tester.getRect(find.byType(BoardView)).width, greaterThan(274 * 0.65), reason: 'the board stays readable');
            if (scale <= d.$6) {
              if (myTurn) {
                for (final label in <String>['RAISE', 'FOLD', 'CALL 80']) {
                  insideScreen(rectOf(tester, label), size, insets, label);
                }
              }
              insideScreen(rectOf(tester, 'PAUSE'), size, insets, 'PAUSE');
              insideScreen(rectOf(tester, 'END GAME'), size, insets, 'END GAME');
              insideScreen(tester.getRect(find.byType(HoleCardsDock)), size, insets, 'my cards');
            }
            await _close(tester);
          });
        }
      }
    }

    // The biggest table (nine opponents) and a showdown with many hands: all of it still on screen.
    const crowded = <(String, double, double, double, double)>[
      ('Android budget 360x640', 360, 640, 24, 48),
      ('iPhone SE 375x667', 375, 667, 20, 0),
      ('iPhone 14 390x844', 390, 844, 47, 34),
      ('Pixel 412x915', 412, 915, 36, 24),
      ('Android landscape 800x360', 800, 360, 24, 0),
    ];
    for (final d in crowded) {
      testWidgets('${d.$1}: nine opponents and a showdown fit', (tester) async {
        final size = Size(d.$2, d.$3);
        final insets = EdgeInsets.only(top: d.$4, bottom: d.$5);
        final seats = _seats(others: 9);
        final reveals = <Reveal>[
          for (var i = 0; i < 6; i++)
            Reveal(
              playerId: 'p_$i',
              name: seats[i].name,
              cards: <PokerCard>[card('As'), card('Kd')],
              category: HandCategory.pair,
              bestFive: <PokerCard>[card('As'), card('Ad'), card('Kd'), card('9c'), card('4h')],
            ),
        ];
        final view = _view(active: null, seats: seats, result: _iWon, reveals: reveals).copyWith(
          board: <PokerCard>[card('9c'), card('Td'), card('2h'), card('Jc'), card('3s')],
        );
        await _playing(tester, view: view, size: size, insets: insets);
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        final limit = size.height - insets.bottom + 0.5;
        for (final label in <String>['PAUSE', 'END GAME']) {
          expect(rectOf(tester, label).bottom, lessThanOrEqualTo(limit), reason: '$label runs off the bottom');
        }
        expect(tester.getRect(find.byType(HoleCardsDock)).bottom, lessThanOrEqualTo(limit));
        final strip = tester.getRect(find.byType(OpponentStrip));
        expect(strip.right, lessThanOrEqualTo(size.width + 0.5), reason: 'the opponents do not run off the side');
        final panel = tester.getRect(find.byType(ShowdownPanel));
        expect(panel.top, greaterThanOrEqualTo(insets.top));
        expect(panel.bottom, lessThanOrEqualTo(limit), reason: 'the showdown is fully on screen');
        await _close(tester);
      });
    }

    // The end-of-game page: the place, the numbers, the deciding hand and the two ways on.
    const out = <Finish>[
      Finish(playerId: 'p_2', name: 'Liam', place: 5),
      Finish(playerId: 'p_3', name: 'Zoe', place: 4),
      Finish(playerId: 'p_1', name: 'Dimath', place: 3),
    ];
    for (final d in devices) {
      for (final scale in <double>[1.0, 1.3]) {
        for (final hands in <int>[2, 6]) {
          testWidgets('${d.$1}, text x$scale: the result page with $hands hands does not scroll', (tester) async {
            final size = Size(d.$2, d.$3);
            final insets = EdgeInsets.only(top: d.$4, bottom: d.$5);
            final h = await _playing(tester, size: size, scale: scale, insets: insets);
            final seats = _seats(others: 6);
            final reveals = <Reveal>[
              for (var i = 0; i < hands; i++)
                Reveal(
                  playerId: 'p_$i',
                  name: seats[i].name,
                  cards: <PokerCard>[card('As'), card('Kd')],
                  category: HandCategory.pair,
                  bestFive: <PokerCard>[card('As'), card('Ad'), card('Kd'), card('9c'), card('4h')],
                ),
            ];
            await _update(
              tester,
              h,
              _view(active: null, finish: out, seats: seats, result: _iWon, reveals: reveals).copyWith(
                board: <PokerCard>[card('9c'), card('Td'), card('2h'), card('Jc'), card('3s')],
              ),
            );
            await _tap(tester, 'SEE RESULT');
            await tester.pumpAndSettle();
            expect(find.byType(SoloResultPage), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'no overflow');
            expect(extentAround(tester, find.text('HANDS PLAYED')), lessThan(0.5), reason: 'the result page does not scroll');
            final limit = size.height - insets.bottom + 0.5;
            for (final label in <String>['PLAY AGAIN', 'HOME']) {
              expect(rectOf(tester, label).bottom, lessThanOrEqualTo(limit), reason: '$label runs off the bottom');
            }
            await _close(tester);
          });
        }
      }
    }

    testWidgets('the buttons do not move when my turn starts', (tester) async {
      const size = Size(390, 844);
      const insets = EdgeInsets.only(top: 47, bottom: 34);
      final view = _view(active: 2, seats: _seats(others: 5)).copyWith(board: board, currentHighBet: 80);
      final h = await _playing(tester, view: view, size: size, insets: insets);
      await tester.pump(const Duration(seconds: 2));
      final pauseWaiting = rectOf(tester, 'PAUSE');
      final cardsWaiting = tester.getRect(find.byType(HoleCardsDock));
      await _update(tester, h, _view(active: 1, seats: _seats(others: 5)).copyWith(board: board, currentHighBet: 80));
      h.network.last.serverSends(turn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(rectOf(tester, 'PAUSE'), pauseWaiting, reason: 'the pause row stays put');
      expect(tester.getRect(find.byType(HoleCardsDock)), cardsWaiting, reason: 'my cards stay put');
      await _close(tester);
    });
  });

  // The table picture of the Microsoft Store listing (docs/MICROSOFT_STORE.md); skipped in normal runs.
  testWidgets('store screenshot, solo table', (tester) async {
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
    await _playing(tester, view: view, size: storeShotSize);
    await tester.pump(const Duration(seconds: 2));
    await saveStoreShot(tester, 'windows-table');
  }, skip: storeShotsDir == null);

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
