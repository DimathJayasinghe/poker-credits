import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/seat_order.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// What the host presses. Every button only sends a command and waits for the server's answer
/// (`ACK` / `ERROR` / the next state): whether a command is allowed is the server's decision.
class HostControls extends StatelessWidget {
  const HostControls({
    super.key,
    required this.view,
    required this.enabled,
    required this.onSend,
    required this.onPickWinners,
    required this.onSeats,
    required this.onEndGame,
  });

  final RoomView view;

  /// False while the link is down: buttons are disabled instead of queueing commands.
  final bool enabled;
  final void Function(ClientMessage message) onSend;
  final VoidCallback onPickWinners;
  final VoidCallback onSeats;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    final phase = view.phase;
    final inHand = phase == WirePhase.preFlop || phase == WirePhase.flop || phase == WirePhase.turn || phase == WirePhase.river;
    VoidCallback? send(ClientMessage message) => enabled ? () => onSend(message) : null;

    final primary = switch (phase) {
      WirePhase.lobby || WirePhase.nextHandPrep => BrutalButton(
        label: Strings.startHand,
        kind: BrutalButtonKind.primary,
        heavy: true,
        minHeight: BrutalMetrics.tapPlayer,
        onPressed: send(const StartHand()),
      ),
      WirePhase.allInRunout => BrutalButton(
        label: Strings.beginShowdown,
        kind: BrutalButtonKind.primary,
        heavy: true,
        minHeight: BrutalMetrics.tapPlayer,
        onPressed: send(const BeginShowdown()),
      ),
      WirePhase.showdown => BrutalButton(
        label: Strings.resolveShowdown,
        kind: BrutalButtonKind.primary,
        heavy: true,
        minHeight: BrutalMetrics.tapPlayer,
        onPressed: enabled ? onPickWinners : null,
      ),
      _ => null,
    };
    final betweenHands = !seatsLocked(phase);
    // A button fills the width it is given, so in a row of buttons each one is sized to its label.
    Widget fit(Widget button) => IntrinsicWidth(
      child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 112), child: button),
    );
    return Wrap(
      spacing: BrutalMetrics.gapM,
      runSpacing: BrutalMetrics.gapS,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (primary != null) fit(primary),
        if (betweenHands) fit(BrutalButton(label: Strings.seatsButton, onPressed: enabled ? onSeats : null)),
        if (view.paused)
          fit(BrutalButton(label: Strings.resume, kind: BrutalButtonKind.info, onPressed: send(const ResumeGame())))
        else if (inHand)
          fit(BrutalButton(label: Strings.pause, onPressed: send(const Pause()))),
        if (inHand || phase == WirePhase.allInRunout || phase == WirePhase.showdown)
          fit(BrutalButton(label: Strings.undo, onPressed: send(const Undo()))),
        fit(BrutalButton(label: Strings.endGame, kind: BrutalButtonKind.danger, onPressed: enabled ? onEndGame : null)),
      ],
    );
  }
}
