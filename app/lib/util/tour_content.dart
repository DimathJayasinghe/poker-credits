/// The steps of the app tour: what the app does and how a night goes, in the order it happens.
///
/// Reading material only (CLAUDE.md: the Dart app holds no poker rules). What the app enforces is
/// in `guide_content.dart` and `docs/GAME_LOGIC_AND_RULES.md`.
library;

import 'package:poker_credits/model/walkthrough.dart';

const List<WalkthroughStep> appTourSteps = <WalkthroughStep>[
  WalkthroughStep(
    title: 'Welcome',
    body:
        'Poker Credits keeps the chips for your game night and, if you like, deals the cards too. This tour takes about two minutes. You can skip it now and find it again in the Guide.',
    art: StepArt.welcome,
    artLabel: 'Five spades turned face up: ace, king, queen, jack and ten.',
  ),
  WalkthroughStep(
    title: 'One phone hosts',
    body: 'Tap Host a game on the phone that will run the table. It shows a room code and a QR code. Everyone has to be on the same Wi-Fi.',
    art: StepArt.host,
    artLabel: 'A QR code next to the room code KQ7M.',
  ),
  WalkthroughStep(
    title: 'Everyone else joins',
    body:
        'Tap Join a game, then type the four-letter room code and pick a name, or choose the game from the list of games found nearby. Take a seat and you are in.',
    art: StepArt.join,
    artLabel: 'The room code K, Q, 7, M typed into four boxes, above a Join button.',
  ),
  WalkthroughStep(
    title: 'Real cards or cards in the app',
    body:
        'The host chooses when starting the game. With real cards you shuffle and deal a normal deck and the app only counts chips. With cards in the app, the host phone shuffles and deals, and your two cards wait face down on your own phone until you tap them.',
    art: StepArt.cardMode,
    artLabel: 'A choice between Real cards and Cards in the app, with two face-down cards below.',
  ),
  WalkthroughStep(
    title: 'Play on your phone',
    body:
        'When it is your turn a big YOUR TURN block appears with a clock. Tap Fold, Call or Raise, or Check when nobody has bet. The app only offers moves that are allowed, so nobody has to argue about the rules.',
    art: StepArt.yourTurn,
    artLabel: 'The text Your turn with a clock, above the buttons Fold, Call 20 and Raise.',
  ),
  WalkthroughStep(
    title: 'Showdown and winners',
    body:
        'At the end, everyone still in shows their cards. With cards in the app the app pays the pots itself and shows every hand and who won each pot. With real cards the host picks the winner.',
    art: StepArt.showdown,
    artLabel: 'Two seats showing their cards, one of them marked as the winner.',
  ),
  WalkthroughStep(
    title: 'Play alone',
    body:
        'Nobody around? Tap Play alone, then pick how many opponents you want and how well they play. It is a tournament: everyone starts with the same chips, nobody can buy back in, and the blinds keep rising. The game pauses when you leave the app.',
    art: StepArt.playAlone,
    artLabel: 'A choice between Easy, Normal and Hard, with the text 4 opponents below.',
  ),
  WalkthroughStep(
    title: 'Play safe',
    body:
        'Use your own Wi-Fi, or a phone hotspot with a password, never a public network. If your connection drops, open the app and tap Back to my game: your seat and chips are kept.',
    art: StepArt.staySafe,
    artLabel: 'A Wi-Fi symbol with a padlock.',
  ),
];
