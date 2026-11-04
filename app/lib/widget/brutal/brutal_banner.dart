import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Visual variants of [BrutalBanner].
enum BrutalBannerKind { info, warning, error }

/// Full-width strip for Reconnecting, Paused and errors. Info is an ink strip, errors are the
/// accent fill, and warnings (reconnecting, paused) are a hatched surface with an accent bar on
/// the left, so they cannot be mistaken for the turn signal.
class BrutalBanner extends StatelessWidget {
  const BrutalBanner({super.key, required this.message, this.kind = BrutalBannerKind.info, this.actionLabel, this.onAction});

  final String message;
  final BrutalBannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final Color text = switch (kind) {
      BrutalBannerKind.info => c.onInfo,
      BrutalBannerKind.warning => c.ink,
      BrutalBannerKind.error => c.onDanger,
    };
    final label = Container(
      color: kind == BrutalBannerKind.warning ? c.surface : null,
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapXs),
      child: Text(
        message.toUpperCase(),
        style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1, color: text),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: switch (kind) {
            BrutalBannerKind.info => c.info,
            BrutalBannerKind.warning => c.surface,
            BrutalBannerKind.error => c.danger,
          },
          border: Border.symmetric(
            horizontal: BorderSide(color: c.ink, width: BrutalMetrics.border),
          ),
        ),
        child: CustomPaint(
          painter: kind == BrutalBannerKind.warning ? _StripePainter(c.ink.withValues(alpha: 0.12), c.accent) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapS, BrutalMetrics.gapM, BrutalMetrics.gapS),
            child: Row(
              children: <Widget>[
                Expanded(child: label),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(left: BrutalMetrics.gapS),
                    child: BrutalPressable(
                      onTap: onAction,
                      builder: (context, pressed) {
                        final duration = BrutalTheme.duration(context, BrutalMetrics.fast);
                        return AnimatedContainer(
                          duration: duration,
                          constraints: const BoxConstraints(minHeight: BrutalMetrics.tap),
                          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                          decoration: BoxDecoration(
                            color: pressed ? c.ink : c.surface,
                            border: Border.all(color: c.line, width: BrutalMetrics.border),
                          ),
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 14, color: pressed ? c.paper : c.ink),
                              child: Text(actionLabel!.toUpperCase()),
                            ),
                          ),
                        );
                      },
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

class _StripePainter extends CustomPainter {
  const _StripePainter(this.color, this.bar);

  final Color color;
  final Color bar;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4;
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, 8, size.height), Paint()..color = bar);
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color || old.bar != bar;
}
