import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A labelled mark on a [BrutalSlider] (for example MIN, 1/2, POT, ALL-IN).
@immutable
class BrutalTick {
  const BrutalTick(this.label, this.value);

  final String label;
  final int value;
}

/// Thick track with a square thumb, tick marks and the value in a large box above.
///
/// The widget only maps a position to a number between [min] and [max]. What those bounds are
/// comes from the server (no poker rules here).
class BrutalSlider extends StatelessWidget {
  const BrutalSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.ticks = const <BrutalTick>[],
    this.step = 1,
    this.semanticLabel,
  }) : assert(max >= min, 'max must not be below min');

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final List<BrutalTick> ticks;
  final int step;
  final String? semanticLabel;

  static const double _thumb = 32;
  static const double _track = 12;

  int get _clamped => value.clamp(min, max);

  double get _fraction => max == min ? 0 : (_clamped - min) / (max - min);

  int _fromDx(double dx, double width) {
    final usable = width - _thumb;
    if (usable <= 0 || max == min) return min;
    final fraction = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    final raw = min + (fraction * (max - min)).round();
    final snapped = min + ((raw - min) / step).round() * step;
    return snapped.clamp(min, max);
  }

  void _nudge(int direction) => onChanged((_clamped + direction * step).clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
          decoration: BoxDecoration(
            color: c.paper,
            border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
          ),
          child: Text(
            '$_clamped',
            style: TextStyle(
              fontFamily: BrutalFonts.display,
              fontSize: 40,
              height: 1,
              color: c.ink,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final usable = width - _thumb;
            return Semantics(
              slider: true,
              label: semanticLabel,
              value: '$_clamped',
              increasedValue: '${(_clamped + step).clamp(min, max)}',
              decreasedValue: '${(_clamped - step).clamp(min, max)}',
              onIncrease: () => _nudge(1),
              onDecrease: () => _nudge(-1),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyUpEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _nudge(1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _nudge(-1);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => onChanged(_fromDx(d.localPosition.dx, width)),
                  onHorizontalDragUpdate: (d) => onChanged(_fromDx(d.localPosition.dx, width)),
                  child: SizedBox(
                    height: BrutalMetrics.tapPlayer,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        Positioned(
                          left: _thumb / 2,
                          right: _thumb / 2,
                          child: Container(
                            height: _track,
                            decoration: BoxDecoration(
                              color: c.paper,
                              border: Border.all(color: c.ink, width: BrutalMetrics.border),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _thumb / 2,
                          width: usable * _fraction,
                          child: Container(
                            height: _track,
                            color: c.signal,
                            foregroundDecoration: BoxDecoration(
                              border: Border.all(color: c.ink, width: BrutalMetrics.border),
                            ),
                          ),
                        ),
                        Positioned(
                          left: usable * _fraction,
                          child: Container(
                            width: _thumb,
                            height: _thumb,
                            decoration: BoxDecoration(
                              color: c.signal,
                              border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
                              boxShadow: <BoxShadow>[BoxShadow(color: c.ink, offset: const Offset(BrutalMetrics.shadow, BrutalMetrics.shadow))],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (ticks.isNotEmpty) ...<Widget>[
          const SizedBox(height: BrutalMetrics.gapS),
          Wrap(
            spacing: BrutalMetrics.gapS,
            runSpacing: BrutalMetrics.gapS,
            children: <Widget>[
              for (final tick in ticks)
                GestureDetector(
                  onTap: () => onChanged(tick.value.clamp(min, max)),
                  child: Semantics(
                    button: true,
                    label: tick.label,
                    excludeSemantics: true,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: BrutalMetrics.tap, minWidth: BrutalMetrics.tap),
                      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                      decoration: BoxDecoration(
                        color: _clamped == tick.value.clamp(min, max) ? c.signal : c.paper,
                        border: Border.all(color: c.ink, width: BrutalMetrics.border),
                      ),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          tick.label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: BrutalFonts.mono,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _clamped == tick.value.clamp(min, max) ? BrutalColors.light.ink : c.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
