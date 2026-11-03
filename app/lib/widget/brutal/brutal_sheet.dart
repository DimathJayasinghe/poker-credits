import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Shows a bordered panel that slides up from the bottom with the `base` motion.
Future<T?> showBrutalSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  final c = BrutalTheme.of(context).colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: c.ink.withValues(alpha: 0.6),
    sheetAnimationStyle: AnimationStyle(
      duration: BrutalTheme.duration(context, BrutalMetrics.base),
      reverseDuration: BrutalTheme.duration(context, BrutalMetrics.fast),
      curve: Curves.easeOut,
    ),
    builder: (context) => BrutalSheet(title: title, child: builder(context)),
  );
}

/// Sheet panel; use [showBrutalSheet] to show it.
class BrutalSheet extends StatelessWidget {
  const BrutalSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.paper,
              border: Border(
                top: BorderSide(color: c.ink, width: BrutalMetrics.borderHeavy),
                left: BorderSide(color: c.ink, width: BrutalMetrics.borderHeavy),
                right: BorderSide(color: c.ink, width: BrutalMetrics.borderHeavy),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    color: c.ink,
                    padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c.paper),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(BrutalMetrics.gapM), child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
