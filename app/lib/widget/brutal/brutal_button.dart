import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Visual variants of [BrutalButton].
enum BrutalButtonKind { primary, danger, info, neutral }

/// Rectangular button with a thick border and a hard offset shadow. Pressing moves it onto its
/// shadow. Disabled when [onPressed] is null. See docs/UI_DESIGN.md section 3.
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

  /// Use the 4 px border and 8 px shadow (primary actions).
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
    final (Color fill, Color text) = switch (widget.kind) {
      BrutalButtonKind.primary => (c.signal, BrutalColors.light.ink),
      BrutalButtonKind.danger => (c.danger, c.onDanger),
      BrutalButtonKind.info => (c.info, c.onInfo),
      BrutalButtonKind.neutral => (c.paper, c.ink),
    };
    final border = widget.heavy ? BrutalMetrics.borderHeavy : BrutalMetrics.border;
    final shadow = widget.heavy ? BrutalMetrics.shadowHeavy : BrutalMetrics.shadow;
    final offset = _pressed && _enabled ? shadow : 0.0;

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
          child: Padding(
            // Room for the shadow so layout does not shift when pressed.
            padding: EdgeInsets.only(right: shadow, bottom: shadow),
            child: AnimatedContainer(
              duration: BrutalTheme.duration(context, BrutalMetrics.fast),
              transform: Matrix4.translationValues(offset, offset, 0),
              constraints: BoxConstraints(minHeight: widget.minHeight, minWidth: BrutalMetrics.tap),
              padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
              decoration: BoxDecoration(
                color: _enabled ? fill : c.muted.withValues(alpha: 0.35),
                border: Border.all(color: c.ink, width: border),
                boxShadow: _enabled && !_pressed ? <BoxShadow>[BoxShadow(color: c.ink, offset: Offset(shadow, shadow))] : const <BoxShadow>[],
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      border: Border.all(color: c.info, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: BrutalFonts.display,
                  fontSize: 16,
                  letterSpacing: 0.5,
                  color: _enabled ? text : c.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
