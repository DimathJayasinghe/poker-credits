import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The pot: the biggest block on the table. Side pots are listed below the total.
class PotDisplay extends StatelessWidget {
  const PotDisplay({super.key, required this.total, required this.pots, this.fontSize = 72, this.compact = false});

  final int total;

  /// Final pots (empty during betting); tier 0 is the main pot.
  final List<PotView> pots;
  final double fontSize;

  /// The label beside the figure instead of above it, for a short screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final ink = c.onChip;
    final sides = pots.where((p) => p.tierIndex > 0).toList();
    Widget label(Color ink, double size, double spacing) => Text(
      Strings.pot.toUpperCase(),
      style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: size, letterSpacing: spacing, color: ink),
    );
    return Semantics(
      container: true,
      label: '${Strings.pot} $total',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.chip,
          border: Border.all(color: c.line, width: BrutalMetrics.borderHeavy),
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapL, vertical: BrutalMetrics.gapM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (compact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    label(ink, 12, 1.5),
                    const SizedBox(width: BrutalMetrics.gapS),
                    BrutalNumber(total, size: fontSize, color: ink),
                  ],
                )
              else ...<Widget>[
                label(ink, 13, 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrutalNumber(total, size: fontSize, color: ink),
                ),
              ],
              if (sides.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: BrutalMetrics.gapXs),
                  child: Wrap(
                    spacing: BrutalMetrics.gapM,
                    children: <Widget>[
                      for (final side in sides)
                        Text(
                          '${Strings.sidePot.toUpperCase()} ${side.amount}',
                          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: compact ? 12 : 16, color: ink),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
