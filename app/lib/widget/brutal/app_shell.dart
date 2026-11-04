import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';

/// One cell of the top bar: a square tap target between two hairlines.
class TopBarCell extends StatelessWidget {
  const TopBarCell({super.key, required this.child, this.onTap, this.semanticLabel, this.width = 56});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final cell = Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: child,
    );
    if (onTap == null) return cell;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: cell),
    );
  }
}

/// The bar across the top: the mark, the screen's name and any action cells, all on one grid.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title, this.actions = const <Widget>[], this.onBack});

  final String title;
  final List<Widget> actions;

  /// When set, the first cell is a back arrow instead of the mark.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (onBack == null)
            Container(
              width: 56,
              alignment: Alignment.center,
              child: Text(
                'PC',
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 22, height: 1, color: c.ink),
              ),
            )
          else
            Semantics(
              button: true,
              label: Strings.back,
              excludeSemantics: true,
              onTap: onBack,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: SizedBox(
                  width: 56,
                  child: Center(
                    child: Transform.rotate(
                      angle: -math.pi / 2,
                      child: NavArrow(color: c.ink),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.line, width: BrutalMetrics.border),
                ),
              ),
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2, color: c.ink),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A destination in the bottom bar (narrow screens) or side rail (wide screens).
class AppDestination {
  const AppDestination(this.label);

  final String label;
}

/// Page frame with navigation: a bottom bar on phones and a left rail from
/// [BrutalMetrics.wide], both made of hairline cells with the chosen one inverted.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.destinations, required this.index, required this.onSelect, required this.body});

  final List<AppDestination> destinations;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final wide = MediaQuery.sizeOf(context).width >= BrutalMetrics.wide;
    Widget cell(int i, {required bool rail}) => _NavCell(label: destinations[i].label, selected: i == index, rail: rail, onTap: () => onSelect(i));
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 220,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: c.line, width: BrutalMetrics.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[for (var i = 0; i < destinations.length; i++) cell(i, rail: true)],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: body),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: c.line, width: BrutalMetrics.border),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < destinations.length; i++) ...<Widget>[
                  if (i > 0) VerticalDivider(width: BrutalMetrics.border, thickness: BrutalMetrics.border, color: c.line),
                  Expanded(child: cell(i, rail: false)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.label, required this.selected, required this.rail, required this.onTap});

  final String label;
  final bool selected;
  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: BrutalMetrics.tapPlayer),
          padding: EdgeInsets.symmetric(horizontal: rail ? BrutalMetrics.gapL : BrutalMetrics.gapS, vertical: BrutalMetrics.gapM),
          color: selected ? c.ink : Colors.transparent,
          alignment: rail ? Alignment.centerLeft : Alignment.center,
          // Chrome shrinks to fit its cell instead of growing without bound with the OS text size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: rail ? Alignment.centerLeft : Alignment.center,
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: BrutalFonts.mono,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 2,
                color: selected ? c.paper : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
