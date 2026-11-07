import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The other players on the phone: a name and two face-down cards each while they are still in
/// the hand, a plain "folded" once they are out. Only what the table can see anyway.
class OpponentStrip extends StatelessWidget {
  const OpponentStrip({
    super.key,
    required this.seats,
    required this.myPlayerId,
    this.showStacks = false,
    this.activeSeat,
    this.turnKey,
    this.paused = false,
  });

  final List<SeatView> seats;
  final String? myPlayerId;

  /// Shows each player's chips under the name (a tournament is played by the stacks).
  final bool showStacks;

  /// The seat whose turn it is; its cell gets a heavy frame.
  final int? activeSeat;

  /// Changes whenever a new turn starts, so the thinking bar of the player on turn starts over.
  final Object? turnKey;

  /// The game is paused: the thinking bar stands still.
  final bool paused;

  /// Width of one opponent's cell.
  static const double cellWidth = 76;

  @override
  Widget build(BuildContext context) {
    final others = seats.where((s) => s.playerId != myPlayerId).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: Strings.opponents,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final seat in others) ...<Widget>[
              _Opponent(seat: seat, showStack: showStacks, active: seat.seatIndex == activeSeat, turnKey: turnKey, paused: paused),
              const SizedBox(width: BrutalMetrics.gapS),
            ],
          ],
        ),
      ),
    );
  }
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.seat, required this.showStack, required this.active, required this.turnKey, required this.paused});

  final SeatView seat;
  final bool showStack;
  final bool active;
  final Object? turnKey;
  final bool paused;

  /// A tournament table marks whose turn it is with a frame; the ordinary strip stays plain.
  Widget _frame(BrutalColors c, {required Widget child}) {
    if (!showStack) return SizedBox(width: OpponentStrip.cellWidth, child: child);
    return Container(
      width: OpponentStrip.cellWidth,
      padding: const EdgeInsets.all(BrutalMetrics.gapXs),
      decoration: BoxDecoration(
        border: Border.all(color: active ? c.line : c.line.withValues(alpha: 0), width: active ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final live = seat.hasCards && !seat.hasFolded;
    final status = seat.hasFolded
        ? Strings.folded
        : seat.isAllIn
        ? Strings.allIn
        : null;
    return Semantics(
      container: true,
      label: '${seat.name}${showStack ? ', ${seat.chips}' : ''}${live ? ', ${Strings.hasCards}' : ''}${status == null ? '' : ', $status'}',
      excludeSemantics: true,
      child: _frame(
        c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              seat.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: seat.hasFolded ? c.muted : c.ink),
            ),
            if (showStack)
              Text(
                '${seat.chips}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 12, color: c.muted),
              ),
            const SizedBox(height: BrutalMetrics.gapXs),
            if (live)
              const CardRow(cards: <PokerCard?>[null, null])
            else
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text((status ?? '').toUpperCase(), style: TextStyle(fontSize: 11, color: c.muted)),
                ),
              ),
            // A tournament table shows that the player on turn is thinking, so there is something to
            // watch while a computer player takes its time. The slot is always there, so nothing moves.
            if (showStack) ...<Widget>[
              const SizedBox(height: BrutalMetrics.gapXs),
              ThinkingBar(key: ValueKey<Object?>(active ? turnKey : null), active: active && live, paused: paused),
            ],
          ],
        ),
      ),
    );
  }
}

/// A thin bar under a player's cards that fills while they think. It never reaches the end: a real
/// player does not announce when they will act, so it slows down as it fills (about 4 seconds for
/// two thirds of the width) instead of counting towards a moment.
class ThinkingBar extends StatefulWidget {
  const ThinkingBar({super.key, required this.active, required this.paused});

  final bool active;
  final bool paused;

  /// Height of the bar's slot.
  static const double height = 5;

  /// The time constant of the fill.
  static const Duration pace = Duration(seconds: 4);

  /// Fraction filled after [elapsed].
  static double fill(Duration elapsed) => 0.95 * (1 - math.exp(-elapsed.inMilliseconds / pace.inMilliseconds));

  @override
  State<ThinkingBar> createState() => _ThinkingBarState();
}

class _ThinkingBarState extends State<ThinkingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !widget.paused) {
      if (!_controller.isAnimating && !_controller.isCompleted) unawaited(_controller.forward());
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final reduced = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: widget.active ? Strings.thinking : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: ThinkingBar.height,
          child: widget.active
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final elapsed = Duration(milliseconds: (_controller.value * 20000).round());
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: reduced ? 0.5 : ThinkingBar.fill(elapsed).clamp(0.02, 1.0),
                        child: ColoredBox(
                          color: c.line,
                          child: const SizedBox(height: ThinkingBar.height),
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      ),
    );
  }
}
