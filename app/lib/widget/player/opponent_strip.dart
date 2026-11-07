import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
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

  /// Widest one opponent's cell gets.
  static const double cellWidth = 76;

  /// Below this width a cell uses small cards and type, so five of them fit a narrow phone.
  static const double compactBelow = 70;

  /// Most cells in a row; more opponents than this take a second row, so the whole table is
  /// always in view and never scrolls sideways.
  static const int perRow = 5;

  @override
  Widget build(BuildContext context) {
    final others = seats.where((s) => s.playerId != myPlayerId).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    final inRow = others.length <= perRow ? others.length : (others.length + 1) ~/ 2;
    return Semantics(
      container: true,
      label: Strings.opponents,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
        child: LayoutBuilder(
          builder: (context, box) {
            // Gaps shrink with the cells; the width is shared out evenly.
            final gap = box.maxWidth < inRow * (cellWidth + BrutalMetrics.gapS) ? BrutalMetrics.gapXs : BrutalMetrics.gapS;
            final width = ((box.maxWidth - (inRow - 1) * gap) / inRow).floorToDouble().clamp(0.0, cellWidth);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final seat in others)
                  _Opponent(
                    seat: seat,
                    showStack: showStacks,
                    active: seat.seatIndex == activeSeat,
                    turnKey: turnKey,
                    paused: paused,
                    width: width,
                    dense: others.length > perRow,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Opponent extends StatelessWidget {
  const _Opponent({
    required this.seat,
    required this.showStack,
    required this.active,
    required this.turnKey,
    required this.paused,
    required this.width,
    required this.dense,
  });

  final SeatView seat;
  final bool showStack;
  final bool active;
  final Object? turnKey;
  final bool paused;

  /// Width of the cell; a narrow one is drawn with small cards and type.
  final double width;

  /// A crowded table: no card backs, only the name and the chips, so two rows stay short.
  final bool dense;

  bool get _compact => width < OpponentStrip.compactBelow;

  /// A tournament table marks whose turn it is with a frame; the ordinary strip stays plain.
  Widget _frame(BrutalColors c, {required Widget child}) {
    if (!showStack) return SizedBox(width: width, child: child);
    return Container(
      width: width,
      padding: EdgeInsets.all(_compact ? 2 : BrutalMetrics.gapXs),
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
    final type = _compact ? 11.0 : 12.0;
    final cards = _compact ? CardSize.tiny : CardSize.mini;
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
              style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: type, color: seat.hasFolded ? c.muted : c.ink),
            ),
            // One line under the name: the folded or all-in state, else the chips. A crowded table has
            // no card backs: the state is in the type and this line.
            if (dense ? (status != null || showStack) : showStack)
              Text(
                dense && status != null ? status.toUpperCase() : '${seat.chips}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: type, color: c.muted),
              ),
            if (!dense) ...<Widget>[
              const SizedBox(height: BrutalMetrics.gapXs),
              if (live)
                CardRow(cards: const <PokerCard?>[null, null], size: cards)
              else
                SizedBox(
                  height: cards.height,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      (status ?? '').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                  ),
                ),
            ],
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
