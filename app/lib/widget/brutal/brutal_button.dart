import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';

/// Visual variants of [BrutalButton]. Meaning rides on position and label, not on hue
/// (docs/UI_DESIGN.md section 2):
/// - [primary]: accent fill, the action the screen is for (raise, host, start).
/// - [info]: ink fill (call, check, join).
/// - [neutral]: outlined.
/// - [danger]: outlined with an accent bar on the left (fold, end game, forget).
enum BrutalButtonKind { primary, danger, info, neutral }

/// Rectangular cell button: a hairline border and flat fill. Pressing inverts it. Disabled when
/// [onPressed] is null. See docs/UI_DESIGN.md section 3.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = BrutalButtonKind.neutral,
    this.heavy = false,
    this.minHeight = BrutalMetrics.tap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BrutalButtonKind kind;

  /// Larger label and the heavy rule as the border (primary actions).
  final bool heavy;
  final double minHeight;

  /// Less padding and a smaller label, for a cell that is narrow (a row of three on a phone), so
  /// a word is not broken across two lines.
  final bool compact;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final duration = BrutalTheme.duration(context, BrutalMetrics.fast);
    final border = widget.heavy ? BrutalMetrics.borderHeavy : BrutalMetrics.border;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call()),
        },
        child: BrutalPressable(
          onTap: widget.onPressed,
          builder: (context, pressed) {
            var (Color fill, Color text) = switch (widget.kind) {
              BrutalButtonKind.primary => (c.accent, c.onAccent),
              BrutalButtonKind.info => (c.ink, c.paper),
              BrutalButtonKind.danger || BrutalButtonKind.neutral => (c.surface, c.ink),
            };
            // Pressed: the cell inverts (ink becomes paper, anything else becomes ink).
            if (pressed) (fill, text) = fill == c.ink ? (c.paper, c.ink) : (c.ink, c.paper);
            return AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              constraints: BoxConstraints(minHeight: widget.minHeight, minWidth: BrutalMetrics.tap),
              padding: widget.compact
                  ? const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapXs + 2, vertical: BrutalMetrics.gapXs)
                  : const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
              decoration: BoxDecoration(
                color: _enabled ? fill : c.muted.withValues(alpha: 0.18),
                border: Border.all(color: _enabled ? c.line : c.muted, width: border),
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      border: Border.all(color: c.ink, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                    )
                  : null,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (widget.kind == BrutalButtonKind.danger && _enabled)
                    Positioned(
                      left: -BrutalMetrics.gapM,
                      top: -BrutalMetrics.gapS,
                      bottom: -BrutalMetrics.gapS,
                      child: AnimatedContainer(
                        duration: duration,
                        width: pressed ? 0 : BrutalMetrics.gapS,
                        color: c.accent,
                      ),
                    ),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOut,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: BrutalFonts.display,
                      fontSize: widget.heavy ? 22 : (widget.compact ? 16 : 17),
                      height: 1.1,
                      letterSpacing: widget.compact ? 0.4 : 0.8,
                      color: _enabled ? text : c.muted,
                    ),
                    child: Text(widget.label.toUpperCase()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
