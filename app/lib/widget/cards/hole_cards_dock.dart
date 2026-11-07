import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Your two cards, face down until you look. A tap flips them; on a table that others can see
/// ([pressToPeek]) they show only while a finger is held on them, so a glance never leaves them
/// open on a shared screen.
class HoleCardsDock extends StatefulWidget {
  const HoleCardsDock({
    super.key,
    required this.cards,
    required this.faceUp,
    required this.onToggle,
    this.pressToPeek = false,
    this.size = CardSize.hero,
    this.fourColour = false,
    this.showHint = true,
    this.verticalPadding = BrutalMetrics.gapS,
  });

  /// Null = no cards (folded, between hands, or not yet dealt).
  final List<PokerCard>? cards;
  final bool faceUp;
  final VoidCallback onToggle;
  final bool pressToPeek;
  final CardSize size;
  final bool fourColour;

  /// The "tap to show" line under the cards; left out where the screen is short (the semantics
  /// hint stays).
  final bool showHint;

  /// Space above and below the cards; a short screen asks for less.
  final double verticalPadding;

  @override
  State<HoleCardsDock> createState() => _HoleCardsDockState();
}

class _HoleCardsDockState extends State<HoleCardsDock> {
  bool _held = false;

  /// Held fingers only count on a shared table; otherwise [HoleCardsDock.faceUp] decides. A screen
  /// reader's own toggle sets [HoleCardsDock.faceUp] in both modes.
  bool get _open => widget.cards != null && (widget.faceUp || (widget.pressToPeek && _held));

  void _hold(bool value) {
    if (!widget.pressToPeek || _held == value) return;
    setState(() => _held = value);
  }

  @override
  void didUpdateWidget(HoleCardsDock old) {
    super.didUpdateWidget(old);
    // New cards or a table that is no longer shared never inherit an open hand.
    if (old.cards != widget.cards && _held) _held = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final cards = widget.cards;
    final hint = cards == null
        ? Strings.noCards
        : widget.faceUp
        ? Strings.tapToHide
        : widget.pressToPeek
        ? Strings.holdToLook
        : Strings.tapToShow;
    final label = cards == null ? Strings.noCards : (_open ? Strings.yourCards : Strings.cardsHiddenSemantics);
    return Semantics(
      container: true,
      button: cards != null,
      label: label,
      hint: hint,
      excludeSemantics: true,
      onTap: cards == null ? null : widget.onToggle,
      // A raw pointer listener drives the hold-to-look: a gesture recogniser would be cancelled by
      // the long-press timeout and the cards would turn back over under a finger that is still down.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _hold(true),
        onPointerUp: (_) => _hold(false),
        onPointerCancel: (_) => _hold(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cards == null || widget.pressToPeek ? null : widget.onToggle,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < 2; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: BrutalMetrics.gapS),
                        cards == null
                            ? _EmptySlot(widget.size)
                            : FlipCard(card: cards[i], faceUp: _open, size: widget.size, fourColour: widget.fourColour),
                      ],
                    ],
                  ),
                ),
                if (widget.showHint) ...<Widget>[
                  const SizedBox(height: BrutalMetrics.gapXs),
                  ExcludeSemantics(
                    child: Text(
                      hint.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: c.muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card that turns over: it narrows to a line, changes face, and widens again. With reduced
/// motion it simply changes.
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.card, required this.faceUp, this.size = CardSize.hero, this.fourColour = false});

  final PokerCard card;
  final bool faceUp;
  final CardSize size;
  final bool fourColour;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: faceUp ? 1 : 0),
      duration: BrutalTheme.duration(context, BrutalMetrics.flip),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final showFace = t > 0.5;
        final squash = (2 * t - 1).abs().clamp(0.02, 1.0);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(squash, 1, 1),
          child: PlayingCard(card: showFace ? card : null, size: size, fourColour: fourColour),
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot(this.size);

  final CardSize size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: BrutalTheme.of(context).colors.muted, width: 1),
      ),
    ),
  );
}
