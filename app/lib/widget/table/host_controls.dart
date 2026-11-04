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
    // Secondary actions share one grid of equal cells, so their widths never depend on their labels.
    final secondary = <Widget>[
      if (betweenHands) BrutalButton(label: Strings.seatsButton, onPressed: enabled ? onSeats : null),
      if (view.paused)
        BrutalButton(label: Strings.resume, kind: BrutalButtonKind.info, onPressed: send(const ResumeGame()))
      else if (inHand)
        BrutalButton(label: Strings.pause, onPressed: send(const Pause())),
      if (inHand || phase == WirePhase.allInRunout || phase == WirePhase.showdown) BrutalButton(label: Strings.undo, onPressed: send(const Undo())),
      BrutalButton(label: Strings.endGame, kind: BrutalButtonKind.danger, onPressed: enabled ? onEndGame : null),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The one thing to do next gets a row of its own, the full width of the controls.
        if (primary != null) ...<Widget>[primary, const SizedBox(height: BrutalMetrics.gapS)],
        _ButtonGrid(children: secondary),
      ],
    );
  }
}

/// Lays buttons out in rows of equal cells. As many columns as keep a cell at least
/// [minCellWidth] wide, then the rows are balanced (four buttons make 2 + 2, not 3 + 1).
class _ButtonGrid extends StatelessWidget {
  const _ButtonGrid({required this.children});

  final List<Widget> children;

  static const double minCellWidth = 104;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = BrutalMetrics.gapS;
        final fit = ((box.maxWidth + gap) / (minCellWidth + gap)).floor().clamp(1, children.length);
        final rows = (children.length / fit).ceil();
        final columns = (children.length / rows).ceil();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var r = 0; r < rows; r++) ...<Widget>[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var col = 0; col < columns; col++) ...<Widget>[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(child: r * columns + col < children.length ? children[r * columns + col] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
