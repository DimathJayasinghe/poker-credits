import 'package:flutter/widgets.dart';

/// Design tokens for the editorial UI (docs/UI_DESIGN.md section 2, ADR-015).
///
/// This is the only file allowed to contain colour literals (enforced by tool/check_web_safe.sh).
@immutable
class BrutalColors {
  const BrutalColors({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.accent,
    required this.onAccent,
    required this.felt,
    required this.onFelt,
    required this.chip,
    required this.onChip,
    required this.muted,
    required this.grain,
    required this.grainOpacity,
    this.cardFace = const Color(0xFFFFFAF0),
    this.cardBack = const Color(0xFF8C1F0C),
    this.cardBackMark = const Color(0xFFF2D9B0),
    this.suitRed = const Color(0xFF9E2210),
    this.suitBlack = const Color(0xFF15120F),
    this.suitGreen = const Color(0xFF14602F),
    this.suitBlue = const Color(0xFF1A3F8F),
  });

  /// Page background, under the grain.
  final Color paper;

  /// Raised cells: cards, inputs, sheets.
  final Color surface;

  /// Text, lines and the ink-filled buttons.
  final Color ink;

  /// Whose turn it is, the primary action, errors. Use for fills and large type only: small text
  /// in this colour can fall under 4.5:1 once the grain is laid over the background.
  final Color accent;

  /// Text on [accent].
  final Color onAccent;

  /// The table panel.
  final Color felt;

  /// Text on [felt].
  final Color onFelt;

  /// Pot block and chip marks.
  final Color chip;

  /// Text on [chip]: always dark.
  final Color onChip;

  /// Secondary text. At least 4.5:1 on [paper] and [surface].
  final Color muted;

  /// Colour the noise tile is painted in.
  final Color grain;

  /// How strongly the noise tile shows.
  final double grainOpacity;

  // Playing cards are drawn like real ones: a light face in both themes, so a card reads the
  // same on paper, in the dark and on the felt. The edge is always an ink hairline.

  /// The face of a card.
  final Color cardFace;

  /// The back of a card.
  final Color cardBack;

  /// The pattern on the back of a card.
  final Color cardBackMark;

  /// Hearts and diamonds. At least 7:1 on [cardFace].
  final Color suitRed;

  /// Spades and clubs.
  final Color suitBlack;

  /// Clubs in the four-colour deck.
  final Color suitGreen;

  /// Diamonds in the four-colour deck.
  final Color suitBlue;

  /// Every hairline.
  Color get line => ink;

  // The earlier palette had three loud hues. Meaning now rides on position and label (docs section
  // 2), so these map onto the new colours and old call sites keep working.

  /// The acting seat and the control that acts. Same as [accent].
  Color get signal => accent;

  /// Fold, all-in and errors. Same as [accent].
  Color get danger => accent;

  /// Text on [danger].
  Color get onDanger => onAccent;

  /// Call and check: the ink-filled button.
  Color get info => ink;

  /// Text on [info].
  Color get onInfo => paper;

  /// Text on [signal].
  Color get onSignal => onAccent;

  /// Paper theme.
  static const BrutalColors light = BrutalColors(
    paper: Color(0xFFEFE5CF),
    surface: Color(0xFFF8F1E0),
    ink: Color(0xFF15120F),
    accent: Color(0xFFB52D14),
    onAccent: Color(0xFFFFF6E6),
    felt: Color(0xFF143A2B),
    onFelt: Color(0xFFF2E8D2),
    chip: Color(0xFFE8A23A),
    onChip: Color(0xFF15120F),
    muted: Color(0xFF5C5547),
    grain: Color(0xFF000000),
    grainOpacity: 0.07,
  );

  /// Night theme.
  static const BrutalColors dark = BrutalColors(
    paper: Color(0xFF12100F),
    surface: Color(0xFF1B1816),
    ink: Color(0xFFF2E8D2),
    accent: Color(0xFFFF5A36),
    onAccent: Color(0xFF12100F),
    felt: Color(0xFF0F2E22),
    onFelt: Color(0xFFF2E8D2),
    chip: Color(0xFFF0AE48),
    onChip: Color(0xFF15120F),
    muted: Color(0xFFA89F8D),
    grain: Color(0xFFFFFFFF),
    grainOpacity: 0.05,
  );
}

/// Shape, spacing and motion tokens.
abstract final class BrutalMetrics {
  /// Corner radius is always zero.
  static const double radius = 0;

  /// The hairline: every divider and cell border.
  static const double border = 1.5;

  /// The rule: the one underline or frame that anchors a screen, and the pot block.
  static const double borderHeavy = 3;

  /// There are no shadows in this look; kept at zero so older call sites draw nothing.
  static const double shadow = 0;
  static const double shadowHeavy = 0;

  /// Spacing grid.
  static const double gapXs = 4;
  static const double gapS = 8;
  static const double gapM = 16;
  static const double gapL = 24;
  static const double gapXl = 32;
  static const double gapXxl = 48;

  /// Minimum tap target on the Player screen.
  static const double tapPlayer = 56;

  /// Minimum tap target elsewhere.
  static const double tap = 48;

  /// Width from which navigation moves from a bottom bar to a side rail.
  static const double wide = 840;

  static const Duration fast = Duration(milliseconds: 90);
  static const Duration base = Duration(milliseconds: 160);
  static const Duration max = Duration(milliseconds: 280);
}

/// Bundled font families (declared in pubspec.yaml). Never downloaded at runtime.
abstract final class BrutalFonts {
  /// Condensed heavy face for titles and numerals.
  static const String display = 'Anton';

  /// Labels, body text and data.
  static const String mono = 'SpaceMono';

  /// Anton's digits are all one width except `1`, and it has no tabular figures, so live numbers
  /// go through `BrutalNumber`, which sets every digit in a box this wide (in em).
  static const double displayDigitEm = 0.494;
}
