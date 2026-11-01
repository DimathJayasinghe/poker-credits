import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Theme extension carrying the brutalist tokens, read with [BrutalTheme.of].
@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({required this.colors});

  final BrutalColors colors;

  static BrutalTheme of(BuildContext context) => Theme.of(context).extension<BrutalTheme>() ?? const BrutalTheme(colors: BrutalColors.light);

  /// Whether the OS asked for reduced motion; animations then use zero duration.
  static Duration duration(BuildContext context, Duration normal) => MediaQuery.of(context).disableAnimations ? Duration.zero : normal;

  @override
  BrutalTheme copyWith({BrutalColors? colors}) => BrutalTheme(colors: colors ?? this.colors);

  @override
  BrutalTheme lerp(ThemeExtension<BrutalTheme>? other, double t) => t < 0.5 || other is! BrutalTheme ? this : other;
}

/// Builds the app [ThemeData]. Material is only plumbing (Scaffold, Navigator, text input);
/// visible UI uses widgets from widget/brutal/.
ThemeData buildBrutalTheme(BrutalColors c, Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: BrutalFonts.mono,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.signal,
      onPrimary: BrutalColors.light.ink,
      secondary: c.info,
      onSecondary: c.onInfo,
      error: c.danger,
      onError: c.onDanger,
      surface: c.paper,
      onSurface: c.ink,
    ),
    textTheme: Typography.blackMountainView.apply(fontFamily: BrutalFonts.mono, bodyColor: c.ink, displayColor: c.ink),
  );
  return base.copyWith(extensions: <ThemeExtension<dynamic>>[BrutalTheme(colors: c)]);
}
