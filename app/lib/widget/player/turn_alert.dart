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
  const TurnBlock({super.key, required this.myTurn, required this.title, this.detail, this.scale = 1, this.trailing});

  final bool myTurn;
  final String title;

  /// 1 = full size; a short screen asks for less (see `PlayerFit`).
  final double scale;

  /// When set, the block is one line: the title and the detail on the left, this on the right
  /// (the pot). For a screen with no height to spare.
  final String? trailing;

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
        child: trailing != null
            ? _line(text)
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapL * scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: BrutalFonts.display, fontSize: (myTurn ? 48 : 28) * scale, height: 1.1, color: text),
                      ),
                    ),
                    if (detail != null) ...<Widget>[
                      SizedBox(height: BrutalMetrics.gapS * scale),
                      Text(
                        detail!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: BrutalFonts.mono,
                          fontWeight: FontWeight.bold,
                          fontSize: scale < 0.8 ? 15 : 18,
                          letterSpacing: 1.5,
                          color: text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _line(Color text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(fontFamily: BrutalFonts.display, fontSize: myTurn ? 26 : 20, height: 1.1, color: text),
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(width: BrutalMetrics.gapS),
                    Text(
                      detail!.toUpperCase(),
                      style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1, color: text),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: BrutalMetrics.gapS),
          Text(
            trailing!.toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 20, height: 1.1, color: text),
          ),
        ],
      ),
    );
  }
}
