import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Who won each pot, one line per pot, in the centre of the felt.
class PotResults extends StatelessWidget {
  const PotResults({super.key, required this.result, required this.color});

  final HandResult result;

  /// The text colour on the felt.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (var i = 0; i < result.pots.length; i++)
        Strings.potWonBy(
          i == 0 ? Strings.mainPot : Strings.sidePotNumber(i),
          result.pots[i].amount,
          result.pots[i].shares.map((s) => '${s.name} +${s.amount}').join(', '),
        ),
    ];
    return Semantics(
      container: true,
      label: lines.join('. '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final line in lines)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                line.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 16, color: color),
              ),
            ),
        ],
      ),
    );
  }
}
