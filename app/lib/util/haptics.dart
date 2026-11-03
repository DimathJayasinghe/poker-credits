import 'package:flutter/services.dart';

/// Vibration cues. Flutter's own `HapticFeedback`, so no plugin; a no-op where the device has
/// no vibration motor.
class Haptics {
  const Haptics();

  /// Two firm pulses: it is your turn.
  Future<void> yourTurn() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
  }

  /// A light tick for a deliberate button press.
  Future<void> tap() => HapticFeedback.selectionClick();
}
