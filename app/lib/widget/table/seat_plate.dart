import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/table/felt_layout.dart';
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
    this.cards,
    this.isWinner = false,
  });

  final SeatView seat;
  final bool isActive;
  final bool isDealer;
  final bool isSmallBlind;
  final bool isBigBlind;

  /// Fraction of the turn clock left (1 = full), drawn as a bar under the plate.
  final double? turnFraction;
  final VoidCallback? onTap;

  /// Virtual cards: two cards on the plate. Null entries are face down; null = none (folded, or a
  /// room with real cards).
  final List<PokerCard?>? cards;

  /// Won a pot at the last showdown.
  final bool isWinner;

  /// Height of the strip under the plate that holds the turn clock.
  static const double turnBarHeight = 10;

  /// Shown at the right of the name between hands, so the screen can be checked against who sits
  /// where in the room. Hidden during a hand.
  final int? seatNumber;

  @override
  Widget build(BuildContext context) {
    // A plate given a short, fixed height (the table's grid on a phone) draws itself denser; given
    // none (the oval, or on its own) it is [FeltLayout.plateHeight] tall.
    return LayoutBuilder(
      builder: (context, box) {
        final given = box.hasTightHeight ? box.maxHeight : null;
        if (given != null && given < FeltLayout.plateHeightFor(context) * 0.9) return _dense(context, given);
        return _standard(context);
      },
    );
  }

  /// The plate for a phone: the name and the tags above the chips, the cards at the right, in the
  /// [height] it is given. Everything the roomy plate shows is here, at a smaller size.
  Widget _dense(BuildContext context, double height) {
    final c = BrutalTheme.of(context).colors;
    final Color fill = isActive ? c.accent : c.surface;
    final Color text = isActive ? c.onAccent : c.ink;
    final dim = seat.hasFolded || seat.isSittingOut;
    // A plate with height to spare gets bigger type and bigger cards.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final grow = ((height / scale - 52) / 36).clamp(0.0, 1.0);
    final tall = height >= 78 * scale;
    final nameStyle = TextStyle(
      fontFamily: BrutalFonts.display,
      fontSize: 15 + 4 * grow,
      height: 1.1,
      color: dim && !isActive ? c.muted : text,
      decoration: seat.hasFolded ? TextDecoration.lineThrough : null,
      decorationThickness: 3,
    );
    final positions = <Widget>[
      if (isWinner) const BrutalTag(Strings.winsTag, kind: BrutalTagKind.signal, compact: true),
      if (isDealer) const BrutalTag(Strings.dealer, compact: true),
      if (isSmallBlind) const BrutalTag(Strings.smallBlindTag, kind: BrutalTagKind.info, compact: true),
      if (isBigBlind) const BrutalTag(Strings.bigBlindTag, kind: BrutalTagKind.info, compact: true),
    ];
    final states = <Widget>[
      if (seat.isAllIn) const BrutalTag(Strings.allIn, kind: BrutalTagKind.danger, compact: true),
      if (seat.hasFolded) const BrutalTag(Strings.folded, compact: true),
      if (seat.isSittingOut) const BrutalTag(Strings.sittingOut, compact: true),
      if (!seat.isConnected) const BrutalTag(Strings.offline, compact: true),
    ];
    Widget row(List<Widget> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < items.length; i++) ...<Widget>[if (i > 0) const SizedBox(width: BrutalMetrics.gapXs), items[i]],
      ],
    );
    final bet = seat.streetBet > 0
        ? Text(
            '${Strings.bet.toUpperCase()} ${seat.streetBet}',
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 11, color: text),
          )
        : null;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(seat.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
            ),
            if (seatNumber != null) ...<Widget>[
              const SizedBox(width: BrutalMetrics.gapXs),
              Text(
                '${seatNumber!}',
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 11, color: isActive ? text : c.muted),
              ),
            ],
            if (positions.isNotEmpty) ...<Widget>[
              const SizedBox(width: BrutalMetrics.gapXs),
              Expanded(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row(positions)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            BrutalNumber(seat.chips, size: 20 + 10 * grow, color: dim && !isActive ? c.muted : text),
            if (bet != null || (states.isNotEmpty && !tall)) ...<Widget>[
              const SizedBox(width: BrutalMetrics.gapS),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: row(<Widget>[?bet, if (!tall) ...states]),
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
        // A tall plate has the height for the state tags on a line of their own, at full size.
        if (tall && states.isNotEmpty) ...<Widget>[
          const SizedBox(height: BrutalMetrics.gapXs),
          Align(alignment: Alignment.centerLeft, child: row(states)),
        ],
      ],
    );
    final turnBar = isActive && turnFraction != null;
    return Semantics(
      container: true,
      label: _semantics(),
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalPressable(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          height: height,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: c.line, width: pressed ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapS, BrutalMetrics.gapXs, BrutalMetrics.gapS, BrutalMetrics.gapXs),
                  child: LayoutBuilder(
                    builder: (context, area) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: area.maxWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(child: left),
                            if (cards != null) ...<Widget>[
                              const SizedBox(width: BrutalMetrics.gapXs),
                              CardRow(cards: cards!, size: tall ? CardSize.mini : CardSize.tiny, gap: 3, alignment: MainAxisAlignment.end),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The turn clock is a thin strip along the bottom edge, and only there when it runs.
              Container(
                height: 5,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: turnBar ? text : Colors.transparent, width: BrutalMetrics.border),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: turnBar
                    ? FractionallySizedBox(
                        widthFactor: turnFraction!.clamp(0.0, 1.0),
                        child: ColoredBox(color: text, child: const SizedBox.expand()),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standard(BuildContext context) {
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
      if (isWinner) const BrutalTag(Strings.winsTag, kind: BrutalTagKind.signal),
      if (isDealer) const BrutalTag(Strings.dealer),
      if (isSmallBlind) const BrutalTag(Strings.smallBlindTag, kind: BrutalTagKind.info),
      if (isBigBlind) const BrutalTag(Strings.bigBlindTag, kind: BrutalTagKind.info),
      if (seat.isAllIn) const BrutalTag(Strings.allIn, kind: BrutalTagKind.danger),
      if (seat.hasFolded) const BrutalTag(Strings.folded),
      if (seat.isSittingOut) const BrutalTag(Strings.sittingOut),
      if (!seat.isConnected) const BrutalTag(Strings.offline),
    ];
    final content = Column(
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
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: isActive ? text : c.muted),
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${Strings.bet.toUpperCase()} ${seat.streetBet}',
                    style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: text),
                  ),
                ),
              ),
            ],
            if (cards != null) ...<Widget>[
              const Spacer(),
              const SizedBox(width: BrutalMetrics.gapXs),
              CardRow(cards: cards!, size: CardSize.tiny, gap: 3, alignment: MainAxisAlignment.end),
            ],
          ],
        ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: BrutalMetrics.gapXs),
          Wrap(spacing: BrutalMetrics.gapXs, runSpacing: BrutalMetrics.gapXs, children: tags),
        ],
      ],
    );
    return Semantics(
      container: true,
      label: _semantics(),
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalPressable(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          // Every plate has the same height, whatever it shows, so a row of plates always lines up.
          height: FeltLayout.plateHeightFor(context),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: c.line, width: pressed ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapS, BrutalMetrics.gapS, BrutalMetrics.gapS, BrutalMetrics.gapXs),
                  // Content that is taller than the plate (a big text size, many tags) shrinks to fit
                  // instead of changing the plate's height.
                  child: LayoutBuilder(
                    builder: (context, box) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: SizedBox(width: box.maxWidth, child: content),
                    ),
                  ),
                ),
              ),
              // The turn clock has a strip of its own so the plate does not grow when it is shown.
              Container(
                height: turnBarHeight,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: isActive && turnFraction != null ? text : Colors.transparent, width: BrutalMetrics.border),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: isActive && turnFraction != null
                    ? FractionallySizedBox(
                        widthFactor: turnFraction!.clamp(0.0, 1.0),
                        child: ColoredBox(color: text, child: const SizedBox.expand()),
                      )
                    : null,
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
    if (isWinner) parts.add(Strings.winsTag.toLowerCase());
    final shown = cards;
    if (shown != null && shown.every((c) => c != null)) {
      parts.add(shown.map((c) => cardName(c!)).join(' and '));
    } else if (shown != null) {
      parts.add(Strings.hasCards);
    }
    if (seat.isSittingOut) parts.add('away');
    if (!seat.isConnected) parts.add('offline');
    return parts.join(', ');
  }
}
