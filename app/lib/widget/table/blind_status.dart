import 'package:flutter/material.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// "25/50": the blinds of the hand, exactly as the server sent them.
String blindsText(BlindsView blinds) => '${blinds.smallBlind}/${blinds.bigBlind}';

/// When the blinds rise, in hands: "3 hands", "1 hand", or "Final level" when they never do.
String riseText(BlindsView blinds) {
  final left = blinds.handsLeft;
  return left == null ? Strings.blindsFinalLevel : Strings.handsCount(left);
}

/// The blinds and the countdown to the next rise, as two cells of a top bar. Only shows what the
/// server sent: the ladder is the engine's.
class BlindStatusCells extends StatelessWidget {
  const BlindStatusCells({super.key, required this.blinds});

  final BlindsView? blinds;

  @override
  Widget build(BuildContext context) {
    final b = blinds;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: TopBarStat(label: Strings.blinds, value: b == null ? '-' : blindsText(b)),
        ),
        Expanded(
          flex: 3,
          child: TopBarStat(label: Strings.blindsRise, value: b == null ? '-' : riseText(b)),
        ),
      ],
    );
  }
}
