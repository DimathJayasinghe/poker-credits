import 'package:dart_mappable/dart_mappable.dart';

/// Rank of a playing card, lowest first.
enum CardRank {
  two('2'),
  three('3'),
  four('4'),
  five('5'),
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  ten('T'),
  jack('J'),
  queen('Q'),
  king('K'),
  ace('A')
  ;

  const CardRank(this.symbol);

  /// Character used on the wire.
  final String symbol;
}

/// Suit of a playing card.
enum CardSuit {
  clubs('c'),
  diamonds('d'),
  hearts('h'),
  spades('s')
  ;

  const CardSuit(this.symbol);

  /// Character used on the wire.
  final String symbol;
}

/// One playing card. Named `PokerCard` so it never clashes with Flutter's `Card` widget.
///
/// On the wire a card is a two-character string, rank then suit: `As`, `Td`, `2c`. The app only
/// shows cards; ranking and dealing live in the Rust engine.
class PokerCard {
  const PokerCard(this.rank, this.suit);

  /// Reads the wire form.
  ///
  /// Throws [FormatException] for anything that is not exactly rank plus suit.
  factory PokerCard.parse(String text) {
    final card = tryParse(text);
    if (card == null) {
      throw FormatException('not a card', text);
    }
    return card;
  }

  /// Like [PokerCard.parse] but `null` instead of an exception.
  static PokerCard? tryParse(String text) {
    if (text.length != 2) {
      return null;
    }
    final rank = _ranks[text[0]];
    final suit = _suits[text[1]];
    if (rank == null || suit == null) {
      return null;
    }
    return PokerCard(rank, suit);
  }

  final CardRank rank;
  final CardSuit suit;

  static final Map<String, CardRank> _ranks = {for (final rank in CardRank.values) rank.symbol: rank};
  static final Map<String, CardSuit> _suits = {for (final suit in CardSuit.values) suit.symbol: suit};

  @override
  bool operator ==(Object other) => other is PokerCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  /// The wire form, for example `As`.
  @override
  String toString() => '${rank.symbol}${suit.symbol}';
}

/// Maps a [PokerCard] to and from its wire string. Any class with card fields lists it in
/// `includeCustomMappers`.
class PokerCardMapper extends SimpleMapper<PokerCard> {
  const PokerCardMapper();

  @override
  PokerCard decode(dynamic value) => PokerCard.parse(value as String);

  @override
  dynamic encode(PokerCard self) => self.toString();
}
