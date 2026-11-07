import 'package:flutter/widgets.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// A short row of cards that shrinks as a whole rather than overflowing a narrow screen.
/// A null entry is a face-down card.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.cards,
    this.size = CardSize.mini,
    this.gap = 4,
    this.fourColour = false,
    this.dimmed = const <int>{},
    this.liftedIndexes = const <int>{},
    this.alignment = MainAxisAlignment.start,
  });

  final List<PokerCard?> cards;
  final CardSize size;
  final double gap;
  final bool fourColour;

  /// Positions drawn dimmed.
  final Set<int> dimmed;

  /// Positions drawn raised.
  final Set<int> liftedIndexes;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: switch (alignment) {
        MainAxisAlignment.center => Alignment.center,
        MainAxisAlignment.end => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: Padding(
        padding: const EdgeInsets.only(top: PlayingCard.liftBy),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              PlayingCard(card: cards[i], size: size, fourColour: fourColour, dim: dimmed.contains(i), lifted: liftedIndexes.contains(i)),
            ],
          ],
        ),
      ),
    );
  }
}
