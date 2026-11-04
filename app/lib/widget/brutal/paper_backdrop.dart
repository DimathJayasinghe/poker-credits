import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';

/// Whether the paper grain is drawn. Provided once above the navigator from the Settings
/// switch; where nothing provides it (tests, goldens) the grain is on.
class BrutalTexture extends InheritedWidget {
  const BrutalTexture({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BrutalTexture>()?.enabled ?? true;

  @override
  bool updateShouldNotify(BrutalTexture oldWidget) => oldWidget.enabled != enabled;
}

/// A screen: `paper` colour with the grain tiled behind the content, never over it.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({super.key, required this.body, this.safeArea = true});

  final Widget body;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final grain = BrutalTexture.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(
          image: grain
              ? DecorationImage(
                  image: const AssetImage('assets/images/grain.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: c.grainOpacity,
                  colorFilter: ColorFilter.mode(c.grain, BlendMode.srcIn),
                )
              : null,
        ),
        child: SizedBox.expand(child: safeArea ? SafeArea(child: body) : body),
      ),
    );
  }
}
