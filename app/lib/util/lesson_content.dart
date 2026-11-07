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

/// The worked example: the board, and what the two players hold.
const List<String> exampleBoard = <String>['8c', '8d', '7d', '4c', '3c'];
const List<String> exampleAlice = <String>['2s', 'Jh'];
const List<String> exampleBob = <String>['Td', '6h'];

const List<WalkthroughStep> pokerLessonSteps = <WalkthroughStep>[
  WalkthroughStep(
    title: 'The goal',
    body:
        'Poker is played with chips. In every hand you are trying to win the pot, which is all the chips bet so far. You win it in one of two ways: by having the best hand at the end, or by making everyone else give up.',
    art: StepArt.goal,
    artLabel: 'A pot of 240 chips.',
  ),
  WalkthroughStep(
    title: 'Your two private cards',
    body:
        'Every player is dealt two cards that only they can see. These are your hole cards. The two shown here are the ace of spades and the king of diamonds.',
    art: StepArt.holeCards,
    artLabel: 'Two cards: the ace of spades and the king of diamonds.',
  ),
  WalkthroughStep(
    title: 'Five shared cards',
    body:
        'Five more cards are turned face up in the middle, and everybody can use them. Your hand is the best five cards you can make from your two and those five. You may use both of your cards, one of them, or none.',
    art: StepArt.board,
    artLabel: 'Five shared cards: king of hearts, nine of clubs, six of diamonds, jack of spades and two of clubs.',
  ),
  WalkthroughStep(
    title: 'Four rounds of betting',
    body:
        'Pre-flop: betting starts before any shared card is shown. Flop: three shared cards are turned and everyone bets again. Turn: a fourth card, another round. River: the fifth and last card, the final round. Then the players who are left show their cards.',
    art: StepArt.rounds,
    artLabel: 'Four rows: pre-flop with no cards, flop with three, turn with four, river with five.',
  ),
  WalkthroughStep(
    title: 'What you can do',
    body:
        'Fold: give up this hand. Check: pass without betting, only possible when nobody has bet. Call: match the current bet. Raise: bet more, so the others must pay more to stay in. All-in: bet every chip you have. When it is your turn the app shows only the moves that are allowed.',
    art: StepArt.choices,
    artLabel: 'Four buttons: Fold, Check, Call and Raise.',
  ),
  WalkthroughStep(
    title: 'Blinds and the dealer button',
    body:
        'Before the cards are dealt, two players put in forced bets, the small blind and the big blind, so there is always something to win. A D marker shows the dealer and moves one seat every hand. The blinds sit to its left. The app posts them for you.',
    art: StepArt.blinds,
    artLabel: 'One seat marked D and small blind, and the next seat marked big blind.',
  ),
  WalkthroughStep(
    title: 'Hands, strongest first',
    body:
        'Each hand beats every hand below it in the list. A royal flush is the best there is. These are the first five; the other five are on the next page.',
    art: StepArt.handsTop,
    artLabel: 'Royal flush, straight flush, four of a kind, full house and flush, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Hands, continued',
    body:
        'If two players have the same kind of hand, the higher cards win: a pair of kings beats a pair of nines. If those match too, the highest card left over, the kicker, decides. If everything is equal, the pot is split.',
    art: StepArt.handsBottom,
    artLabel: 'Straight, three of a kind, two pair, one pair and high card, each shown with five cards.',
  ),
  WalkthroughStep(
    title: 'Who wins this one?',
    body:
        'The shared cards are the eight of clubs, eight of diamonds, seven of diamonds, four of clubs and three of clubs. Alice holds a two and a jack. Bob holds a ten and a six. Both have a pair of eights from the table. Then the highest other card counts, and Alice\'s jack beats Bob\'s ten. Alice wins.',
    art: StepArt.workedExample,
    artLabel: 'The board, then Alice with a two and a jack marked as the winner, and Bob with a ten and a six.',
  ),
  WalkthroughStep(
    title: 'A few more words',
    body:
        'Pot: the chips bet so far. Stack: the chips one player has. Side pot: when someone is all-in for less, the others keep betting into a separate pot that player cannot win. Showdown: turning your cards over at the end. You will always find these in the Guide.',
    art: StepArt.words,
    artLabel: 'Labels: fold, check, call, raise, all-in, pot, kicker.',
  ),
];
