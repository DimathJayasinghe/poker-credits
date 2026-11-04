import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A raised cell: `surface` fill and a hairline, with an optional caption strip on top.
class BrutalCard extends StatelessWidget {
  const BrutalCard({super.key, required this.child, this.header, this.padding = const EdgeInsets.all(BrutalMetrics.gapM)});

  final Widget child;
  final String? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: c.ink),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
