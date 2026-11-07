import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The other players on the phone: a name and two face-down cards each while they are still in
/// the hand, a plain "folded" once they are out. Only what the table can see anyway.
class OpponentStrip extends StatelessWidget {
  const OpponentStrip({super.key, required this.seats, required this.myPlayerId});

  final List<SeatView> seats;
  final String? myPlayerId;

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
            for (final seat in others) ...<Widget>[_Opponent(seat: seat), const SizedBox(width: BrutalMetrics.gapS)],
          ],
        ),
      ),
    );
  }
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.seat});

  final SeatView seat;

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
      label: '${seat.name}${live ? ', ${Strings.hasCards}' : ''}${status == null ? '' : ', $status'}',
      excludeSemantics: true,
      child: SizedBox(
        width: OpponentStrip.cellWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              seat.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: seat.hasFolded ? c.muted : c.ink),
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
