import 'dart:ui' show Size;

import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';

/// How tightly the host's table is drawn, from the height it has to work with.
///
/// A game never scrolls (docs/UI_DESIGN.md "No scrolling"): the pot, every seat and every control
/// are on screen at once. What gives way as the screen gets smaller is the size of the seat
/// plates, the cards and the buttons, never whether they are there.
class TableFit {
  const TableFit._({
    required this.name,
    required this.plate,
    required this.minPlate,
    required this.button,
    required this.secondary,
    required this.gap,
    required this.pot,
    required this.boardCard,
    required this.dockCard,
    required this.qr,
    required this.note,
  });

  final String name;

  /// The tallest a seat plate in the grid gets, at text scale 1.
  final double plate;

  /// The shortest; below this the seats scroll inside their own box (the last resort).
  final double minPlate;

  /// Height of the main host button (start, begin showdown) and of the player's fold, call and raise.
  final double button;

  /// Height of the row of smaller host buttons.
  final double secondary;

  /// The space between blocks.
  final double gap;

  /// Size of the pot figure.
  final double pot;

  /// The community cards.
  final CardSize boardCard;

  /// The seated host's own two cards.
  final CardSize dockCard;

  /// The side of the join QR code in the lobby.
  final double qr;

  /// The note about what Undo can do: 0 = in full, 1 = one short line.
  final int note;

  bool get isRoomy => identical(this, TableFit.roomy);
  bool get isTight => identical(this, TableFit.tight);

  /// A big phone, a tablet or a desktop window.
  static const TableFit roomy = TableFit._(
    name: 'roomy',
    plate: 100,
    minPlate: 60,
    button: BrutalMetrics.tapPlayer,
    secondary: BrutalMetrics.tap,
    gap: BrutalMetrics.gapM,
    pot: 56,
    boardCard: CardSize.board,
    dockCard: CardSize.hand,
    qr: 168,
    note: 0,
  );

  /// Most phones.
  static const TableFit snug = TableFit._(
    name: 'snug',
    plate: 88,
    minPlate: 52,
    button: 52,
    secondary: 44,
    gap: BrutalMetrics.gapS,
    pot: 40,
    boardCard: CardSize.mini,
    dockCard: CardSize.board,
    qr: 136,
    note: 1,
  );

  /// A small phone with its system bars, or a phone on its side.
  static const TableFit tight = TableFit._(
    name: 'tight',
    plate: 60,
    minPlate: 44,
    button: 48,
    secondary: 44,
    gap: BrutalMetrics.gapS,
    pot: 34,
    boardCard: CardSize.mini,
    dockCard: CardSize.board,
    qr: 112,
    note: 1,
  );

  /// The tier for a screen whose usable height (system bars already taken off) is [height]. A bigger
  /// [textScale] counts as less height, since the text takes more of it.
  static TableFit forHeight(double height, {double textScale = 1, double width = 0}) {
    final effective = height / (textScale < 1 ? 1 : textScale);
    // A tablet or a window has the width for a roomy table at a moderate height; a phone needs
    // the height of a big one for the same cards, buttons and ten seats.
    if (effective >= (width >= 600 ? 600 : 880)) return roomy;
    if (effective >= 600) return snug;
    return tight;
  }

  /// The tier for a phone held on its side, from its height.
  static TableFit forWide(double height, {double textScale = 1}) {
    final effective = height / (textScale < 1 ? 1 : textScale);
    return effective >= 420 ? snug : tight;
  }

  /// A phone turned on its side: much wider than tall. The controls then sit in a pane at the right.
  static bool isWide(Size size) => size.width >= 600 && size.height < 460;

  /// The least usable height the upright layout needs at the [tight] tier, and the sideways one.
  static const double minHeight = 560;
  static const double minWideHeight = 330;

  /// The biggest text scale the table draws at [height], so everything still fits: a game has no
  /// room to scroll. At or below the least height there is no room for more than the normal size.
  static double maxTextScale(double height, {bool wide = false}) {
    final need = wide ? minWideHeight : minHeight;
    return height <= need ? 1 : height / need;
  }
}
