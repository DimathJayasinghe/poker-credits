import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A flat green panel with a line drawing of a table seen from above: the slot where the references
/// put a photograph. Purely decorative, so it is hidden from screen readers.
///
/// The drawing has one fixed shape ([aspect]) and is scaled to fit, never stretched: whatever the
/// panel's proportions (a short band on a phone, a tall column beside the title on a tablet, a
/// wide window), the table keeps the same proportions and the felt fills the rest.
class FeltPanel extends StatelessWidget {
  const FeltPanel({super.key, this.height});

  final double? height;

  /// Width over height of the drawing.
  static const double aspect = 1.7;

  /// Share of the panel kept clear around the drawing.
  static const double inset = 0.07;

  /// Where the drawing goes in a panel of [size]: the largest [aspect] rectangle that fits inside
  /// the inset, centred. Empty when there is no room.
  static Rect sceneRect(Size size) {
    final width = size.width * (1 - 2 * inset);
    final height = size.height * (1 - 2 * inset);
    if (width <= 0 || height <= 0) return Rect.zero;
    final sceneWidth = math.min(width, height * aspect);
    final sceneHeight = sceneWidth / aspect;
    return Rect.fromCenter(center: size.center(Offset.zero), width: sceneWidth, height: sceneHeight);
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return ExcludeSemantics(
      child: Container(
        height: height,
        color: c.felt,
        child: CustomPaint(
          painter: _TablePainter(line: c.onFelt, chip: c.chip, accent: c.accent, onAccent: c.onAccent),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter({required this.line, required this.chip, required this.accent, required this.onAccent});

  final Color line;
  final Color chip;
  final Color accent;
  final Color onAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = FeltPanel.sceneRect(size);
    if (scene.isEmpty) return;
    final unit = scene.height / 100; // everything below is in 1/100 of the drawing's height
    final stroke = Paint()
      ..color = line.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = BrutalMetrics.border;
    final center = scene.center;

    // The rim: the table, an inner line and the seats just outside it.
    final plate = Size(unit * 24, unit * 15);
    final rx = scene.width / 2 - plate.width * 0.62;
    final ry = scene.height / 2 - plate.height * 0.62;
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), stroke);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2 - unit * 7, height: ry * 2 - unit * 7),
      Paint()
        ..color = line.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = BrutalMetrics.border,
    );

    const seats = 6;
    for (var i = 0; i < seats; i++) {
      final angle = math.pi / 2 + i * 2 * math.pi / seats;
      final at = center + Offset(rx * math.cos(angle), ry * math.sin(angle));
      final rect = Rect.fromCenter(center: at, width: plate.width, height: plate.height);
      final acting = i == 3;
      canvas.drawRect(rect, Paint()..color = acting ? accent : line.withValues(alpha: 0.12));
      canvas.drawRect(rect, stroke);
      _number(canvas, '${i + 1}', rect, acting ? onAccent : line, unit * 9);
    }

    // The board: five cards in a row, and the pot under them.
    final card = Size(unit * 7.5, unit * 11);
    const gap = 2.0;
    final boardWidth = card.width * 5 + gap * 4 * unit * 0.3;
    final top = center.dy - card.height - unit * 2;
    for (var i = 0; i < 5; i++) {
      final left = center.dx - boardWidth / 2 + i * (card.width + gap * unit * 0.3);
      final rect = Rect.fromLTWH(left, top, card.width, card.height);
      if (i < 3) canvas.drawRect(rect, Paint()..color = line.withValues(alpha: 0.9));
      canvas.drawRect(rect, stroke);
    }
    final pot = Rect.fromCenter(center: Offset(center.dx, center.dy + unit * 9), width: unit * 20, height: unit * 9);
    canvas.drawRect(pot, Paint()..color = chip);
  }

  /// A seat number, centred in [rect].
  void _number(Canvas canvas, String text, Rect rect, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: BrutalFonts.display, fontSize: fontSize, height: 1, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, rect.center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.chip != chip || oldDelegate.accent != accent || oldDelegate.onAccent != onAccent;
}
