import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// A rectangular name plate for one seat. The player who must act is the only accent fill;
/// state is always spelled out in a tag (never colour alone).
class SeatPlate extends StatelessWidget {
  const SeatPlate({
    super.key,
    required this.seat,
    this.isActive = false,
    this.isDealer = false,
    this.isSmallBlind = false,
    this.isBigBlind = false,
    this.turnFraction,
    this.seatNumber,
    this.onTap,
  });

  final SeatView seat;
  final bool isActive;
  final bool isDealer;
  final bool isSmallBlind;
  final bool isBigBlind;

  /// Fraction of the turn clock left (1 = full), drawn as a bar under the plate.
  final double? turnFraction;
  final VoidCallback? onTap;

  /// Shown at the right of the name between hands, so the screen can be checked against who sits
  /// where in the room. Hidden during a hand.
  final int? seatNumber;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final Color fill = isActive ? c.accent : c.surface;
    final Color text = isActive ? c.onAccent : c.ink;
    final dim = seat.hasFolded || seat.isSittingOut;
    final nameStyle = TextStyle(
      fontFamily: BrutalFonts.display,
      fontSize: 18,
      color: dim && !isActive ? c.muted : text,
      decoration: seat.hasFolded ? TextDecoration.lineThrough : null,
      decorationThickness: 3,
    );
    final tags = <Widget>[
      if (isDealer) const BrutalTag(Strings.dealer),
      if (isSmallBlind) const BrutalTag(Strings.smallBlindTag, kind: BrutalTagKind.info),
      if (isBigBlind) const BrutalTag(Strings.bigBlindTag, kind: BrutalTagKind.info),
      if (seat.isAllIn) const BrutalTag(Strings.allIn, kind: BrutalTagKind.danger),
      if (seat.hasFolded) const BrutalTag(Strings.folded),
      if (seat.isSittingOut) const BrutalTag(Strings.sittingOut),
      if (!seat.isConnected) const BrutalTag(Strings.offline),
    ];
    return Semantics(
      container: true,
      label: _semantics(),
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalPressable(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: c.line, width: pressed ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapS, BrutalMetrics.gapS, BrutalMetrics.gapS, BrutalMetrics.gapXs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(seat.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
                        ),
                        if (seatNumber != null)
                          Text(
                            '${seatNumber!}',
                            style: TextStyle(
                              fontFamily: BrutalFonts.mono,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isActive ? text : c.muted,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: BrutalNumber(seat.chips, size: 28, color: dim && !isActive ? c.muted : text),
                          ),
                        ),
                        if (seat.streetBet > 0) ...<Widget>[
                          const SizedBox(width: BrutalMetrics.gapS),
                          Text(
                            '${Strings.bet.toUpperCase()} ${seat.streetBet}',
                            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: text),
                          ),
                        ],
                      ],
                    ),
                    if (tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: BrutalMetrics.gapXs),
                      Wrap(spacing: BrutalMetrics.gapXs, runSpacing: BrutalMetrics.gapXs, children: tags),
                    ],
                  ],
                ),
              ),
              if (isActive && turnFraction != null)
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: text, width: BrutalMetrics.border),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: turnFraction!.clamp(0.0, 1.0),
                    child: ColoredBox(color: text, child: const SizedBox.expand()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _semantics() {
    final parts = <String>[if (seatNumber != null) Strings.seatLabel(seatNumber!), seat.name, '${seat.chips} chips'];
    if (seat.streetBet > 0) parts.add('bet ${seat.streetBet}');
    if (isActive) parts.add('acting');
    if (seat.hasFolded) parts.add('folded');
    if (seat.isAllIn) parts.add('all in');
    if (seat.isSittingOut) parts.add('away');
    if (!seat.isConnected) parts.add('offline');
    return parts.join(', ');
  }
}
