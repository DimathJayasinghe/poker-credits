import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/table/action_ticker.dart';
import 'package:poker_credits/widget/table/pot_results.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// Seat 0 is the host (`p_host`, what the fake server returns), so it can be seated at the table.
List<SeatView> _seats() => <SeatView>[
  seatView(0, 'Dimath', chips: 940, hasCards: true).copyWith(playerId: 'p_host'),
  seatView(1, 'Alice', chips: 1200, hasCards: true),
  seatView(2, 'Bob', chips: 300, folded: true),
  seatView(3, 'Cara', chips: 610, hasCards: true),
];

final List<PokerCard> _board = <PokerCard>[card('Kd'), card('9c'), card('6c')];

RoomView _hand({WirePhase phase = WirePhase.flop, List<PokerCard>? board, List<Reveal> reveals = const <Reveal>[], HandResult? result}) => roomView(
  hand: 5,
  activeSeat: 1,
  pot: 120,
  seats: _seats(),
  deadline: 1730000021000,
  phase: phase,
  board: board ?? _board,
  reveals: reveals,
  result: result,
);

Future<TestHarness> _openHostTable(
  WidgetTester tester,
  RoomView view, {
  Size size = const Size(1280, 800),
  bool deal = true,
  TestHarness? harness,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = harness ?? TestHarness();
  await tester.pumpWidget(h.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.ensureVisible(find.text('HOST A GAME'));
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Dimath');
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  h.network.last.serverSends(snapshot(version: 1, serverTime: h.clock.millisecondsSinceEpoch, view: view));
  if (deal) h.network.last.serverSends(holeCards('As', 'Kh', hand: view.handNumber));
  await tester.pump();
  await tester.pump();
  return h;
}

List<PokerCard?> _dock(WidgetTester tester) =>
    tester.widgetList<PlayingCard>(find.descendant(of: find.byType(HoleCardsDock), matching: find.byType(PlayingCard))).map((p) => p.card).toList();

Finder _plateOf(String name) => find.ancestor(of: find.text(name.toUpperCase()), matching: find.byType(SeatPlate)).first;

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadFonts);

  testWidgets('seat plates show two backs for players still in the hand and nothing for a folded one', (tester) async {
    await _openHostTable(tester, _hand());
    int cards(String name) => find.descendant(of: _plateOf(name), matching: find.byType(PlayingCard)).evaluate().length;
    expect(cards('Alice'), 2);
    expect(cards('Cara'), 2);
    expect(cards('Bob'), 0, reason: 'folded');
    expect(
      tester.widgetList<PlayingCard>(find.descendant(of: _plateOf('Alice'), matching: find.byType(PlayingCard))).every((p) => p.card == null),
      isTrue,
    );
    await _close(tester);
  });

  testWidgets('the community cards sit on the felt', (tester) async {
    await _openHostTable(tester, _hand());
    expect(find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)), findsNWidgets(3));
    await _close(tester);
  });

  testWidgets('a room with real cards shows no cards, no board and no virtual controls note', (tester) async {
    await _openHostTable(
      tester,
      roomView(hand: 5, activeSeat: 1, pot: 120, seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice')], deadline: 1730000021000),
      deal: false,
    );
    expect(find.byType(PlayingCard), findsNothing);
    expect(find.byType(BoardView), findsNothing);
    expect(find.text(Strings.undoVirtualNote), findsNothing);
    await _close(tester);
  });

  testWidgets('at showdown every contender\'s cards turn up on their plate and the winner is marked', (tester) async {
    const reveals = <Reveal>[
      Reveal(
        playerId: 'p_1',
        name: 'Alice',
        cards: <PokerCard>[PokerCard(CardRank.king, CardSuit.hearts), PokerCard(CardRank.king, CardSuit.clubs)],
        category: HandCategory.threeOfAKind,
        bestFive: <PokerCard>[
          PokerCard(CardRank.king, CardSuit.hearts),
          PokerCard(CardRank.king, CardSuit.clubs),
          PokerCard(CardRank.king, CardSuit.diamonds),
          PokerCard(CardRank.nine, CardSuit.clubs),
          PokerCard(CardRank.six, CardSuit.clubs),
        ],
      ),
      Reveal(
        playerId: 'p_3',
        name: 'Cara',
        cards: <PokerCard>[PokerCard(CardRank.ace, CardSuit.spades), PokerCard(CardRank.two, CardSuit.hearts)],
        category: HandCategory.highCard,
        bestFive: <PokerCard>[
          PokerCard(CardRank.ace, CardSuit.spades),
          PokerCard(CardRank.king, CardSuit.diamonds),
          PokerCard(CardRank.nine, CardSuit.clubs),
          PokerCard(CardRank.six, CardSuit.clubs),
          PokerCard(CardRank.two, CardSuit.hearts),
        ],
      ),
    ];
    const result = HandResult(
      uncontested: false,
      pots: <PotResult>[
        PotResult(
          potIndex: 0,
          amount: 120,
          winnerPlayerIds: <String>['p_1'],
          shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 120)],
        ),
      ],
    );
    await _openHostTable(
      tester,
      _hand(phase: WirePhase.showdown, board: <PokerCard>[..._board, card('2c'), card('Js')], reveals: reveals, result: result),
      deal: false,
    );

    final alice = tester
        .widgetList<PlayingCard>(find.descendant(of: _plateOf('Alice'), matching: find.byType(PlayingCard)))
        .map((p) => p.card)
        .toList();
    expect(alice, <PokerCard?>[card('Kh'), card('Kc')]);
    final cara = tester
        .widgetList<PlayingCard>(find.descendant(of: _plateOf('Cara'), matching: find.byType(PlayingCard)))
        .map((p) => p.card)
        .toList();
    expect(cara, <PokerCard?>[card('As'), card('2h')]);
    expect(find.descendant(of: _plateOf('Alice'), matching: find.text(Strings.winsTag.toUpperCase())), findsOneWidget);
    expect(find.descendant(of: _plateOf('Cara'), matching: find.text(Strings.winsTag.toUpperCase())), findsNothing);
    expect(find.descendant(of: find.byType(PotResults), matching: find.text('MAIN POT 120: ALICE +120')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('an all-in run-out is dealt street by street, and the result and START HAND wait for the last card', (tester) async {
    final harness = await _openHostTable(tester, _hand(phase: WirePhase.allInRunout), deal: false);
    int boardCards() => find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)).evaluate().length;
    expect(boardCards(), 3);

    const result = HandResult(
      uncontested: false,
      pots: <PotResult>[
        PotResult(
          potIndex: 0,
          amount: 120,
          winnerPlayerIds: <String>['p_1'],
          shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 120)],
        ),
      ],
    );
    const reveals = <Reveal>[
      Reveal(
        playerId: 'p_1',
        name: 'Alice',
        cards: <PokerCard>[PokerCard(CardRank.king, CardSuit.hearts), PokerCard(CardRank.king, CardSuit.clubs)],
        category: HandCategory.threeOfAKind,
        bestFive: <PokerCard>[],
      ),
      Reveal(
        playerId: 'p_3',
        name: 'Cara',
        cards: <PokerCard>[PokerCard(CardRank.ace, CardSuit.spades), PokerCard(CardRank.two, CardSuit.hearts)],
        category: HandCategory.highCard,
        bestFive: <PokerCard>[],
      ),
    ];
    harness.network.last.serverSends(
      StateUpdate(
        stateVersion: 2,
        view: _hand(phase: WirePhase.showdown, board: <PokerCard>[..._board, card('Jh'), card('2c')], reveals: reveals, result: result).copyWith(
          totalPot: 0,
          seats: <SeatView>[for (final seat in _seats()) seat.playerId == 'p_1' ? seat.copyWith(chips: 1320) : seat],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(boardCards(), 4, reason: 'the turn at once');
    expect(find.byType(PotResults), findsNothing, reason: 'no spoiler before the river');
    expect(findNumber(120), findsOneWidget, reason: 'the pot is still on the table');
    expect(findNumber(1320), findsNothing, reason: 'the winner\'s new stack is not shown yet');
    expect(findNumber(1200), findsOneWidget, reason: 'Alice still has her old stack');
    expect(find.descendant(of: _plateOf('Alice'), matching: find.text(Strings.winsTag.toUpperCase())), findsNothing);
    expect(
      find.descendant(of: _plateOf('Alice'), matching: find.byType(PlayingCard)).evaluate().every((e) => (e.widget as PlayingCard).card == null),
      isTrue,
    );

    harness.clock = harness.clock.add(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    expect(boardCards(), 5);
    expect(findNumber(1320), findsOneWidget, reason: 'paid once the last card is down');
    expect(find.byType(PotResults), findsOneWidget);
    expect(find.descendant(of: _plateOf('Alice'), matching: find.text(Strings.winsTag.toUpperCase())), findsOneWidget);
    await _close(tester);
  });

  testWidgets('START HAND is held while the run-out is still being dealt', (tester) async {
    final harness = await _openHostTable(tester, _hand(phase: WirePhase.allInRunout), deal: false);
    harness.network.last.serverSends(
      StateUpdate(
        stateVersion: 2,
        view: _hand(phase: WirePhase.nextHandPrep, board: <PokerCard>[..._board, card('Jh'), card('2c')]),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('START HAND'), warnIfMissed: false);
    await tester.pump();
    expect(harness.network.last.sent.whereType<StartHand>(), isEmpty, reason: 'the river is not down yet');
    harness.clock = harness.clock.add(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('START HAND'));
    await tester.pump();
    expect(harness.network.last.sent.whereType<StartHand>(), hasLength(1));
    await _close(tester);
  });

  testWidgets('a virtual room has no begin-showdown or pick-winners button: the server does both', (tester) async {
    await _openHostTable(tester, _hand(phase: WirePhase.allInRunout));
    expect(find.text('BEGIN SHOWDOWN'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _openHostTable(tester, _hand(phase: WirePhase.showdown), harness: TestHarness());
    expect(find.text('PICK WINNERS'), findsNothing);
    await _close(tester);
  });

  testWidgets('the host is told what undo can do in a virtual room', (tester) async {
    await _openHostTable(tester, _hand());
    expect(find.text(Strings.undoVirtualNote), findsOneWidget);
    await _close(tester);
  });

  // Every height from a short window up to a tall tablet: the host's note and buttons are whole
  // and above the action ticker. The table never scrolls, so there is no scrolled-to-the-end state.
  for (final width in <double>[1280, 390]) {
    for (final scale in <double>[1, 2]) {
      testWidgets('the host controls and their undo note are never cut off by the action ticker (width $width, text x$scale)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final bad = <String>[];
        for (var height = 560.0; height <= 1100; height += 40) {
          await _openHostTable(tester, _hand(), size: Size(width, height));
          expect(tester.takeException(), isNull, reason: 'no overflow at $width x $height');
          final ticker = tester.getRect(find.byType(ActionTicker));
          // The note is in full where the table is tall, in one short line where it is not.
          final note = find.byWidgetPredicate((w) => w is Text && (w.data == Strings.undoVirtualNote || w.data == Strings.undoVirtualShort));
          for (final finder in <Finder>[note, find.text('END GAME')]) {
            final rect = tester.getRect(finder);
            if (rect.bottom > ticker.top + 0.5) bad.add('$height: ${rect.bottom} runs under the ticker at ${ticker.top}');
          }
          await _close(tester);
        }
        expect(bad, isEmpty);
      });
    }
  }

  group('the seated host\'s own cards', () {
    testWidgets('on a shared screen they show only while held', (tester) async {
      await _openHostTable(tester, _hand());
      expect(find.byType(HoleCardsDock), findsOneWidget);
      expect(_dock(tester), <PokerCard?>[null, null]);
      await tester.tap(find.byType(HoleCardsDock));
      await tester.pumpAndSettle();
      expect(_dock(tester), <PokerCard?>[null, null], reason: 'a tap must not leave cards open in front of everybody');
      final hold = await tester.startGesture(tester.getCenter(find.byType(HoleCardsDock)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_dock(tester), <PokerCard?>[card('As'), card('Kh')]);
      await hold.up();
      await tester.pumpAndSettle();
      expect(_dock(tester), <PokerCard?>[null, null]);
      await _close(tester);
    });

    testWidgets('on a phone a tap turns them over', (tester) async {
      await _openHostTable(tester, _hand(), size: const Size(390, 844));
      await tester.ensureVisible(find.byType(HoleCardsDock));
      await tester.tap(find.byType(HoleCardsDock));
      await tester.pumpAndSettle();
      expect(_dock(tester), <PokerCard?>[card('As'), card('Kh')]);
      await _close(tester);
    });

    testWidgets('leaving the app turns them back over', (tester) async {
      await _openHostTable(tester, _hand(), size: const Size(390, 844));
      await tester.ensureVisible(find.byType(HoleCardsDock));
      await tester.tap(find.byType(HoleCardsDock));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(_dock(tester), <PokerCard?>[null, null]);
      await _close(tester);
    });
  });

  testWidgets('a spectator sees backs on the plates and the board but no dock', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.tap(find.text('JOIN A GAME'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'kq7m');
    await tester.enterText(find.byType(TextField).at(1), 'Wanda');
    await tester.ensureVisible(find.text('WATCH ONLY'));
    await tester.tap(find.text('WATCH ONLY'));
    await tester.pump();
    await tester.pump();
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_w', role: Role.spectator, sessionToken: 'watch-token'))
      ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: _hand()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TablePage), findsOneWidget);
    expect(find.byType(HoleCardsDock), findsNothing);
    expect(find.descendant(of: _plateOf('Alice'), matching: find.byType(PlayingCard)), findsNWidgets(2));
    expect(find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)), findsNWidgets(3));
    await _close(tester);
  });
}
