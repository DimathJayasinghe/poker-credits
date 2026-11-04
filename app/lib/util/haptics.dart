import 'package:flutter/services.dart';

/// Vibration cues. Flutter's own `HapticFeedback`, so no plugin; a no-op where the device has
/// no vibration motor.
class Haptics {
  /// [enabled] is asked every time, so the Settings switch takes effect at once.
  const Haptics({this.enabled = _always});

  final bool Function() enabled;

  static bool _always() => true;

  /// Two firm pulses: it is your turn.
  Future<void> yourTurn() async {
    if (!enabled()) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
  }

  /// A light tick for a deliberate button press.
  Future<void> tap() async {
    if (enabled()) await HapticFeedback.selectionClick();
  }
}
