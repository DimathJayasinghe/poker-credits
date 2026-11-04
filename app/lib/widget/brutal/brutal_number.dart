import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A whole number in the display face with every digit in a box of the same width.
///
/// Anton has no tabular figures (its `1` is narrower), so a plain `Text` would shift sideways
/// while a pot counts up. Here `1111` and `8888` are exactly as wide.
class BrutalNumber extends StatelessWidget {
  const BrutalNumber(this.value, {super.key, this.size = 64, this.color});

  final int value;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = scaler.scale(size);
    final style = TextStyle(fontFamily: BrutalFonts.display, fontSize: fontSize, height: 1, color: color ?? c.ink);
    final box = fontSize * BrutalFonts.displayDigitEm;
    return Semantics(
      label: '$value',
      excludeSemantics: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final digit in '$value'.split(''))
              SizedBox(
                width: digit == '-' ? box * 0.6 : box,
                child: Text(digit, textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: style),
              ),
          ],
        ),
      ),
    );
  }
}
