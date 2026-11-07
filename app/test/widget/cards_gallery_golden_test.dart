import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/test_app.dart';

PokerCard _c(String text) => PokerCard.parse(text);

const _alice = Reveal(
  playerId: 'p_1',
  name: 'Alice',
  cards: <PokerCard>[PokerCard(CardRank.ace, CardSuit.spades), PokerCard(CardRank.ace, CardSuit.hearts)],
  category: HandCategory.pair,
  bestFive: <PokerCard>[
    PokerCard(CardRank.ace, CardSuit.spades),
    PokerCard(CardRank.ace, CardSuit.hearts),
    PokerCard(CardRank.king, CardSuit.diamonds),
    PokerCard(CardRank.nine, CardSuit.clubs),
    PokerCard(CardRank.six, CardSuit.clubs),
  ],
);
const _bob = Reveal(
  playerId: 'p_2',
  name: 'Bob',
  cards: <PokerCard>[PokerCard(CardRank.king, CardSuit.hearts), PokerCard(CardRank.three, CardSuit.diamonds)],
  category: HandCategory.pair,
  bestFive: <PokerCard>[
    PokerCard(CardRank.king, CardSuit.hearts),
    PokerCard(CardRank.king, CardSuit.diamonds),
    PokerCard(CardRank.jack, CardSuit.hearts),
    PokerCard(CardRank.nine, CardSuit.clubs),
    PokerCard(CardRank.six, CardSuit.clubs),
  ],
);
const _result = HandResult(
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

Widget _gallery({required bool fourColour}) {
  final board = <PokerCard>[_c('Kd'), _c('9c'), _c('6c'), _c('Jh'), _c('Ts')];
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CardRow(
          cards: <PokerCard>[for (final suit in CardSuit.values) PokerCard(CardRank.queen, suit)],
          size: CardSize.hero,
          gap: 6,
          fourColour: fourColour,
        ),
        const SizedBox(height: 16),
        HoleCardsDock(cards: <PokerCard>[_c('As'), _c('Td')], faceUp: true, onToggle: () {}, fourColour: fourColour),
        HoleCardsDock(cards: <PokerCard>[_c('As'), _c('Td')], faceUp: false, onToggle: () {}),
        const HoleCardsDock(cards: null, faceUp: false, onToggle: _noop),
        const SizedBox(height: 8),
        BoardView(shown: board.sublist(0, 3), fourColour: fourColour),
        const SizedBox(height: 16),
        BoardView(shown: board, fourColour: fourColour, highlight: <PokerCard>{board[0], board[1], board[2], board[3], board[4]}),
        const SizedBox(height: 16),
        ShowdownPanel(reveals: const <Reveal>[_alice, _bob], result: _result, board: board, fourColour: fourColour, myPlayerId: 'p_2'),
      ],
    ),
  );
}

void _noop() {}

void main() {
  setUpAll(loadBrutalFonts);

  for (final dark in <bool>[false, true]) {
    for (final four in <bool>[false, true]) {
      final name = '${dark ? 'dark' : 'light'}${four ? '_four_colour' : ''}';
      testWidgets('card gallery, $name, phone portrait', (tester) async {
        tester.view
          ..physicalSize = const Size(390, 1400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(brutalHost(_gallery(fourColour: four), dark: dark));
        await tester.pumpAndSettle();
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/cards_gallery_$name.png'));
      });
    }
  }
}
