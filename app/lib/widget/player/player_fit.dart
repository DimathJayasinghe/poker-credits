import 'dart:ui' show Size;

import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';

/// How tightly the player's controller is drawn, from the height it has to work with.
///
/// A game's controls must be on screen without scrolling, on a small phone as on a big one. The
/// bottom block (my cards, the action buttons, the pause row) is never allowed to leave the
/// screen; what gives way is the size of the numbers and cards above it.
class PlayerFit {
  const PlayerFit._({
    required this.name,
    required this.numeral,
    required this.stackPad,
    required this.card,
    required this.hint,
    required this.button,
    required this.secondary,
    required this.gap,
    required this.turn,
    required this.pot,
    required this.compactTurn,
  });

  final String name;

  /// Size of the big chip count.
  final double numeral;

  /// Space above and below the chip count block.
  final double stackPad;

  /// My two cards.
  final CardSize card;

  /// The "tap to show" line under my cards.
  final bool hint;

  /// Height of the fold, call and raise buttons.
  final double button;

  /// Height of the pause row (and, in a hosted game, the top-up row).
  final double secondary;

  /// Space between the blocks of the bottom area.
  final double gap;

  /// Scale of the "your turn" block (1 = full size).
  final double turn;

  /// Size of the pot figure.
  final double pot;

  /// The turn and the pot share one line, and the last-action line is left out.
  final bool compactTurn;

  /// Plenty of room: a big phone, or a tablet.
  static const PlayerFit roomy = PlayerFit._(
    name: 'roomy',
    numeral: 52,
    stackPad: 12,
    card: CardSize.hero,
    hint: true,
    button: BrutalMetrics.tapPlayer,
    secondary: 56,
    gap: BrutalMetrics.gapM,
    turn: 0.85,
    pot: 28,
    compactTurn: false,
  );

  /// Most phones.
  static const PlayerFit snug = PlayerFit._(
    name: 'snug',
    numeral: 44,
    stackPad: 8,
    card: CardSize.hand,
    hint: true,
    button: 52,
    secondary: 52,
    gap: BrutalMetrics.gapS,
    turn: 0.7,
    pot: 24,
    compactTurn: false,
  );

  /// A small phone with its system bars, or a large text size.
  static const PlayerFit tight = PlayerFit._(
    name: 'tight',
    numeral: 36,
    stackPad: 4,
    card: CardSize.board,
    hint: false,
    button: 48,
    secondary: 48,
    gap: BrutalMetrics.gapS,
    turn: 0.55,
    pot: 20,
    compactTurn: true,
  );

  /// The least height the upright layout needs: the top bar, my chips, the opponents, my cards,
  /// the buttons and the pause row, drawn at the [tight] tier, plus a little for the middle.
  static const double minHeight = 555;

  /// The least height the sideways layout needs (a phone held in landscape).
  static const double minWideHeight = 330;

  /// A phone turned on its side: much wider than tall. The controller then puts the chips and the
  /// table on the left and my cards and the buttons on the right, instead of stacking them.
  static bool isWide(Size size) => size.height < 600 && size.width >= size.height * 1.3;

  /// The tier for the upright layout. [height] is what the controller may use (system bars already
  /// taken off); a bigger [textScale] counts as less height, since the text takes more of it.
  static PlayerFit forHeight(double height, {double textScale = 1}) {
    final effective = height / (textScale < 1 ? 1 : textScale);
    if (effective >= 885) return roomy;
    if (effective >= 745) return snug;
    return tight;
  }

  /// The tier for the sideways layout, from its height.
  static PlayerFit forWide(double height) => height >= 520 ? roomy : (height >= 430 ? snug : tight);

  /// The biggest text scale the controller draws at [height], so everything still fits: a game
  /// has no room to scroll. Below [minHeight] there is no room for more than the normal size.
  static double maxTextScale(double height, {bool wide = false}) {
    final need = wide ? minWideHeight : minHeight;
    return height <= need ? 1 : height / need;
  }
}
