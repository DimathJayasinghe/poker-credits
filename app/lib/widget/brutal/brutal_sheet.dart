import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';

/// The widest a sheet gets on this screen: a phone on its side has width and no height, so its
/// sheets are wider and can lay their contents out in columns.
double wideSheetWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= 600 && size.height < 460 ? 760 : 560;
}

/// Shows a bordered panel that slides up from the bottom with the `base` motion.
///
/// [maxWidth] is the widest the panel gets. With [scrolls] false the panel does not scroll its
/// body: the body is given the height that is left and decides itself what scrolls (a list), so
/// its main button can stay in place under the list.
Future<T?> showBrutalSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  double maxWidth = 560,
  bool scrolls = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The platform default caps a sheet at 640; a sheet that asks for more gets it.
    constraints: BoxConstraints(maxWidth: maxWidth),
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: BrutalColors.dark.paper.withValues(alpha: 0.7),
    sheetAnimationStyle: AnimationStyle(
      duration: BrutalTheme.duration(context, BrutalMetrics.base),
      reverseDuration: BrutalTheme.duration(context, BrutalMetrics.fast),
      curve: Curves.easeOut,
    ),
    builder: (context) => BrutalSheet(title: title, maxWidth: maxWidth, scrolls: scrolls, child: builder(context)),
  );
}

/// Sheet panel; use [showBrutalSheet] to show it.
///
/// The header never scrolls and always carries a CLOSE cell: on a short screen the sheet can fill
/// the whole display, and then there is no backdrop left to tap and no hint of how to get back.
class BrutalSheet extends StatelessWidget {
  const BrutalSheet({super.key, required this.title, required this.child, this.maxWidth = 560, this.scrolls = true});

  final String title;
  final Widget child;
  final double maxWidth;
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final media = MediaQuery.of(context);
    // Leave a strip of backdrop above the sheet whenever the screen is tall enough.
    final maxHeight = media.size.height - media.padding.top - (media.size.height > 520 ? BrutalMetrics.gapXl : 0);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                top: BorderSide(color: c.line, width: BrutalMetrics.borderHeavy),
                left: BorderSide(color: c.line, width: BrutalMetrics.border),
                right: BorderSide(color: c.line, width: BrutalMetrics.border),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: BrutalFonts.mono,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 2,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const _CloseCell(),
                    ],
                  ),
                ),
                Flexible(
                  child: scrolls
                      ? SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                          child: Padding(padding: const EdgeInsets.all(BrutalMetrics.gapM), child: child),
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            BrutalMetrics.gapM,
                            BrutalMetrics.gapM,
                            BrutalMetrics.gapM,
                            BrutalMetrics.gapM + media.viewInsets.bottom,
                          ),
                          child: child,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "CLOSE ×" at the right end of a sheet's header.
class _CloseCell extends StatelessWidget {
  const _CloseCell();

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      button: true,
      label: Strings.close,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: BrutalPressable(
        onTap: () => Navigator.of(context).maybePop(),
        builder: (context, pressed) {
          final color = pressed ? c.paper : c.ink;
          return AnimatedContainer(
            duration: BrutalTheme.duration(context, BrutalMetrics.fast),
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
            decoration: BoxDecoration(
              color: pressed ? c.ink : c.surface,
              border: Border(
                left: BorderSide(color: c.line, width: BrutalMetrics.border),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  Strings.close.toUpperCase(),
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 17, letterSpacing: 0.8, color: color),
                ),
                const SizedBox(width: BrutalMetrics.gapS),
                Text(
                  '×',
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 26, height: 1, color: color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
