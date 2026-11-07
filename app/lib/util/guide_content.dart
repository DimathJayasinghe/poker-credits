/// Static teaching text for the Guide tab and the quick guide sheet.
///
/// This is reading material only. The Dart app holds no poker rules (CLAUDE.md): nothing here
/// ranks a hand or checks a bet. The rules themselves live in `crates/poker_engine`, and the
/// statements in [guideRules] mirror `docs/GAME_LOGIC_AND_RULES.md`; change them together.
library;

/// One step of "how a night works" or "how a hand plays".
class GuideStep {
  const GuideStep(this.title, this.body);

  final String title;
  final String body;
}

/// One entry of the ranked hand list. [rank] 1 is the strongest.
class GuideHand {
  const GuideHand(this.rank, this.name, this.line, this.example);

  final int rank;
  final String name;
  final String line;

  /// Written out, so it reads the same in every font: no suit symbols.
  final String example;
}

/// A word and what it means.
class GuideTerm {
  const GuideTerm(this.term, this.meaning);

  final String term;
  final String meaning;
}

/// What the app does and what you do, in the order a night goes.
const List<GuideStep> guideNight = <GuideStep>[
  GuideStep('One phone hosts', 'Tap Host a game. The screen shows a room code and a QR code. Everyone needs the same Wi-Fi.'),
  GuideStep('Everyone joins', 'Friends tap Join a game, then type the code and a name. Everyone starts with the same chips.'),
  GuideStep(
    'Real cards, or cards in the app',
    'The host picks. Real cards: you deal a normal deck, and the app never sees a card. Cards in the app: it deals for you. Your two cards wait face down on your phone.',
  ),
  GuideStep(
    'Play on your phone',
    'A big YOUR TURN block appears. Tap Fold, Check, Call or Raise. The app counts every chip.',
  ),
  GuideStep(
    'Show cards, then the pot is paid',
    'Players still in show their cards. Real cards: the host taps the winner. Cards in the app: the app shows every hand and pays the pots. Then the next hand starts.',
  ),
];

/// All ten hands, strongest first. Players compare the best five cards they can make from their
/// two cards and the five shared ones.
const List<GuideHand> guideHands = <GuideHand>[
  GuideHand(1, 'Royal flush', 'Ace, king, queen, jack and ten, all of one suit. The best hand there is.', 'A K Q J 10, one suit'),
  GuideHand(2, 'Straight flush', 'Five cards in a row, all of one suit.', '9 8 7 6 5, one suit'),
  GuideHand(3, 'Four of a kind', 'Four cards of the same number.', '7 7 7 7 and any card'),
  GuideHand(4, 'Full house', 'Three of one number and two of another.', 'K K K 4 4'),
  GuideHand(5, 'Flush', 'Any five cards of one suit, not in a row.', 'A J 8 5 2, one suit'),
  GuideHand(6, 'Straight', 'Five cards in a row, suits mixed. The ace can be high (10 to A) or low (A to 5).', '10 9 8 7 6'),
  GuideHand(7, 'Three of a kind', 'Three cards of the same number.', '9 9 9 and two others'),
  GuideHand(8, 'Two pair', 'Two different pairs.', 'J J 4 4 and any card'),
  GuideHand(9, 'One pair', 'Two cards of the same number.', 'Q Q and three others'),
  GuideHand(10, 'High card', 'None of the above. Your single highest card counts.', 'A 10 7 4 2, mixed suits'),
];

/// Notes that go with the ranking, shown under it.
const List<String> guideHandNotes = <String>[
  'Suits are never ranked against each other. Two flushes are compared card by card from the top.',
  'If two players have the same kind of hand, the higher cards win: a pair of kings beats a pair of nines.',
  'If that is also equal, the next highest unused card (the kicker) decides. If everything is equal the pot is split.',
  'The best five cards count, from your two plus the five shared ones. You may use both of your cards, one, or none.',
];

/// How one hand goes, from the deal to the payout.
const List<GuideStep> guideHandFlow = <GuideStep>[
  GuideStep(
    'Blinds',
    'Two players next to the dealer button post forced bets, so there is always something to win. The button moves one seat each hand. The app posts them for you.',
  ),
  GuideStep('Pre-flop', 'Everyone gets two private cards. Betting starts left of the big blind and goes clockwise.'),
  GuideStep('Flop', 'Three shared cards are turned face up. Another round of betting.'),
  GuideStep('Turn', 'A fourth shared card. Another round of betting.'),
  GuideStep('River', 'The fifth and last shared card. The final round of betting.'),
  GuideStep(
    'Showdown',
    'Players still in show their cards. The best five-card hand wins. If everyone else folds, the last player wins without showing.',
  ),
];

/// Words you will hear and see on the buttons.
const List<GuideTerm> guideTerms = <GuideTerm>[
  GuideTerm('Fold', 'Give up this hand. You lose the chips you already put in, and you are out until the next hand.'),
  GuideTerm('Check', 'Pass without betting. Only possible when nobody has bet yet this round.'),
  GuideTerm('Call', 'Match the current bet to stay in. The button shows how many chips it costs.'),
  GuideTerm(
    'Bet / Raise',
    'Put in more chips so others must pay more to stay in. Raise opens a slider with the smallest and largest amount allowed.',
  ),
  GuideTerm('All-in', 'Bet every chip you have. You can still win the part of the pot you covered.'),
  GuideTerm('Pot', 'All the chips bet so far this hand. The winner takes it.'),
  GuideTerm('Side pot', 'When someone is all-in for less, the others bet into a separate pot. The short player cannot win it.'),
  GuideTerm('Blinds', 'The forced bets before the cards are dealt: the small blind, then the big blind (usually double).'),
  GuideTerm('Dealer button', 'The D marker. It shows who deals and moves one seat clockwise every hand. The blinds sit to its left.'),
  GuideTerm('Stack', 'The chips one player has.'),
  GuideTerm('Hole cards', 'The two private cards each player is dealt. Only you see yours until the showdown.'),
  GuideTerm('Community cards', 'The five shared cards turned face up in the middle: three on the flop, one on the turn, one on the river.'),
  GuideTerm(
    'Run-out',
    'When everyone left is all-in, betting stops. The rest of the shared cards are turned over one street at a time.',
  ),
  GuideTerm('Kicker', 'The extra card that breaks a tie between two equal hands.'),
  GuideTerm('Showdown', 'Turning your cards over at the end of the hand.'),
];

/// What the app enforces for you, so nobody argues at the table.
const List<String> guideRules = <String>[
  'You may check only when nobody has bet this round. Otherwise the button says Call.',
  'A bet is at least the big blind. A raise is at least as big as the last one. The one exception: going all-in with less.',
  'You can raise up to all of your chips, never more.',
  'After an all-in for less than a full raise, players who already acted can only call or fold.',
  'Chips nobody could match go straight back to the player who bet them.',
  'Side pots are worked out for you. The pots are paid from the last side pot back to the main pot.',
  'If players tie, the pot is split. A leftover chip goes to the tied player sitting first to the left of the dealer button.',
  'With two players, the dealer posts the small blind and acts first before the flop and last after it.',
  'With a turn timer, you check when time runs out if it costs nothing. Otherwise you fold. Two timeouts in a row sit you out.',
  'Sit out, leave or top up between hands. A new player or a returning one is dealt in from the next hand.',
  'The host can pause and undo up to five steps. With cards in the app, undo stays inside one betting round. A turned card cannot be taken back.',
  'With cards in the app, the app decides the winners and pays every pot.',
];

/// What to do when the connection drops.
const List<GuideStep> guideDrops = <GuideStep>[
  GuideStep('Your seat and chips are kept', 'If your phone loses Wi-Fi or you switch app, the table keeps your seat and your chips.'),
  GuideStep('Come back', 'Open the app and tap Back to my game. You are put straight back where you were.'),
  GuideStep(
    'The clock keeps running',
    'If it is your turn while you are away, the timer still runs and the table will check or fold for you when it ends.',
  ),
  GuideStep('If the host closes the app', 'The game stops for everyone. When the host opens it again, Resume hosted game brings the table back.'),
];

/// Good habits with real cards.
const List<String> guideManners = <String>[
  'Keep your cards where everyone can see you have them, but do not show them until the showdown.',
  'Act in turn. The app tells you whose turn it is, so there is no guessing.',
  'Do not talk about your hand while the hand is still being played.',
  'The app is the bank. Use it for every chip, and keep the real cards on the table.',
];

/// How cards in the app work, once a game uses them.
const List<GuideStep> guideCards = <GuideStep>[
  GuideStep(
    'Your two cards',
    'They wait face down on your phone. Tap to look, tap again to hide. On a shared screen, hold your finger on them to peek. Fold, and the dock says No cards.',
  ),
  GuideStep(
    'The shared cards',
    'The flop, turn and river appear on the table and on every phone. After an all-in the app turns them over one street at a time, so nobody misses a card.',
  ),
  GuideStep(
    'The showdown',
    'Everyone still in shows both cards. Each winning hand is named, and every pot lists who won how much. The app pays out; the host picks nothing.',
  ),
  GuideStep(
    'Card settings',
    'In Settings you can show your cards as soon as they are dealt. You can also switch to a four-colour deck: clubs green, diamonds blue.',
  ),
];

/// Staying safe on a shared network.
const List<String> guideSafety = <String>[
  'Use your own Wi-Fi, or a phone hotspot with a password. Avoid public or shared Wi-Fi such as a cafe, hotel or school.',
  'The game connection is not encrypted. Give the room code only to the people at your table.',
  'With cards in the app, the host phone holds the deck and knows every card. Play that way only with people you would trust to host.',
  'Chips are counters. The app never moves real money.',
  'You can read the full notice again in Settings under Terms and safety.',
];
