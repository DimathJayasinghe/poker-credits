import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Decides when the "your turn" vibration and sound go off: once per turn.
///
/// The server sends `TURN_PROMPT` again after every snapshot (a reconnect, a resumed app), so
/// firing on every prompt would buzz the phone each time the link comes back. A turn is
/// identified by the hand, the seat and the server's action counter, which moves on with every
/// accepted action of this player.
class TurnAlertGate {
  (int, int, int)? _last;

  /// True the first time [prompt] is seen; false for a repeat of the same turn.
  bool shouldFire({required TurnPrompt? prompt, required int handNumber}) {
    if (prompt == null) return false;
    final key = (handNumber, prompt.seatIndex, prompt.nextActionSeq);
    if (key == _last) return false;
    _last = key;
    return true;
  }
}

/// The big block in the middle of the controller: `accent` and loud on your turn, quiet `surface`
/// otherwise. The state is in the words as well as the colour.
class TurnBlock extends StatelessWidget {
  const TurnBlock({super.key, required this.myTurn, required this.title, this.detail});

  final bool myTurn;
  final String title;

  /// Countdown or a hint under the title.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final fill = myTurn ? c.accent : c.surface;
    final text = myTurn ? c.onAccent : c.ink;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title${detail == null ? '' : ', $detail'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: c.line, width: myTurn ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: myTurn ? 48 : 28, height: 1.1, color: text),
                ),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: BrutalMetrics.gapS),
                Text(
                  detail!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5, color: text),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
