import 'package:flutter/widgets.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// A card that arrives face down and turns over after [delay], so a deal or a showdown has a
/// rhythm instead of everything appearing at once. With [animate] off, or with reduced motion,
/// it is simply the face.
class FlipIn extends StatefulWidget {
  const FlipIn({
    super.key,
    required this.card,
    this.delay = Duration.zero,
    this.animate = true,
    this.size = CardSize.board,
    this.fourColour = false,
    this.dim = false,
    this.lifted = false,
  });

  final PokerCard card;
  final Duration delay;
  final bool animate;
  final CardSize size;
  final bool fourColour;
  final bool dim;
  final bool lifted;

  @override
  State<FlipIn> createState() => _FlipInState();
}

class _FlipInState extends State<FlipIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || BrutalTheme.duration(context, BrutalMetrics.flip) == Duration.zero) return;
    final total = widget.delay + BrutalMetrics.flip;
    _controller = AnimationController(vsync: this, duration: total)
      ..addListener(() => setState(() {}))
      ..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || controller.isCompleted) {
      return PlayingCard(card: widget.card, size: widget.size, fourColour: widget.fourColour, dim: widget.dim, lifted: widget.lifted);
    }
    final total = controller.duration!.inMicroseconds;
    final start = widget.delay.inMicroseconds / total;
    final t = Interval(start, 1, curve: Curves.easeInOut).transform(controller.value);
    final showFace = t > 0.5;
    final squash = (2 * t - 1).abs().clamp(0.02, 1.0);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(squash, 1, 1),
      child: PlayingCard(
        card: showFace ? widget.card : null,
        size: widget.size,
        fourColour: widget.fourColour,
        dim: showFace && widget.dim,
        lifted: showFace && widget.lifted,
      ),
    );
  }
}
