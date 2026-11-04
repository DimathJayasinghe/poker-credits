import 'dart:async';

import 'package:flutter/widgets.dart';

/// Shared press behaviour for every tappable cell: reports whether a finger is down and keeps
/// that state visible for at least [minHold], so even a quick tap shows the cell inverting
/// instead of flashing for a frame. [onTap] still fires the moment the finger lifts.
///
/// It draws nothing itself; the [builder] decides what "pressed" looks like (docs/UI_DESIGN.md
/// section 2: pressed cells invert). Semantics are left to the caller.
class BrutalPressable extends StatefulWidget {
  const BrutalPressable({super.key, required this.onTap, required this.builder, this.enabled = true});

  /// How long the pressed look stays at least.
  static const Duration minHold = Duration(milliseconds: 140);

  final VoidCallback? onTap;
  final bool enabled;
  final Widget Function(BuildContext context, bool pressed) builder;

  @override
  State<BrutalPressable> createState() => _BrutalPressableState();
}

class _BrutalPressableState extends State<BrutalPressable> {
  bool _pressed = false;
  bool _released = true;
  bool _holdElapsed = true;
  Timer? _hold;

  bool get _active => widget.enabled && widget.onTap != null;

  void _down(TapDownDetails _) {
    if (!_active) return;
    _hold?.cancel();
    _released = false;
    _holdElapsed = false;
    _hold = Timer(BrutalPressable.minHold, () {
      _holdElapsed = true;
      if (_released) _clear();
    });
    if (!_pressed) setState(() => _pressed = true);
  }

  void _up() {
    _released = true;
    if (_holdElapsed) _clear();
  }

  void _clear() {
    if (mounted && _pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(BrutalPressable old) {
    super.didUpdateWidget(old);
    if (!_active) {
      _hold?.cancel();
      _released = true;
      _holdElapsed = true;
      _pressed = false;
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? _down : null,
      onTapUp: _active ? (_) => _up() : null,
      onTapCancel: _active ? _up : null,
      onTap: _active ? widget.onTap : null,
      child: widget.builder(context, _pressed && _active),
    );
  }
}
