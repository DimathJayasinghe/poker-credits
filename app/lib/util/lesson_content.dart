/// The steps of "Learn poker": a first lesson for someone who has never played Texas Hold'em.
///
/// Reading material only. The Dart app holds no poker rules (CLAUDE.md): the examples below are
/// fixed pictures with fixed text, checked by hand, and nothing here ranks a hand.
library;

import 'package:poker_credits/model/walkthrough.dart';

/// The ten hands for the pictures, strongest first, in the same order as `guideHands`.
/// Each is five cards written as rank then suit (`As` = ace of spades, `T` = ten).
const List<(String, List<String>)> handExamples = <(String, List<String>)>[
  ('Royal flush', <String>['As', 'Ks', 'Qs', 'Js', 'Ts']),
  ('Straight flush', <String>['9h', '8h', '7h', '6h', '5h']),
  ('Four of a kind', <String>['7s', '7h', '7d', '7c', 'Kd']),
  ('Full house', <String>['Ks', 'Kh', 'Kd', '4c', '4s']),
  ('Flush', <String>['Ad', 'Jd', '8d', '5d', '2d']),
  ('Straight', <String>['Tc', '9d', '8h', '7s', '6c']),
  ('Three of a kind', <String>['9s', '9h', '9d', 'Kc', '3s']),
  ('Two pair', <String>['Jh', 'Jc', '4d', '4s', 'Ac']),
  ('One pair', <String>['Qs', 'Qd', '9c', '6h', '2s']),
  ('High card', <String>['As', 'Td', '7c', '4h', '2s']),
];

/// The board for the pictures about the shared cards and the rounds.
const List<String> lessonBoard = <String>['Kh', '9c', '6d', 'Js', '2c'];

/// The last worked example: the board, and what the two players hold. Both have a pair of eights
/// from the board; Alice's jack beats Bob's ten.
const List<String> exampleBoard = <String>['8c', '8d', '7d', '4c', '3c'];
const List<String> exampleAlice = <String>['2s', 'Jh'];
const List<String> exampleBob = <String>['Td', '6h'];

/// The first worked example. Alice has five hearts (a flush); Bob has two pair, aces and nines.
const List<String> flushBoard = <String>['Ah', '7h', '4h', '9c', '2s'];
const List<String> flushAlice = <String>['Kh', '3h'];
const List<String> flushBob = <String>['Ac', '9d'];

/// "Same kind of hand, higher cards win": a pair of kings against a pair of nines.
/// Each row is a label, five cards and whether it is the winner.
const List<(String, List<String>, bool)> tieBreakRows = <(String, List<String>, bool)>[
  ('Pair of kings', <String>['Ks', 'Kd', '7c', '4h', '2s'], true),
  ('Pair of nines', <String>['9s', '9d', 'Jc', '5h', '3c'], false),
];

/// "The kicker": both have a pair of kings; the ace beats the queen.
const List<(String, List<String>, bool)> kickerRows = <(String, List<String>, bool)>[
  ('Alice: ace kicker', <String>['Ks', 'Kd', 'As', '7c', '2h'], true),
  ('Bob: queen kicker', <String>['Kh', 'Kc', 'Qd', '7d', '2s'], false),
];

/// Which two of [handExamples] each "hands" picture shows (weaker first, as indexes into that
/// strongest-first list). The lesson teaches the hands from the weakest to the strongest.
const List<(StepArt, int, int)> lessonHandPairs = <(StepArt, int, int)>[
  (StepArt.handsWeakest, 9, 8),
  (StepArt.handsPairs, 7, 6),
  (StepArt.handsRuns, 5, 4),
  (StepArt.handsFull, 3, 2),
  (StepArt.handsBest, 1, 0),
];

/// Written for someone who has never played: short sentences, one idea a step, each new word
/// explained where it first appears. Lines in a body are separated by newlines on purpose.
const List<WalkthroughStep> pokerLessonSteps = <WalkthroughStep>[
  WalkthroughStep(
    title: 'What poker is',
    body:
        'Poker is a card game played for chips. Each deal is called a hand. In every hand, players put chips in the middle. That pile is the pot, and one player wins it.',
    art: StepArt.goal,
    artLabel: 'A pot of 240 chips.',
  ),
  WalkthroughStep(
    title: 'Two ways to win',
    body:
        'You win the pot in one of two ways. Either you have the best hand when the cards are shown, or everyone else gives up. Giving up is called folding. Then you win without showing your cards.',
    art: StepArt.winWays,
    artLabel: 'Two boxes: the best hand wins, or everyone else folds.',
  ),
  WalkthroughStep(
    title: 'Your two secret cards',
    body:
        'Each player gets two cards that only they can see. These are your hole cards. Keep them secret. The two shown here are the ace of spades and the king of diamonds.',
    art: StepArt.holeCards,
    artLabel: 'Two cards: the ace of spades and the king of diamonds.',
  ),
  WalkthroughStep(
    title: 'Five shared cards',
    body: 'Five more cards go face up in the middle. This is called the board. It belongs to everybody: all players use the same five cards.',
    art: StepArt.board,
    artLabel: 'Five shared cards: king of hearts, nine of clubs, six of diamonds, jack of spades and two of clubs.',
  ),
  WalkthroughStep(
    title: 'Making your hand',
    body:
        'Your hand is the best five cards you can make. Pick them from seven: your two cards and the five on the board. You can use both of your cards, just one, or none.',
    art: StepArt.sevenCards,
    artLabel: 'The five board cards, and your two cards below them.',
  ),
  WalkthroughStep(
    title: 'The four rounds',
    body:
        'A hand has four rounds, and players bet in each one.\nPre-flop: no board cards yet.\nFlop: three board cards appear.\nTurn: a fourth card.\nRiver: the fifth and last card.',
    art: StepArt.rounds,
    artLabel: 'Four rows: pre-flop with no cards, flop with three, turn with four, river with five.',
  ),
  WalkthroughStep(
    title: 'The dealer button',
    body:
        'A marker called the dealer button shows who deals. After every hand it moves one seat to the left, so everybody gets the same turns in every spot. The app moves it for you.',
    art: StepArt.dealerButton,
    artLabel: 'Three seats. The first one has a D marker for the dealer.',
  ),
  WalkthroughStep(
    title: 'The blinds',
    body:
        'The two players after the dealer must bet before the cards are dealt. These forced bets are the blinds: a small one, then a bigger one. They make sure there is always something to win. The app posts them for you.',
    art: StepArt.blinds,
    artLabel: 'Three seats: the dealer, then the small blind, then the big blind.',
  ),
  WalkthroughStep(
    title: 'Your moves',
    body:
        'When it is your turn, you pick a move: fold, check, call or raise. The app shows only the moves you are allowed to make. Next, what each move means.',
    art: StepArt.choices,
    artLabel: 'Four buttons: Fold, Check, Call and Raise.',
  ),
  WalkthroughStep(
    title: 'Fold',
    body:
        'Fold means you give up this hand. You lose the chips you already bet, and you wait for the next hand. Fold when your cards are weak and the bet is big.',
    art: StepArt.moveFold,
    artLabel: 'The Fold button is highlighted: give up this hand.',
  ),
  WalkthroughStep(
    title: 'Check',
    body: 'Check means you pass without betting. You can only check when nobody has bet in this round. It costs nothing, and you stay in the hand.',
    art: StepArt.moveCheck,
    artLabel: 'The Check button is highlighted: pass with no bet.',
  ),
  WalkthroughStep(
    title: 'Call',
    body: 'Call means you match the bet on the table. If someone bet 20, you put in 20 too. You stay in the hand, and the round goes on.',
    art: StepArt.moveCall,
    artLabel: 'The Call button is highlighted: match the bet.',
  ),
  WalkthroughStep(
    title: 'Raise',
    body:
        'Raise means you bet more than the current bet. Everyone else must pay the extra to stay in, or fold. You choose how much. Raise when you like your hand.',
    art: StepArt.moveRaise,
    artLabel: 'The Raise button is highlighted: bet more.',
  ),
  WalkthroughStep(
    title: 'All-in',
    body: 'All-in means you bet every chip you have, all at once. If you win the hand, your chips grow fast. If you lose, you have no chips left.',
    art: StepArt.moveAllIn,
    artLabel: 'The All-in button is highlighted: bet everything.',
  ),
  WalkthroughStep(
    title: 'The showdown',
    body: 'After the last round of betting, the players still in the hand show their cards. This is the showdown. The best hand wins the pot.',
    art: StepArt.reveal,
    artLabel: 'Two players turn their cards over: Alice shows king and three of hearts, Bob shows ace and nine.',
  ),
  WalkthroughStep(
    title: 'The weakest hands',
    body:
        'There are ten kinds of hands. Here they are, weakest first.\nHigh card: nothing matches, so your highest card counts.\nOne pair: two cards with the same number, here two queens.',
    art: StepArt.handsWeakest,
    artLabel: 'High card, then one pair, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Two pair, three of a kind',
    body: 'Two pair: two different pairs, here jacks and fours.\nThree of a kind: three cards with the same number, here three nines.',
    art: StepArt.handsPairs,
    artLabel: 'Two pair, then three of a kind, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Straight and flush',
    body:
        'Straight: five cards in a row, in any suits. The ace can come before the 2 or after the king.\nFlush: five cards of one suit, in any order.',
    art: StepArt.handsRuns,
    artLabel: 'A straight from ten down to six, then a flush of diamonds, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Full house, four of a kind',
    body:
        'Full house: three cards of one number and two of another, here kings and fours.\nFour of a kind: four cards with the same number, here four sevens.',
    art: StepArt.handsFull,
    artLabel: 'A full house, then four of a kind, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'The strongest hands',
    body: 'Straight flush: five cards in a row, all of one suit.\nRoyal flush: ace, king, queen, jack and ten of one suit. Nothing beats it.',
    art: StepArt.handsBest,
    artLabel: 'A straight flush, then a royal flush, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Who wins this hand?',
    body:
        'Look at the hearts. The board has three, and Alice holds two more, so she has a flush. Bob has two pair, aces and nines. A flush beats two pair, so Alice wins.',
    art: StepArt.exampleFlush,
    artLabel: 'The board, then Alice with king and three of hearts marked as the winner, and Bob with ace and nine.',
  ),
  WalkthroughStep(
    title: 'Same kind, higher cards win',
    body:
        'What if two players have the same kind of hand? Then the higher cards win. A pair of kings beats a pair of nines. Compare the highest cards first.',
    art: StepArt.tieBreak,
    artLabel: 'A pair of kings is marked as the winner over a pair of nines.',
  ),
  WalkthroughStep(
    title: 'The kicker',
    body:
        'Two players can have the same pair. Then the highest card outside the pair decides. This card is called the kicker. Both have kings here, but the ace beats the queen. If everything matches, the players split the pot.',
    art: StepArt.kicker,
    artLabel: 'Two pairs of kings. The one with an ace as the fifth card is marked as the winner over the one with a queen.',
  ),
  WalkthroughStep(
    title: 'A closer one',
    body:
        'The board is 8, 8, 7, 4, 3. Alice holds a 2 and a jack. Bob holds a 10 and a 6. Both have a pair of eights from the board. So the highest other card decides: the jack beats the ten. Alice wins.',
    art: StepArt.workedExample,
    artLabel: 'The board, then Alice with a two and a jack marked as the winner, and Bob with a ten and a six.',
  ),
  WalkthroughStep(
    title: 'You are ready to play',
    body:
        'That is all you need. The app keeps track of the chips, the pot and whose turn it is. You choose fold, check, call or raise. Forgot a word? The Guide explains them all.',
    art: StepArt.words,
    artLabel: 'Labels: fold, check, call, raise, all-in, pot, kicker.',
  ),
];
