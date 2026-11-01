import 'package:flutter/widgets.dart';

/// Design tokens for the neo-brutalist UI (docs/UI_DESIGN.md section 2, ADR-013).
///
/// This is the only file allowed to contain colour literals (enforced by tool/check_web_safe.sh).
@immutable
class BrutalColors {
  const BrutalColors({
    required this.ink,
    required this.paper,
    required this.felt,
    required this.signal,
    required this.danger,
    required this.info,
    required this.chip,
    required this.muted,
    required this.onFelt,
    required this.onDanger,
    required this.onInfo,
  });

  /// Text, borders and shadows.
  final Color ink;

  /// Backgrounds.
  final Color paper;

  /// Table surface.
  final Color felt;

  /// Active turn and primary action highlight.
  final Color signal;

  /// Fold, all-in and errors.
  final Color danger;

  /// Call, links and connection state.
  final Color info;

  /// Chip amounts and pot.
  final Color chip;

  /// Secondary text. Keep at 4.5:1 contrast or better on its background.
  final Color muted;

  final Color onFelt;
  final Color onDanger;
  final Color onInfo;

  static const BrutalColors light = BrutalColors(
    ink: Color(0xFF0A0A0A),
    paper: Color(0xFFF3F0E6),
    felt: Color(0xFF0F6B3A),
    signal: Color(0xFFFFE600),
    danger: Color(0xFFFF3B1D),
    info: Color(0xFF2B50FF),
    chip: Color(0xFFFF9F1C),
    muted: Color(0xFF6B6B6B),
    onFelt: Color(0xFFF3F0E6),
    onDanger: Color(0xFF0A0A0A),
    onInfo: Color(0xFFFFFFFF),
  );

  /// Default for the Table screen.
  static const BrutalColors dark = BrutalColors(
    ink: Color(0xFFF3F0E6),
    paper: Color(0xFF0A0A0A),
    felt: Color(0xFF0F6B3A),
    signal: Color(0xFFFFE600),
    danger: Color(0xFFFF5A3C),
    info: Color(0xFF6B83FF),
    chip: Color(0xFFFF9F1C),
    muted: Color(0xFFA8A8A8),
    onFelt: Color(0xFFF3F0E6),
    onDanger: Color(0xFF0A0A0A),
    onInfo: Color(0xFF0A0A0A),
  );
}

/// Shape, spacing and motion tokens.
abstract final class BrutalMetrics {
  /// Corner radius is always zero.
  static const double radius = 0;

  /// Standard border width.
  static const double border = 3;

  /// Border width for primary buttons and the pot.
  static const double borderHeavy = 4;

  /// Hard shadow offset (no blur).
  static const double shadow = 4;

  /// Hard shadow offset for the pot block.
  static const double shadowHeavy = 8;

  /// 8-point spacing grid.
  static const double gapXs = 4;
  static const double gapS = 8;
  static const double gapM = 16;
  static const double gapL = 24;
  static const double gapXl = 32;

  /// Minimum tap target on the Player screen.
  static const double tapPlayer = 56;

  /// Minimum tap target elsewhere.
  static const double tap = 48;

  static const Duration fast = Duration(milliseconds: 80);
  static const Duration base = Duration(milliseconds: 150);
  static const Duration max = Duration(milliseconds: 300);
}

/// Bundled font families (declared in pubspec.yaml). Never downloaded at runtime.
abstract final class BrutalFonts {
  static const String display = 'ArchivoBlack';
  static const String mono = 'SpaceMono';
}
