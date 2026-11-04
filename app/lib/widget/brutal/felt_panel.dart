import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A flat green panel with a line drawing of a table: the slot where the references put a
/// photograph. Purely decorative, so it is hidden from screen readers.
class FeltPanel extends StatelessWidget {
  const FeltPanel({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return ExcludeSemantics(
      child: Container(
        height: height,
        color: c.felt,
        child: CustomPaint(
          painter: _TablePainter(line: c.onFelt, chip: c.chip, accent: c.accent),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter({required this.line, required this.chip, required this.accent});

  final Color line;
  final Color chip;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = BrutalMetrics.border;
    final center = size.center(Offset.zero);
    final rx = size.width * 0.36;
    final ry = size.height * 0.27;
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), stroke);
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2 - 24, height: ry * 2 - 24), stroke..color = line.withValues(alpha: 0.3));

    // Seat plates on the oval; the one at the top is the seat that has to act.
    const seats = 6;
    final plate = Size(size.shortestSide * 0.16, size.shortestSide * 0.09);
    for (var i = 0; i < seats; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / seats;
      // Seats sit just outside the rim, so the whole plate stays inside the panel.
      final at = center + Offset((rx + plate.width * 0.6) * math.cos(angle), (ry + plate.height * 0.8) * math.sin(angle));
      final rect = Rect.fromCenter(center: at, width: plate.width, height: plate.height);
      if (i == 0) {
        canvas.drawRect(rect, Paint()..color = accent);
      } else {
        canvas.drawRect(rect, Paint()..color = line.withValues(alpha: 0.12));
        canvas.drawRect(rect, stroke..color = line.withValues(alpha: 0.7));
      }
    }
    // The pot.
    final pot = Rect.fromCenter(center: center, width: size.shortestSide * 0.22, height: size.shortestSide * 0.13);
    canvas.drawRect(pot, Paint()..color = chip);
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) => oldDelegate.line != line || oldDelegate.chip != chip || oldDelegate.accent != accent;
}
