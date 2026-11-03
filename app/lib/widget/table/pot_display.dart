import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
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
    final ink = BrutalColors.light.ink;
    final sides = pots.where((p) => p.tierIndex > 0).toList();
    return Semantics(
      container: true,
      label: '${Strings.pot} $total',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: BrutalMetrics.shadowHeavy, bottom: BrutalMetrics.shadowHeavy),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.chip,
            border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
            boxShadow: <BoxShadow>[BoxShadow(color: c.ink, offset: const Offset(BrutalMetrics.shadowHeavy, BrutalMetrics.shadowHeavy))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapL, vertical: BrutalMetrics.gapM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  Strings.pot.toUpperCase(),
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: ink),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$total',
                    style: TextStyle(
                      fontFamily: BrutalFonts.display,
                      fontSize: fontSize,
                      height: 1,
                      color: ink,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
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
      ),
    );
  }
}
