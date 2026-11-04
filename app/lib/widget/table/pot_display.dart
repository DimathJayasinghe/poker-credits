import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The pot: the biggest block on the table. Side pots are listed below the total.
class PotDisplay extends StatelessWidget {
  const PotDisplay({super.key, required this.total, required this.pots, this.fontSize = 72});

  final int total;

  /// Final pots (empty during betting); tier 0 is the main pot.
  final List<PotView> pots;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final ink = c.onChip;
    final sides = pots.where((p) => p.tierIndex > 0).toList();
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
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapL, vertical: BrutalMetrics.gapM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                Strings.pot.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2, color: ink),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BrutalNumber(total, size: fontSize, color: ink),
              ),
              if (sides.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: BrutalMetrics.gapXs),
                  child: Wrap(
                    spacing: BrutalMetrics.gapM,
                    children: <Widget>[
                      for (final side in sides)
                        Text(
                          '${Strings.sidePot.toUpperCase()} ${side.amount}',
                          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 16, color: ink),
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
