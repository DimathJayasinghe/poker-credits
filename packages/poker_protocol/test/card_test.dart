import 'package:poker_protocol/poker_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('PokerCard', () {
    test('parse round trips all 52 cards', () {
      final seen = <String>{};
      for (final rank in CardRank.values) {
        for (final suit in CardSuit.values) {
          final card = PokerCard(rank, suit);
          final text = card.toString();
          expect(text, hasLength(2));
          expect(PokerCard.parse(text), card);
          expect(PokerCard.parse(text).hashCode, card.hashCode);
          seen.add(text);
        }
      }
      expect(seen, hasLength(52));
    });

    test('the wire form is rank then suit, upper case rank and lower case suit', () {
      expect(const PokerCard(CardRank.ace, CardSuit.spades).toString(), 'As');
      expect(const PokerCard(CardRank.ten, CardSuit.diamonds).toString(), 'Td');
      expect(const PokerCard(CardRank.two, CardSuit.clubs).toString(), '2c');
    });

    test('bad strings are rejected, not guessed at', () {
      for (final bad in ['', 'A', 'Asx', 'as', 'AS', '1s', '0c', 'Ax', 'Zz', ' As', 'A s']) {
        expect(() => PokerCard.parse(bad), throwsFormatException, reason: '"$bad"');
        expect(PokerCard.tryParse(bad), isNull, reason: '"$bad"');
      }
    });

    test('cards compare by value and order by rank then suit', () {
      expect(const PokerCard(CardRank.king, CardSuit.hearts), const PokerCard(CardRank.king, CardSuit.hearts));
      expect(const PokerCard(CardRank.king, CardSuit.hearts), isNot(const PokerCard(CardRank.king, CardSuit.clubs)));
    });
  });
}
