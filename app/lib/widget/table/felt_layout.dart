import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/scroll_fade.dart';
import 'package:poker_credits/widget/table/table_fit.dart';

/// Places seat plates around the pot. Slots are fixed per seat index so a player keeps their place
/// on the screen for the whole game: that is what makes the screen match the room.
///
/// Two layouts, chosen from the space actually given, never from the device:
/// * **Oval**: plates on an ellipse around the pot. Only used when ten plates fit without touching
///   each other or the pot ([ovalFits]).
/// * **Grid**: the pot on top, the plates in as many columns as fit under it, in seat order. Used
///   on narrow or short areas. The rows share the height that is left, so the plates get shorter
///   (down to [TableFit.minPlate]) rather than the grid longer: the whole table is on screen.
///   Only when even the shortest plates do not fit does the grid scroll inside its own box.
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
    this.compactCenter,
    this.framed = true,
    this.showCenter = true,
    this.fit = TableFit.snug,
  });

  /// Slots around the table (the engine allows 10 seats).
  final int seatCount;

  /// Builds the plate for a seat index; called only for [occupied] indexes.
  final Widget Function(BuildContext context, int seatIndex, double plateWidth) seatBuilder;
  final Set<int> occupied;

  /// The middle of the oval; also the middle of the grid unless [compactCenter] is given.
  final Widget center;

  /// A smaller middle for the grid.
  final Widget? compactCenter;

  /// Whether the grid sets its middle on a felt panel. A middle that is a panel itself (the join
  /// code) goes bare.
  final bool framed;

  /// False when the page shows the middle elsewhere (in a pane beside the seats): the grid is then
  /// the seats alone. The oval always has its middle.
  final bool showCenter;

  /// How tightly the grid is drawn.
  final TableFit fit;

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
        if (!bounded) return _stacked(context, size);
        if (!ovalFits(size, heightPerPlate)) return _grid(context, size);
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
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final gapX = fit.gap;
    final gapY = fit.isRoomy ? fit.gap : (fit.isTight ? 4.0 : 6.0);
    final seats = occupied.toList()..sort();
    final width = size.width;
    final across = fit.isTight ? 124.0 : minPlateWidth;
    final widest = math.max(1, math.min(5, math.min(((width + gapX) / (across + gapX)).floor(), seats.length)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!showCenter)
          const SizedBox.shrink()
        else if (framed)
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.felt,
              border: Border.all(color: c.line, width: BrutalMetrics.border),
            ),
            child: Padding(
              padding: EdgeInsets.all(fit.gap),
              child: Center(child: compactCenter ?? center),
            ),
          )
        else
          compactCenter ?? center,
        if (showCenter) SizedBox(height: gapY),
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) {
              final least = fit.minPlate * scale;
              final most = fit.plate * scale;
              // As few columns as still give every plate its least height: wider plates read
              // better, and the tags and the cards then have room next to the chips. A phone
              // upright never goes below two.
              final fewest = math.min(widest, width < narrowWidth ? 2 : 1);
              var columns = widest;
              for (var cols = fewest; cols <= widest; cols++) {
                final needed = (seats.length / cols).ceil() * least + ((seats.length / cols).ceil() - 1) * gapY;
                if (needed <= area.maxHeight + 0.5) {
                  columns = cols;
                  break;
                }
              }
              final rows = math.max(1, (seats.length / columns).ceil());
              final plateWidth = math.min(maxPlateWidth, (width - gapX * (columns - 1)) / columns);
              final gridWidth = plateWidth * columns + gapX * (columns - 1);
              final room = (area.maxHeight - gapY * (rows - 1)) / rows;
              final height = room.clamp(least, most);
              final grid = SizedBox(
                width: gridWidth,
                child: Wrap(
                  spacing: gapX,
                  runSpacing: gapY,
                  children: <Widget>[
                    for (final i in seats) SizedBox(width: plateWidth, height: height, child: seatBuilder(context, i, plateWidth)),
                  ],
                ),
              );
              if (room >= least - 0.5) return Align(alignment: Alignment.topCenter, child: grid);
              // Even the shortest plates do not fit: the seats scroll inside their own box, and the
              // pot and the controls stay where they are.
              return ScrollFade(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  child: Align(alignment: Alignment.topCenter, child: grid),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context, Size size) {
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
    return content;
  }
}
