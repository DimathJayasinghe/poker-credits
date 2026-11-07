import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';

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
    this.stepButtons = false,
  }) : assert(max >= min, 'max must not be below min');

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final List<BrutalTick> ticks;
  final int step;
  final String? semanticLabel;

  /// Shows a minus and a plus button beside the value. A press moves the value by one [step];
  /// holding repeats, and the longer it is held the bigger the jumps, so a long range is quick to
  /// cross and a single tap is still exact.
  final bool stepButtons;

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

  void _nudge(int direction, [int multiplier = 1]) => onChanged((_clamped + direction * step * multiplier).clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The buttons stretch to the height of the value box.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (stepButtons) ...<Widget>[
                _StepButton(plus: false, enabled: _clamped > min, onStep: (m) => _nudge(-1, m)),
                const SizedBox(width: BrutalMetrics.gapS),
              ],
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line, width: BrutalMetrics.border),
                  ),
                  // A big text size makes the digits wider than the box between the step buttons.
                  child: FittedBox(fit: BoxFit.scaleDown, child: BrutalNumber(_clamped, size: 56)),
                ),
              ),
              if (stepButtons) ...<Widget>[
                const SizedBox(width: BrutalMetrics.gapS),
                _StepButton(plus: true, enabled: _clamped < max, onStep: (m) => _nudge(1, m)),
              ],
            ],
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
                              color: c.surface,
                              border: Border.all(color: c.line, width: BrutalMetrics.border),
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
                              color: c.accent,
                              border: Border.all(color: c.line, width: BrutalMetrics.borderHeavy),
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
                        color: _clamped == tick.value.clamp(min, max) ? c.accent : c.surface,
                        border: Border.all(color: c.line, width: BrutalMetrics.border),
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
                            color: _clamped == tick.value.clamp(min, max) ? c.onAccent : c.ink,
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

/// The minus or plus beside the slider's value. Acts on press, repeats while held and speeds up.
class _StepButton extends StatefulWidget {
  const _StepButton({required this.plus, required this.enabled, required this.onStep});

  final bool plus;
  final bool enabled;

  /// Called with how many steps to move: 1, then more the longer the button is held.
  final ValueChanged<int> onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  static const Duration _delay = Duration(milliseconds: 380);
  static const Duration _every = Duration(milliseconds: 80);

  Timer? _timer;
  int _ticks = 0;
  bool _down = false;

  void _start() {
    if (!widget.enabled) return;
    setState(() => _down = true);
    _ticks = 0;
    widget.onStep(1);
    _timer?.cancel();
    _timer = Timer(_delay, () {
      _timer = Timer.periodic(_every, (_) {
        _ticks++;
        widget.onStep(_ticks > 30 ? 20 : (_ticks > 12 ? 5 : 1));
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_down && mounted) setState(() => _down = false);
  }

  @override
  void didUpdateWidget(_StepButton old) {
    super.didUpdateWidget(old);
    // Reaching either end of the range ends the repeat.
    if (!widget.enabled) _stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final enabled = widget.enabled;
    final pressed = _down && enabled;
    final color = !enabled ? c.muted : (pressed ? c.paper : c.ink);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.plus ? Strings.increase : Strings.decrease,
      excludeSemantics: true,
      onTap: enabled ? () => widget.onStep(1) : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          width: 72,
          constraints: const BoxConstraints(minHeight: BrutalMetrics.tapPlayer),
          decoration: BoxDecoration(
            color: !enabled ? c.muted.withValues(alpha: 0.18) : (pressed ? c.ink : c.surface),
            border: Border.all(color: enabled ? c.line : c.muted, width: BrutalMetrics.border),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(22, 22),
              painter: _SignPainter(plus: widget.plus, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A minus or plus sign drawn as flat bars, so it never depends on a font having the glyph.
class _SignPainter extends CustomPainter {
  const _SignPainter({required this.plus, required this.color});

  final bool plus;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const bar = 4.0;
    canvas.drawRect(Rect.fromLTWH(0, (size.height - bar) / 2, size.width, bar), paint);
    if (plus) canvas.drawRect(Rect.fromLTWH((size.width - bar) / 2, 0, bar, size.height), paint);
  }

  @override
  bool shouldRepaint(_SignPainter old) => old.plus != plus || old.color != color;
}
