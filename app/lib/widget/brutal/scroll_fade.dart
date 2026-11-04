import 'package:flutter/material.dart';

/// Fades the bottom edge of a scroll view while there is more below, so a row cut off by the edge
/// reads as "this scrolls" and not as a drawing mistake. Nothing is faded once the end is in view
/// or when everything fits.
///
/// [builder] must hand [controller] to the scroll view it builds.
class ScrollFade extends StatefulWidget {
  const ScrollFade({super.key, required this.builder, this.height = 28});

  final Widget Function(BuildContext context, ScrollController controller) builder;

  /// How tall the fade is.
  final double height;

  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade> {
  final ScrollController _controller = ScrollController();
  bool _more = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _update(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 1;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _update(n.metrics),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0, _more ? 1 - widget.height / rect.height : 1, 1],
          ).createShader(rect),
          child: widget.builder(context, _controller),
        ),
      ),
    );
  }
}
