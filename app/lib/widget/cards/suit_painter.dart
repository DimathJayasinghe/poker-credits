import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The colour of [suit] on a card face. Two colours by default, four for the four-colour deck.
Color suitColor(BrutalColors c, CardSuit suit, {required bool fourColour}) => switch (suit) {
  CardSuit.hearts => c.suitRed,
  CardSuit.diamonds => fourColour ? c.suitBlue : c.suitRed,
  CardSuit.clubs => fourColour ? c.suitGreen : c.suitBlack,
  CardSuit.spades => c.suitBlack,
};

/// The outline of [suit] in a unit box, so each suit has its own shape and colour never carries
/// the meaning alone.
Path suitPath(CardSuit suit) {
  final path = Path();
  switch (suit) {
    case CardSuit.hearts:
      _heart(path, flip: false);
    case CardSuit.spades:
      _heart(path, flip: true);
      path
        ..moveTo(0.5, 0.58)
        ..lineTo(0.34, 1)
        ..lineTo(0.66, 1)
        ..close();
    case CardSuit.diamonds:
      path
        ..moveTo(0.5, 0)
        ..lineTo(0.88, 0.5)
        ..lineTo(0.5, 1)
        ..lineTo(0.12, 0.5)
        ..close();
    case CardSuit.clubs:
      for (final (double x, double y) in const <(double, double)>[(0.5, 0.27), (0.26, 0.6), (0.74, 0.6)]) {
        path.addOval(Rect.fromCircle(center: Offset(x, y), radius: 0.23));
      }
      path
        ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.55), radius: 0.17))
        ..moveTo(0.5, 0.5)
        ..lineTo(0.35, 1)
        ..lineTo(0.65, 1)
        ..close();
  }
  return path;
}

/// A heart in the unit box; flipped it is the body of a spade (squeezed to leave room for the stem).
void _heart(Path path, {required bool flip}) {
  double y(double v) => flip ? 0.86 * (1 - v) : v;
  path
    ..moveTo(0.5, y(0.92))
    ..cubicTo(0.1, y(0.62), 0.0, y(0.38), 0.14, y(0.2))
    ..cubicTo(0.28, y(0.02), 0.46, y(0.1), 0.5, y(0.27))
    ..cubicTo(0.54, y(0.1), 0.72, y(0.02), 0.86, y(0.2))
    ..cubicTo(1.0, y(0.38), 0.9, y(0.62), 0.5, y(0.92))
    ..close();
}

/// Paints one suit symbol into its box.
class SuitPainter extends CustomPainter {
  const SuitPainter(this.suit, this.color);

  final CardSuit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = Float64List.fromList(<double>[size.width, 0, 0, 0, 0, size.height, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    canvas.drawPath(suitPath(suit).transform(matrix), Paint()..color = color);
  }

  @override
  bool shouldRepaint(SuitPainter old) => old.suit != suit || old.color != color;
}

/// A suit symbol of the given pixel size.
class SuitIcon extends StatelessWidget {
  const SuitIcon(this.suit, {super.key, required this.size, required this.color});

  final CardSuit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: SuitPainter(suit, color)),
  );
}
