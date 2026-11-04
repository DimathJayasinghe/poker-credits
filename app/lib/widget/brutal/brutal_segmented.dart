import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';

/// Two to four equal cells; the chosen one is inverted. For small choices such as the theme.
class BrutalSegmented<T> extends StatelessWidget {
  const BrutalSegmented({super.key, required this.value, required this.options, required this.onChanged, this.semanticLabel});

  final T value;

  /// In display order: value and its label.
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line, width: BrutalMetrics.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < options.length; i++) ...<Widget>[
                if (i > 0) VerticalDivider(width: BrutalMetrics.border, thickness: BrutalMetrics.border, color: c.line),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: options[i].$1 == value,
                    label: options[i].$2,
                    excludeSemantics: true,
                    onTap: () => onChanged(options[i].$1),
                    child: BrutalPressable(
                      onTap: () => onChanged(options[i].$1),
                      builder: (context, pressed) {
                        final solid = options[i].$1 == value || pressed;
                        final duration = BrutalTheme.duration(context, BrutalMetrics.fast);
                        return AnimatedContainer(
                          duration: duration,
                          constraints: const BoxConstraints(minHeight: BrutalMetrics.tap),
                          color: solid ? c.ink : c.paper.withValues(alpha: 0),
                          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapS),
                          alignment: Alignment.center,
                          // Shrinks to fit its cell rather than overflowing at large text sizes.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: BrutalFonts.mono,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                                color: solid ? c.paper : c.ink,
                              ),
                              child: Text(options[i].$2.toUpperCase()),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
