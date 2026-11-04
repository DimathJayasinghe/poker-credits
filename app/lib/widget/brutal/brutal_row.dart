import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// A diagonal arrow, drawn so it looks the same on every platform and in every font.
class NavArrow extends StatelessWidget {
  const NavArrow({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ArrowPainter(color));
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = BrutalMetrics.border
      ..strokeCap = StrokeCap.square;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.18, w * 0.82)
      ..lineTo(w * 0.82, w * 0.18)
      ..moveTo(w * 0.28, w * 0.18)
      ..lineTo(w * 0.82, w * 0.18)
      ..lineTo(w * 0.82, w * 0.72);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

/// A full-width row: the label on the left and an arrow cell on the right, divided by hairlines.
/// Home actions and Settings navigation use it. [emphasis] fills it with the accent (use for the
/// one thing the screen is for).
class BrutalRow extends StatefulWidget {
  const BrutalRow({super.key, required this.label, required this.onTap, this.caption, this.emphasis = false});

  final String label;
  final String? caption;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  State<BrutalRow> createState() => _BrutalRowState();
}

class _BrutalRowState extends State<BrutalRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final enabled = widget.onTap != null;
    var (Color fill, Color text) = widget.emphasis ? (c.accent, c.onAccent) : (Colors.transparent, c.ink);
    if (_pressed && enabled) (fill, text) = (c.ink, c.paper);
    final muted = _pressed || widget.emphasis ? text : c.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.caption == null ? widget.label : '${widget.label}. ${widget.caption}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapL, vertical: BrutalMetrics.gapM),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: BrutalFonts.display,
                            fontSize: 26,
                            height: 1.05,
                            letterSpacing: 0.8,
                            color: enabled ? text : c.muted,
                          ),
                        ),
                        if (widget.caption != null) ...<Widget>[
                          const SizedBox(height: BrutalMetrics.gapXs),
                          Text(widget.caption!, style: TextStyle(fontSize: 12, height: 1.3, color: muted)),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 76,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: c.line, width: BrutalMetrics.border),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: NavArrow(color: enabled ? text : c.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
