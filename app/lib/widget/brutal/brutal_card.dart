import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Bordered block with a hard shadow and an optional inverted header strip.
class BrutalCard extends StatelessWidget {
  const BrutalCard({super.key, required this.child, this.header, this.padding = const EdgeInsets.all(BrutalMetrics.gapM)});

  final Widget child;
  final String? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(right: BrutalMetrics.shadow, bottom: BrutalMetrics.shadow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.paper,
          border: Border.all(color: c.ink, width: BrutalMetrics.border),
          boxShadow: <BoxShadow>[BoxShadow(color: c.ink, offset: const Offset(BrutalMetrics.shadow, BrutalMetrics.shadow))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null)
              Container(
                color: c.ink,
                padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
                child: Text(
                  header!.toUpperCase(),
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c.paper),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
