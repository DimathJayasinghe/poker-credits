import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Places seat plates on an oval around [center]. Slots are fixed per seat index so a player
/// keeps their place on the screen for the whole game. The oval is the layout; the shapes are
/// boxes (docs/UI_DESIGN.md section 4). On a narrow screen (phone portrait) an oval cannot fit ten
/// plates, so they stack in two columns under the pot instead, still in seat order.
class FeltLayout extends StatelessWidget {
  const FeltLayout({super.key, required this.seatCount, required this.seatBuilder, required this.occupied, required this.center});

  /// Slots around the table (the engine allows 10 seats).
  final int seatCount;

  /// Builds the plate for a seat index; called only for [occupied] indexes.
  final Widget Function(BuildContext context, int seatIndex, double plateWidth) seatBuilder;
  final Set<int> occupied;
  final Widget center;

  /// Below this width the oval gives way to the stacked layout.
  static const double narrowWidth = 600;

  /// Slot position in -1..1 on both axes: slot 0 is at the bottom centre, then clockwise.
  static Offset slot(int index, int count) {
    final angle = math.pi / 2 + 2 * math.pi * index / count;
    return Offset(math.cos(angle), math.sin(angle));
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width < narrowWidth) return _stacked(context, size);
        final plateWidth = (size.width * 0.19).clamp(120.0, 240.0);
        const plateHeight = 100.0;
        final radiusX = (size.width - plateWidth) / 2;
        final radiusY = (size.height - plateHeight) / 2;
        final middle = Offset(size.width / 2, size.height / 2);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: plateWidth * 0.55, vertical: plateHeight * 0.55),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.felt,
                    border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
                    boxShadow: <BoxShadow>[BoxShadow(color: c.ink, offset: const Offset(BrutalMetrics.shadowHeavy, BrutalMetrics.shadowHeavy))],
                  ),
                ),
              ),
            ),
            Center(child: center),
            for (var i = 0; i < seatCount; i++)
              if (occupied.contains(i))
                Positioned(
                  left: middle.dx + slot(i, seatCount).dx * radiusX - plateWidth / 2,
                  top: middle.dy + slot(i, seatCount).dy * radiusY - plateHeight / 2,
                  width: plateWidth,
                  child: seatBuilder(context, i, plateWidth),
                ),
          ],
        );
      },
    );
  }

  Widget _stacked(BuildContext context, Size size) {
    final c = BrutalTheme.of(context).colors;
    const gap = BrutalMetrics.gapM;
    final plateWidth = (size.width - gap) / 2;
    final seats = (occupied.toList()..sort());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.felt,
              border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
              boxShadow: <BoxShadow>[BoxShadow(color: c.ink, offset: const Offset(BrutalMetrics.shadowHeavy, BrutalMetrics.shadowHeavy))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(gap),
              child: Center(child: center),
            ),
          ),
          const SizedBox(height: gap),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final i in seats) SizedBox(width: plateWidth, child: seatBuilder(context, i, plateWidth)),
            ],
          ),
          const SizedBox(height: gap),
        ],
      ),
    );
  }
}
