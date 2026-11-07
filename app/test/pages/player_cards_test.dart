import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_credits/widget/player/opponent_strip.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

/// The Player screen in a virtual-card room: me as Alice (p_1, seat 1).
List<SeatView> _seats({bool aliceFolded = false}) => <SeatView>[
  seatView(0, 'Dimath', hasCards: true),
  seatView(1, 'Alice', chips: 940, hasCards: !aliceFolded, folded: aliceFolded),
  seatView(2, 'Bob', chips: 1200, hasCards: true),
];

RoomView _hand({int hand = 3, List<PokerCard> board = const <PokerCard>[], bool aliceFolded = false}) => roomView(
  hand: hand,
  activeSeat: 2,
  pot: 60,
  seats: _seats(aliceFolded: aliceFolded),
  deadline: 1730000021000,
  board: board,
);

void _phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<TestHarness> _seated(WidgetTester tester, {RoomView? view, TestHarness? harness, Size size = const Size(390, 844)}) async {
  _phone(tester, size: size);
  final h = harness ?? TestHarness();
  await tester.pumpWidget(h.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'kq7m');
  await tester.enterText(find.byType(TextField).at(1), 'Alice');
  await tester.ensureVisible(find.text('JOIN'));
  await tester.tap(find.text('JOIN'));
  await tester.pump();
  await tester.pump();
  h.network.last
    ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
    ..serverSends(snapshot(version: 1, serverTime: h.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: view ?? _hand()))
    ..serverSends(holeCards('As', 'Kd', hand: (view ?? _hand()).handNumber));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return h;
}

List<PokerCard?> _dockCards(WidgetTester tester) =>
    tester.widgetList<PlayingCard>(find.descendant(of: find.byType(HoleCardsDock), matching: find.byType(PlayingCard))).map((p) => p.card).toList();

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadFonts);

  testWidgets('my cards arrive face down and a tap turns them over, and again hides them', (tester) async {
    await _seated(tester);
    expect(find.byType(HoleCardsDock), findsOneWidget);
    expect(_dockCards(tester), <PokerCard?>[null, null]);
    expect(find.bySemanticsLabel('Ace of spades'), findsNothing, reason: 'hidden cards are not read out');

    await tester.tap(find.byType(HoleCardsDock));
    await tester.pumpAndSettle();
    expect(_dockCards(tester), <PokerCard?>[card('As'), card('Kd')]);

    await tester.tap(find.byType(HoleCardsDock));
    await tester.pumpAndSettle();
    expect(_dockCards(tester), <PokerCard?>[null, null]);
    await _close(tester);
  });

  testWidgets('the next hand starts face down even if the last one was left open', (tester) async {
    final harness = await _seated(tester);
    await tester.tap(find.byType(HoleCardsDock));
    await tester.pumpAndSettle();
    expect(_dockCards(tester).first, isNotNull);

    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _hand(hand: 4)))
      ..serverSends(holeCards('2c', '7h', hand: 4));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_dockCards(tester), <PokerCard?>[null, null]);
    await _close(tester);
  });

  testWidgets('leaving the app turns the cards back over', (tester) async {
    await _seated(tester);
    await tester.tap(find.byType(HoleCardsDock));
    await tester.pumpAndSettle();
    expect(_dockCards(tester).first, isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(_dockCards(tester), <PokerCard?>[null, null]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_dockCards(tester), <PokerCard?>[null, null], reason: 'coming back does not reopen them');
    await _close(tester);
  });

  testWidgets('the setting "show my cards at once" deals face up, and still hides on a new hand per the setting', (tester) async {
    final harness = TestHarness();
    harness.settings.value = harness.settings.value.copyWith(cardsFaceUp: true);
    await _seated(tester, harness: harness);
    expect(_dockCards(tester), <PokerCard?>[card('As'), card('Kd')]);
    await _close(tester);
  });

  testWidgets('cards that have not arrived yet show as backs, not as "no cards"', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.tap(find.text('JOIN A GAME'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'kq7m');
    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump();
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 't'))
      ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: _hand()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HoleCardsDock), findsNothing);
    expect(find.text(Strings.noCards.toUpperCase()), findsNothing);
    expect(find.byType(PlayingCard), findsWidgets, reason: 'backs for me, backs for the others');
    await _close(tester);
  });

  testWidgets('after folding there is nothing to look at', (tester) async {
    await _seated(tester, view: _hand(aliceFolded: true));
    expect(find.text(Strings.noCards.toUpperCase()), findsOneWidget);
    expect(_dockCards(tester), isEmpty);
    await _close(tester);
  });

  testWidgets('the other players show two backs each, or nothing once they folded', (tester) async {
    await _seated(
      tester,
      view: roomView(
        hand: 3,
        activeSeat: 2,
        seats: <SeatView>[seatView(0, 'Dimath', hasCards: true), seatView(1, 'Alice', hasCards: true), seatView(2, 'Bob', folded: true)],
      ),
    );
    final strip = find.byType(OpponentStrip);
    expect(strip, findsOneWidget);
    expect(find.descendant(of: strip, matching: find.text('DIMATH')), findsOneWidget);
    expect(
      find.descendant(of: strip, matching: find.text('ALICE')),
      findsNothing,
      reason: 'that is me',
    );
    expect(find.descendant(of: strip, matching: find.byType(PlayingCard)), findsNWidgets(2));
    expect(find.descendant(of: strip, matching: find.text('FOLDED')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('community cards appear on the Player screen as the server reveals them', (tester) async {
    final harness = await _seated(tester);
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)), findsNothing);
    harness.network.last.serverSends(StateUpdate(stateVersion: 2, view: _hand(board: <PokerCard>[card('9c'), card('Jh'), card('2d')])));
    await tester.pump();
    await tester.pump();
    expect(find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)), findsNWidgets(3));
    expect(find.bySemanticsLabel('Nine of clubs'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('at showdown everyone sees every hand and who won each pot', (tester) async {
    final harness = await _seated(tester);
    const reveals = <Reveal>[
      Reveal(
        playerId: 'p_0',
        name: 'Dimath',
        cards: <PokerCard>[PokerCard(CardRank.king, CardSuit.hearts), PokerCard(CardRank.king, CardSuit.clubs)],
        category: HandCategory.threeOfAKind,
        bestFive: <PokerCard>[
          PokerCard(CardRank.king, CardSuit.hearts),
          PokerCard(CardRank.king, CardSuit.clubs),
          PokerCard(CardRank.king, CardSuit.diamonds),
          PokerCard(CardRank.jack, CardSuit.hearts),
          PokerCard(CardRank.nine, CardSuit.clubs),
        ],
      ),
      Reveal(
        playerId: 'p_1',
        name: 'Alice',
        cards: <PokerCard>[PokerCard(CardRank.ace, CardSuit.spades), PokerCard(CardRank.king, CardSuit.diamonds)],
        category: HandCategory.pair,
        bestFive: <PokerCard>[
          PokerCard(CardRank.ace, CardSuit.spades),
          PokerCard(CardRank.king, CardSuit.diamonds),
          PokerCard(CardRank.jack, CardSuit.hearts),
          PokerCard(CardRank.nine, CardSuit.clubs),
          PokerCard(CardRank.two, CardSuit.diamonds),
        ],
      ),
    ];
    const result = HandResult(
      uncontested: false,
      pots: <PotResult>[
        PotResult(
          potIndex: 0,
          amount: 120,
          winnerPlayerIds: <String>['p_0'],
          shares: <Share>[Share(playerId: 'p_0', name: 'Dimath', amount: 120)],
        ),
      ],
    );
    harness.network.last.serverSends(
      StateUpdate(
        stateVersion: 2,
        view: roomView(
          hand: 3,
          phase: WirePhase.showdown,
          pot: 0,
          seats: _seats(),
          board: <PokerCard>[card('Kd'), card('Jh'), card('2d'), card('9c'), card('Qs')],
          reveals: reveals,
          result: result,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShowdownPanel), findsNothing, reason: 'the board is dealt street by street first; no spoiler');
    for (var street = 0; street < 2; street++) {
      harness.clock = harness.clock.add(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final panel = find.byType(ShowdownPanel);
    await tester.ensureVisible(panel);
    expect(panel, findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('DIMATH')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('ALICE')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Three of a kind')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Dimath +120')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text(Strings.winnerTag.toUpperCase())), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a room with real cards shows none of this', (tester) async {
    final harness = TestHarness();
    _phone(tester);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.tap(find.text('JOIN A GAME'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'kq7m');
    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump();
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 't'))
      ..serverSends(
        snapshot(
          version: 1,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(hand: 3, activeSeat: 2, seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice'), seatView(2, 'Bob')]),
        ),
      );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HoleCardsDock), findsNothing);
    expect(find.byType(BoardView), findsNothing);
    expect(find.byType(OpponentStrip), findsNothing);
    await _close(tester);
  });
}
