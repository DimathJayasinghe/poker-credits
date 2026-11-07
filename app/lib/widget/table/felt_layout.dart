import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/scroll_fade.dart';

/// Places seat plates around the pot. Slots are fixed per seat index so a player keeps their place
/// on the screen for the whole game: that is what makes the screen match the room.
///
/// Two layouts, chosen from the space actually given, never from the device:
/// * **Oval**: plates on an ellipse around the pot. Only used when ten plates fit without touching
///   each other or the pot ([ovalFits]).
/// * **Grid**: plates in as many columns as fit, in seat order, under the pot. Used on narrow or
///   short areas. With [shrinkWrap] it has no scroll of its own, for a page that scrolls as a
///   whole; otherwise it scrolls inside its box.
///
/// Nothing is ever drawn over anything else: when the space is too small, the layout gives way
/// to the grid instead of squeezing the oval.
class FeltLayout extends StatelessWidget {
  const FeltLayout({
    super.key,
    required this.seatCount,
    required this.seatBuilder,
    required this.occupied,
    required this.center,
    this.shrinkWrap = false,
  });

  /// Slots around the table (the engine allows 10 seats).
  final int seatCount;

  /// Builds the plate for a seat index; called only for [occupied] indexes.
  final Widget Function(BuildContext context, int seatIndex, double plateWidth) seatBuilder;
  final Set<int> occupied;
  final Widget center;

  /// Lay the grid out at its full height so an outer scroll view can scroll it. Always the grid.
  final bool shrinkWrap;

  /// Below this width the oval gives way to the grid.
  static const double narrowWidth = 600;

  /// A plate's height at text scale 1. Every plate is exactly this tall.
  static const double plateHeight = 108;

  /// Neighbouring plates on the oval are at least half a plate height apart vertically at their
  /// closest (slots 2 and 3 of 10), so the oval needs about five plate heights, plus room for the
  /// pot between the top and bottom plates.
  static const double ovalPlateRows = 5.2;

  /// Grid plates are never narrower or wider than this.
  static const double minPlateWidth = 150;
  static const double maxPlateWidth = 240;

  /// The height a plate takes at the current text size.
  static double plateHeightFor(BuildContext context) => MediaQuery.textScalerOf(context).scale(plateHeight);

  /// The least height the oval needs at the current text size.
  static double minOvalHeight(BuildContext context) => plateHeightFor(context) * ovalPlateRows;

  /// Whether the oval can be used in [size] without overlap.
  static bool ovalFits(Size size, double plateHeight) => size.width >= narrowWidth && size.height >= plateHeight * ovalPlateRows;

  /// Slot position in -1..1 on both axes: slot 0 is at the bottom centre, then clockwise.
  static Offset slot(int index, int count) {
    final angle = math.pi / 2 + 2 * math.pi * index / count;
    return Offset(math.cos(angle), math.sin(angle));
  }

  @override
  Widget build(BuildContext context) {
    final heightPerPlate = plateHeightFor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final bounded = constraints.hasBoundedHeight;
        if (shrinkWrap || !bounded || !ovalFits(size, heightPerPlate)) return _grid(context, size);
        return _oval(context, size, heightPerPlate);
      },
    );
  }

  Widget _oval(BuildContext context, Size size, double heightPerPlate) {
    final c = BrutalTheme.of(context).colors;
    final plateWidth = (size.width * 0.19).clamp(120.0, maxPlateWidth);
    final radiusX = (size.width - plateWidth) / 2;
    final radiusY = (size.height - heightPerPlate) / 2;
    final middle = Offset(size.width / 2, size.height / 2);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: plateWidth * 0.55, vertical: heightPerPlate * 0.55),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.felt,
                border: Border.all(color: c.line, width: BrutalMetrics.border),
              ),
            ),
          ),
        ),
        Center(child: center),
        for (var i = 0; i < seatCount; i++)
          if (occupied.contains(i))
            Positioned(
              left: middle.dx + slot(i, seatCount).dx * radiusX - plateWidth / 2,
              top: middle.dy + slot(i, seatCount).dy * radiusY,
              width: plateWidth,
              // Centred on the slot whatever height the plate turns out to have.
              child: FractionalTranslation(translation: const Offset(0, -0.5), child: seatBuilder(context, i, plateWidth)),
            ),
      ],
    );
  }

  Widget _grid(BuildContext context, Size size) {
    final c = BrutalTheme.of(context).colors;
    const gap = BrutalMetrics.gapM;
    final width = size.width.isFinite ? size.width : 360.0;
    final columns = math.max(1, ((width + gap) / (minPlateWidth + gap)).floor()).clamp(1, 5);
    final plateWidth = math.min(maxPlateWidth, (width - gap * (columns - 1)) / columns);
    final seats = occupied.toList()..sort();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.felt,
            border: Border.all(color: c.line, width: BrutalMetrics.border),
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
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final i in seats) SizedBox(width: plateWidth, child: seatBuilder(context, i, plateWidth)),
          ],
        ),
        const SizedBox(height: gap),
      ],
    );
    return shrinkWrap
        ? content
        : ScrollFade(
            builder: (context, controller) => SingleChildScrollView(controller: controller, child: content),
          );
  }
}
