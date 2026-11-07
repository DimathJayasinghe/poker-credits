import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The other players on the phone: a name and two face-down cards each while they are still in
/// the hand, a plain "folded" once they are out. Only what the table can see anyway.
class OpponentStrip extends StatelessWidget {
  const OpponentStrip({super.key, required this.seats, required this.myPlayerId, this.showStacks = false, this.activeSeat});

  final List<SeatView> seats;
  final String? myPlayerId;

  /// Shows each player's chips under the name (a tournament is played by the stacks).
  final bool showStacks;

  /// The seat whose turn it is; its cell gets a heavy frame.
  final int? activeSeat;

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
              _Opponent(seat: seat, showStack: showStacks, active: seat.seatIndex == activeSeat),
              const SizedBox(width: BrutalMetrics.gapS),
            ],
          ],
        ),
      ),
    );
  }
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.seat, required this.showStack, required this.active});

  final SeatView seat;
  final bool showStack;
  final bool active;

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
          ],
        ),
      ),
    );
  }
}
