import 'package:flutter/widgets.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/cards/flip_in.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The community cards: [shown] face up from the left, the rest as empty slots so the row never
/// changes size when the flop, turn and river arrive.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.shown,
    this.slots = 5,
    this.size = CardSize.board,
    this.fourColour = false,
    this.highlight,
    this.slotColor,
    this.animate = false,
  });

  final List<PokerCard> shown;
  final int slots;
  final CardSize size;
  final bool fourColour;

  /// New cards turn over as they arrive, the three of a flop one after the other.
  final bool animate;

  /// Outline of the empty slots; the muted text colour by default. On the felt use its own text colour.
  final Color? slotColor;

  /// Cards of the winning hands stay raised and the others are dimmed; null = no highlight.
  final Set<PokerCard>? highlight;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < slots; i++) {
      if (i > 0) children.add(const SizedBox(width: 6));
      if (i < shown.length) {
        final card = shown[i];
        final marked = highlight;
        children.add(
          FlipIn(
            key: ValueKey<PokerCard>(card),
            card: card,
            animate: animate,
            // The flop's three cards turn one after the other; a turn or a river comes alone.
            delay: i < 3 ? BrutalMetrics.dealGap * i : Duration.zero,
            size: size,
            fourColour: fourColour,
            lifted: marked?.contains(card) ?? false,
            dim: marked != null && !marked.contains(card),
          ),
        );
      } else {
        children.add(_Slot(size, slotColor ?? BrutalTheme.of(context).colors.muted));
      }
    }
    return Semantics(
      container: true,
      label: Strings.boardLabel,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.only(top: PlayingCard.liftBy),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot(this.size, this.color);

  final CardSize size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1),
        ),
      ),
    ),
  );
}
