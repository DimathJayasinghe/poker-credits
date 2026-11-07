import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/suit_painter.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The three sizes a card is drawn at. Cards are graphics: they do not grow with the text size
/// (their name is in the semantics instead), so a large text size cannot break a row of them.
enum CardSize {
  /// Your own two cards.
  hero(84, 120, 38, 20, 44),

  /// The community cards.
  board(50, 72, 23, 12, 26),

  /// Opponents and the showdown list.
  mini(30, 44, 16, 11, 0),

  /// On a seat plate.
  tiny(22, 32, 12, 8, 0)
  ;

  const CardSize(this.width, this.height, this.rank, this.suit, this.pip);

  final double width;
  final double height;

  /// Rank type size.
  final double rank;

  /// Small suit mark beside the rank.
  final double suit;

  /// Big suit mark; 0 = none.
  final double pip;
}

/// One playing card: the face of [card], or its back when [card] is null.
class PlayingCard extends StatelessWidget {
  const PlayingCard({super.key, required this.card, this.size = CardSize.board, this.dim = false, this.lifted = false, this.fourColour = false});

  final PokerCard? card;
  final CardSize size;

  /// Pushed back, for cards that are not part of the winning hand.
  final bool dim;

  /// Raised, for the five cards that make the hand.
  final bool lifted;
  final bool fourColour;

  /// How far a lifted card rises.
  static const double liftBy = 6;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final face = card;
    final body = SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: face == null ? c.cardBack : c.cardFace,
          border: Border.all(color: c.ink, width: BrutalMetrics.border),
        ),
        child: face == null ? _Back(c, size) : _Face(c, face, size, fourColour: fourColour),
      ),
    );
    return Semantics(
      image: true,
      label: face == null ? Strings.cardBack : cardName(face),
      excludeSemantics: true,
      child: MediaQuery.withNoTextScaling(
        child: AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          transform: Matrix4.translationValues(0, lifted ? -liftBy : 0, 0),
          child: Opacity(opacity: dim ? 0.45 : 1, child: body),
        ),
      ),
    );
  }
}

/// A rank as printed on the card.
String rankLabel(CardRank rank) => rank == CardRank.ten ? '10' : rank.symbol;

class _Face extends StatelessWidget {
  const _Face(this.c, this.card, this.size, {required this.fourColour});

  final BrutalColors c;
  final PokerCard card;
  final CardSize size;
  final bool fourColour;

  @override
  Widget build(BuildContext context) {
    final ink = suitColor(c, card.suit, fourColour: fourColour);
    final corner = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          rankLabel(card.rank),
          maxLines: 1,
          style: TextStyle(fontFamily: BrutalFonts.display, fontSize: size.rank, height: 1, color: ink),
        ),
        SuitIcon(card.suit, size: size.suit, color: ink),
      ],
    );
    if (size.pip == 0) return Center(child: corner);
    return Stack(
      children: <Widget>[
        Positioned(left: 4, top: 3, child: corner),
        Positioned(
          right: 4,
          bottom: 4,
          child: SuitIcon(card.suit, size: size.pip, color: ink),
        ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back(this.c, this.size);

  final BrutalColors c;
  final CardSize size;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LatticePainter(c.cardBackMark), child: const SizedBox.expand());
}

/// The diamond lattice on the back of a card.
class _LatticePainter extends CustomPainter {
  const _LatticePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 4.0;
    final box = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..save()
      ..clipRect(box)
      ..drawRect(box, line);
    final step = (box.shortestSide / 3).clamp(6.0, 14.0);
    for (var d = -box.height; d < box.width; d += step) {
      canvas
        ..drawLine(Offset(box.left + d, box.top), Offset(box.left + d + box.height, box.bottom), line)
        ..drawLine(Offset(box.left + d, box.bottom), Offset(box.left + d + box.height, box.top), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.color != color;
}
