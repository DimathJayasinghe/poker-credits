import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_credits/widget/cards/suit_painter.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/test_app.dart';

PokerCard c(String text) => PokerCard.parse(text);

void main() {
  setUpAll(loadBrutalFonts);

  test('every card has a spoken name', () {
    expect(cardName(c('As')), 'Ace of spades');
    expect(cardName(c('Td')), 'Ten of diamonds');
    expect(cardName(c('2c')), 'Two of clubs');
    final names = <String>{
      for (final r in CardRank.values)
        for (final s in CardSuit.values) cardName(PokerCard(r, s)),
    };
    expect(names, hasLength(52));
  });

  test('suits differ by colour only in the four-colour deck, and always by shape', () {
    const light = BrutalColors.light;
    Color of(CardSuit s, bool four) => suitColor(light, s, fourColour: four);
    expect(of(CardSuit.hearts, false), of(CardSuit.diamonds, false));
    expect(of(CardSuit.clubs, false), of(CardSuit.spades, false));
    expect(<Color>{for (final s in CardSuit.values) of(s, true)}, hasLength(4));
    final shapes = <String>{for (final s in CardSuit.values) suitPath(s).getBounds().toString()};
    expect(shapes.length, greaterThan(1));
  });

  testWidgets('a face-up card is named for a screen reader and a face-down one is not', (tester) async {
    await tester.pumpWidget(
      brutalHost(
        const Row(
          children: <Widget>[
            PlayingCard(card: null),
            PlayingCard(card: PokerCard(CardRank.ace, CardSuit.spades)),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Ace of spades'), findsOneWidget);
    expect(find.bySemanticsLabel(Strings.cardBack), findsOneWidget);
  });

  testWidgets('cards ignore the text scale, so a huge font cannot break a row of them', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3), size: Size(320, 640)),
        child: brutalHost(
          const Align(
            alignment: Alignment.topLeft,
            child: PlayingCard(card: PokerCard(CardRank.ten, CardSuit.hearts), size: CardSize.mini),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PlayingCard)), const Size(30, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board keeps five slots so the row never changes size', (tester) async {
    await tester.pumpWidget(brutalHost(const BoardView(shown: <PokerCard>[])));
    final empty = tester.getSize(find.byType(BoardView));
    await tester.pumpWidget(brutalHost(BoardView(shown: <PokerCard>[c('As'), c('Kd'), c('2c')])));
    expect(tester.getSize(find.byType(BoardView)), empty);
    expect(find.byType(PlayingCard), findsNWidgets(3));
  });

  testWidgets('a board of five shrinks to a 320 px screen without overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      brutalHost(
        Padding(
          padding: const EdgeInsets.all(16),
          child: BoardView(shown: <PokerCard>[c('As'), c('Kd'), c('2c'), c('9h'), c('Ts')], size: CardSize.hero),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BoardView)).width, lessThanOrEqualTo(288));
  });

  group('HoleCardsDock', () {
    Widget dock({List<PokerCard>? cards, bool faceUp = false, bool peek = false, VoidCallback? onToggle}) =>
        brutalHost(HoleCardsDock(cards: cards, faceUp: faceUp, pressToPeek: peek, onToggle: onToggle ?? () {}));
    final hand = <PokerCard>[c('As'), c('Kd')];

    testWidgets('face down it says nothing about the cards, face up it names them', (tester) async {
      await tester.pumpWidget(dock(cards: hand));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Ace of spades'), findsNothing);
      expect(find.bySemanticsLabel(Strings.cardBack), findsNWidgets(0), reason: 'the dock describes itself once, not each card');
      expect(find.bySemanticsLabel(Strings.cardsHiddenSemantics), findsOneWidget);
      await tester.pumpWidget(dock(cards: hand, faceUp: true));
      await tester.pumpAndSettle();
      expect(tester.widgetList<PlayingCard>(find.byType(PlayingCard)).map((p) => p.card), hand);
    });

    testWidgets('a slow tap (past the long-press timeout) still flips', (tester) async {
      var taps = 0;
      await tester.pumpWidget(dock(cards: hand, onToggle: () => taps++));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoleCardsDock)));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a tap asks to flip', (tester) async {
      var taps = 0;
      await tester.pumpWidget(dock(cards: hand, onToggle: () => taps++));
      await tester.tap(find.byType(HoleCardsDock));
      expect(taps, 1);
    });

    testWidgets('on a shared table a tap does not flip, but holding shows the cards until release', (tester) async {
      var taps = 0;
      await tester.pumpWidget(dock(cards: hand, peek: true, onToggle: () => taps++));
      await tester.pumpAndSettle();
      bool faceUp() => tester.widgetList<PlayingCard>(find.byType(PlayingCard)).every((p) => p.card != null);
      expect(faceUp(), isFalse);
      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoleCardsDock)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(faceUp(), isTrue, reason: 'still held after a long press timeout');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(faceUp(), isFalse);
      expect(taps, 0);
    });

    testWidgets('without cards it shows two empty slots and cannot be flipped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(dock(onToggle: () => taps++));
      expect(find.byType(PlayingCard), findsNothing);
      await tester.tap(find.byType(HoleCardsDock));
      expect(taps, 0);
      expect(find.bySemanticsLabel(Strings.noCards), findsOneWidget);
    });

    testWidgets('with reduced motion the flip is instant', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: dock(cards: hand),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: dock(cards: hand, faceUp: true),
        ),
      );
      await tester.pump();
      expect(tester.widgetList<PlayingCard>(find.byType(PlayingCard)).map((p) => p.card), hand);
    });
  });

  group('ShowdownPanel', () {
    const alice = Reveal(
      playerId: 'p_1',
      name: 'Alice',
      cards: <PokerCard>[PokerCard(CardRank.ace, CardSuit.spades), PokerCard(CardRank.ace, CardSuit.hearts)],
      category: HandCategory.pair,
      bestFive: <PokerCard>[
        PokerCard(CardRank.ace, CardSuit.spades),
        PokerCard(CardRank.ace, CardSuit.hearts),
        PokerCard(CardRank.king, CardSuit.diamonds),
        PokerCard(CardRank.nine, CardSuit.clubs),
        PokerCard(CardRank.two, CardSuit.clubs),
      ],
    );
    const bob = Reveal(
      playerId: 'p_2',
      name: 'Bob',
      cards: <PokerCard>[PokerCard(CardRank.king, CardSuit.hearts), PokerCard(CardRank.three, CardSuit.diamonds)],
      category: HandCategory.pair,
      bestFive: <PokerCard>[
        PokerCard(CardRank.king, CardSuit.hearts),
        PokerCard(CardRank.king, CardSuit.diamonds),
        PokerCard(CardRank.nine, CardSuit.clubs),
        PokerCard(CardRank.six, CardSuit.clubs),
        PokerCard(CardRank.two, CardSuit.clubs),
      ],
    );
    const result = HandResult(
      uncontested: false,
      pots: <PotResult>[
        PotResult(
          potIndex: 0,
          amount: 80,
          winnerPlayerIds: <String>['p_1'],
          shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 80)],
        ),
        PotResult(
          potIndex: 1,
          amount: 40,
          winnerPlayerIds: <String>['p_2'],
          shares: <Share>[Share(playerId: 'p_2', name: 'Bob', amount: 40)],
        ),
      ],
    );

    testWidgets('shows every hand, its category, who won and how each pot was paid', (tester) async {
      await tester.pumpWidget(
        brutalHost(
          SingleChildScrollView(
            child: ShowdownPanel(
              reveals: const <Reveal>[alice, bob],
              result: result,
              board: [c('Kd'), c('9c'), c('2c'), c('6c'), c('Jh')],
              myPlayerId: 'p_2',
            ),
          ),
        ),
      );
      expect(find.text('ALICE'), findsOneWidget);
      expect(find.text('BOB'), findsOneWidget);
      expect(find.text('Pair'), findsNWidgets(2));
      expect(find.text(Strings.winnerTag.toUpperCase()), findsNWidgets(2), reason: 'one winner tag per winning player');
      expect(find.text(Strings.youTag.toUpperCase()), findsOneWidget);
      expect(find.text('MAIN POT 80'), findsOneWidget);
      expect(find.text('SIDE POT 1 40'), findsOneWidget);
      expect(find.text('Alice +80'), findsOneWidget);
      expect(find.text('Bob +40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hand won because everyone else folded shows no cards, only the payout', (tester) async {
      await tester.pumpWidget(
        brutalHost(
          const ShowdownPanel(
            reveals: <Reveal>[],
            board: <PokerCard>[],
            result: HandResult(
              uncontested: true,
              pots: <PotResult>[
                PotResult(
                  potIndex: 0,
                  amount: 30,
                  winnerPlayerIds: <String>['p_1'],
                  shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 30)],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(Strings.wonUncontested), findsOneWidget);
      expect(find.byType(PlayingCard), findsNothing);
      expect(find.text('Alice +30'), findsOneWidget);
    });

    testWidgets('the compact panel of a hand everyone folded to has no hands to list and still draws', (tester) async {
      // The player page asks for at least one row; with no revealed hand there is none to give.
      await tester.pumpWidget(
        brutalHost(
          const ShowdownPanel(
            compact: true,
            maxRows: 1,
            reveals: <Reveal>[],
            board: <PokerCard>[],
            result: HandResult(
              uncontested: true,
              pots: <PotResult>[
                PotResult(
                  potIndex: 0,
                  amount: 30,
                  winnerPlayerIds: <String>['p_1'],
                  shares: <Share>[Share(playerId: 'p_1', name: 'Alice', amount: 30)],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(Strings.wonUncontested), findsOneWidget);
      expect(find.text('Alice +30'), findsOneWidget);
    });

    testWidgets('ten hands at text scale 3 on a 320 px screen do not overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3), size: Size(320, 640)),
          child: brutalHost(
            SingleChildScrollView(
              child: ShowdownPanel(
                reveals: <Reveal>[for (var i = 0; i < 10; i++) alice],
                result: result,
                board: [c('Kd'), c('9c'), c('2c'), c('6c'), c('Jh')],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
