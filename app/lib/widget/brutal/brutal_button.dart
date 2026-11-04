import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

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
  });

  final String label;
  final VoidCallback? onPressed;
  final BrutalButtonKind kind;

  /// Larger label and the heavy rule as the border (primary actions).
  final bool heavy;
  final double minHeight;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    var (Color fill, Color text) = switch (widget.kind) {
      BrutalButtonKind.primary => (c.accent, c.onAccent),
      BrutalButtonKind.info => (c.ink, c.paper),
      BrutalButtonKind.danger || BrutalButtonKind.neutral => (c.surface, c.ink),
    };
    // Pressed: the cell inverts (ink becomes paper, anything else becomes ink).
    if (_pressed && _enabled) (fill, text) = fill == c.ink ? (c.paper, c.ink) : (c.ink, c.paper);
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: BrutalTheme.duration(context, BrutalMetrics.fast),
            constraints: BoxConstraints(minHeight: widget.minHeight, minWidth: BrutalMetrics.tap),
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
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
                if (widget.kind == BrutalButtonKind.danger && _enabled && !_pressed)
                  Positioned(
                    left: -BrutalMetrics.gapM,
                    top: -BrutalMetrics.gapS,
                    bottom: -BrutalMetrics.gapS,
                    child: ColoredBox(
                      color: c.accent,
                      child: const SizedBox(width: BrutalMetrics.gapS),
                    ),
                  ),
                Text(
                  widget.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: BrutalFonts.display,
                    fontSize: widget.heavy ? 22 : 17,
                    height: 1.1,
                    letterSpacing: 0.8,
                    color: _enabled ? text : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
