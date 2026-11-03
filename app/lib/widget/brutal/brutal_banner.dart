import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Visual variants of [BrutalBanner].
enum BrutalBannerKind { info, warning, error }

/// Full-width strip for Reconnecting, Paused and errors. Warnings use a striped signal/ink
/// background so they cannot be missed or confused with a plain yellow turn signal.
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
      BrutalBannerKind.warning => BrutalColors.light.ink,
      BrutalBannerKind.error => c.onDanger,
    };
    final label = Container(
      color: kind == BrutalBannerKind.warning ? c.signal : null,
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapXs),
      child: Text(
        message.toUpperCase(),
        style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: text),
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
            BrutalBannerKind.warning => c.signal,
            BrutalBannerKind.error => c.danger,
          },
          border: Border.symmetric(
            horizontal: BorderSide(color: c.ink, width: BrutalMetrics.border),
          ),
        ),
        child: CustomPaint(
          painter: kind == BrutalBannerKind.warning ? _StripePainter(c.ink) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
            child: Row(
              children: <Widget>[
                Expanded(child: label),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(left: BrutalMetrics.gapS),
                    child: GestureDetector(
                      onTap: onAction,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: BrutalMetrics.tap),
                        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                        decoration: BoxDecoration(
                          color: c.paper,
                          border: Border.all(color: c.ink, width: BrutalMetrics.border),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            actionLabel!.toUpperCase(),
                            style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 14, color: c.ink),
                          ),
                        ),
                      ),
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
  const _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8;
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}
