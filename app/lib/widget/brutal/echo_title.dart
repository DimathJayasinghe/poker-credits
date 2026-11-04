import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// The hero wordmark: solid display type with two outlined copies stepped straight up. The
/// one loud thing on the home screen. The copies slide out from behind the word once per app
/// session (and never with reduced motion).
class EchoTitle extends StatefulWidget {
  const EchoTitle(this.lines, {super.key, this.size = 104});

  final List<String> lines;
  final double size;

  /// Plays the entrance only the first time the title is built in this app session.
  static bool _played = false;

  @override
  State<EchoTitle> createState() => _EchoTitleState();
}

class _EchoTitleState extends State<EchoTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (EchoTitle._played || MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      EchoTitle._played = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final text = widget.lines.map((l) => l.toUpperCase()).join('\n');
    TextStyle style({Paint? stroke}) => TextStyle(
      fontFamily: BrutalFonts.display,
      fontSize: widget.size,
      height: 0.95,
      letterSpacing: 1,
      color: stroke == null ? c.ink : null,
      foreground: stroke,
    );
    Widget echo(int step) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = BrutalMetrics.border
        ..color = c.ink.withValues(alpha: 0.75 - step * 0.3);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Transform.translate(offset: Offset(0, -widget.size * 0.05 * step * t), child: child);
        },
        child: Text(text, style: style(stroke: stroke)),
      );
    }

    return Semantics(
      header: true,
      label: widget.lines.join(' '),
      excludeSemantics: true,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            echo(2),
            echo(1),
            Text(text, style: style()),
          ],
        ),
      ),
    );
  }
}
