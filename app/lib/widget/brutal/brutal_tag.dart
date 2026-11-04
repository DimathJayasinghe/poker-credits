import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Visual variants of [BrutalTag].
enum BrutalTagKind { neutral, signal, danger, info }

/// Small boxed label: `D`, `SB`, `BB`, `ALL-IN`, `FOLDED`, `AUTO`. State is carried by the text,
/// never by colour alone (docs/UI_DESIGN.md section 2).
class BrutalTag extends StatelessWidget {
  const BrutalTag(this.label, {super.key, this.kind = BrutalTagKind.neutral});

  final String label;
  final BrutalTagKind kind;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final (Color fill, Color text) = switch (kind) {
      BrutalTagKind.neutral => (c.surface, c.ink),
      BrutalTagKind.signal => (c.accent, c.onAccent),
      BrutalTagKind.danger => (c.accent, c.onAccent),
      BrutalTagKind.info => (c.ink, c.paper),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: c.line, width: BrutalMetrics.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapXs / 2),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: text),
          ),
        ),
      ),
    );
  }
}
