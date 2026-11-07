import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/flip_in.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Everyone's cards at the end of a hand and who won what. It draws only what the server sent:
/// the revealed hands, the board and how each pot was paid.
class ShowdownPanel extends StatelessWidget {
  const ShowdownPanel({
    super.key,
    required this.reveals,
    required this.result,
    this.board = const <PokerCard>[],
    this.fourColour = false,
    this.myPlayerId,
    this.animate = false,
  });

  /// The hands turn over one player after the other.
  final bool animate;

  final List<Reveal> reveals;
  final HandResult result;

  /// Shown above the hands when the screen does not already show the board.
  final List<PokerCard> board;
  final bool fourColour;

  /// Marks the viewer's own line.
  final String? myPlayerId;

  Set<String> get _winners => <String>{for (final pot in result.pots) ...pot.winnerPlayerIds};

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final winners = _winners;
    return BrutalCard(
      header: Strings.showdownTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (board.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: BoardView(shown: board, size: CardSize.mini, fourColour: fourColour),
            ),
            const SizedBox(height: BrutalMetrics.gapM),
          ],
          if (result.uncontested)
            Text(Strings.wonUncontested, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted))
          else
            for (var i = 0; i < reveals.length; i++) ...<Widget>[
              _RevealLine(
                reveal: reveals[i],
                won: winners.contains(reveals[i].playerId),
                mine: reveals[i].playerId == myPlayerId,
                fourColour: fourColour,
                // Players turn their cards over one after the other, about half a second apart.
                delay: animate ? (BrutalMetrics.flip + BrutalMetrics.dealGap) * i : null,
              ),
              const SizedBox(height: BrutalMetrics.gapM),
            ],
          for (var i = 0; i < result.pots.length; i++) _PotLine(pot: result.pots[i], main: i == 0, number: i, myPlayerId: myPlayerId),
        ],
      ),
    );
  }
}

class _RevealLine extends StatelessWidget {
  const _RevealLine({required this.reveal, required this.won, required this.mine, required this.fourColour, this.delay});

  /// Null = no animation.
  final Duration? delay;

  final Reveal reveal;
  final bool won;
  final bool mine;
  final bool fourColour;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    // The hole cards that are part of the best five stay bright, the others step back.
    final best = reveal.bestFive.toSet();
    final dimmed = <int>{
      for (var i = 0; i < reveal.cards.length; i++)
        if (!best.contains(reveal.cards[i])) i,
    };
    return Semantics(
      container: true,
      label: '${reveal.name}, ${handCategoryText(reveal.category)}${won ? ', ${Strings.winnerTag}' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: BrutalMetrics.gapS,
            runSpacing: BrutalMetrics.gapXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                reveal.name.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 14, color: c.ink),
              ),
              if (mine) const BrutalTag(Strings.youTag),
              if (won) const BrutalTag(Strings.winnerTag, kind: BrutalTagKind.signal),
              Text(handCategoryText(reveal.category), style: TextStyle(fontSize: 13, color: c.muted)),
            ],
          ),
          const SizedBox(height: BrutalMetrics.gapXs),
          ExcludeSemantics(
            child: delay == null
                ? CardRow(cards: reveal.cards, fourColour: fourColour, dimmed: dimmed)
                : _FlipRow(cards: reveal.cards, delay: delay!, fourColour: fourColour, dimmed: dimmed),
          ),
          const SizedBox(height: BrutalMetrics.gapXs),
          ExcludeSemantics(
            child: delay == null
                ? CardRow(cards: reveal.bestFive, fourColour: fourColour, liftedIndexes: <int>{for (var i = 0; i < reveal.bestFive.length; i++) i})
                : _FlipRow(
                    cards: reveal.bestFive,
                    delay: delay! + BrutalMetrics.flip,
                    fourColour: fourColour,
                    lifted: <int>{for (var i = 0; i < reveal.bestFive.length; i++) i},
                  ),
          ),
        ],
      ),
    );
  }
}

/// A row of mini cards that turn over one after the other, starting after [delay].
class _FlipRow extends StatelessWidget {
  const _FlipRow({required this.cards, required this.delay, required this.fourColour, this.dimmed = const <int>{}, this.lifted = const <int>{}});

  final List<PokerCard> cards;
  final Duration delay;
  final bool fourColour;
  final Set<int> dimmed;
  final Set<int> lifted;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: PlayingCard.liftBy),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 4),
              FlipIn(
                key: ValueKey<String>('${cards[i]}-$i-${delay.inMilliseconds}'),
                card: cards[i],
                delay: delay + BrutalMetrics.dealGap * i ~/ 2,
                size: CardSize.mini,
                fourColour: fourColour,
                dim: dimmed.contains(i),
                lifted: lifted.contains(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PotLine extends StatelessWidget {
  const _PotLine({required this.pot, required this.main, required this.number, required this.myPlayerId});

  final PotResult pot;
  final bool main;
  final int number;
  final String? myPlayerId;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final label = main ? Strings.mainPot : Strings.sidePotNumber(number);
    return Padding(
      padding: const EdgeInsets.only(top: BrutalMetrics.gapXs),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.line, width: BrutalMetrics.border),
          ),
        ),
        padding: const EdgeInsets.only(top: BrutalMetrics.gapS),
        child: Semantics(
          container: true,
          label: '$label ${pot.amount}: ${pot.shares.map((s) => '${s.name} ${s.amount}').join(', ')}',
          excludeSemantics: true,
          child: Wrap(
            spacing: BrutalMetrics.gapS,
            runSpacing: BrutalMetrics.gapXs,
            children: <Widget>[
              Text(
                '${label.toUpperCase()} ${pot.amount}',
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, color: c.ink),
              ),
              for (final share in pot.shares)
                Text(
                  '${share.name} +${share.amount}',
                  style: TextStyle(fontSize: 13, fontWeight: share.playerId == myPlayerId ? FontWeight.bold : FontWeight.normal, color: c.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
