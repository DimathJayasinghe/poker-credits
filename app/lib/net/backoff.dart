import 'dart:math';

/// Reconnect delays: 0.5, 1, 2, 4, 8 s, then 10 s, each with +-20% jitter
/// (docs/RESILIENCE_AND_CRASH_HANDLING.md section 4.1).
class Backoff {
  Backoff({Random? random}) : _random = random ?? Random();

  static const List<int> _stepsMs = <int>[500, 1000, 2000, 4000, 8000, 10000];

  final Random _random;
  int _attempt = 0;

  /// The delay before the next attempt; advances the schedule.
  Duration next() {
    final base = _stepsMs[_attempt < _stepsMs.length ? _attempt : _stepsMs.length - 1];
    _attempt++;
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (base * jitter).round());
  }

  /// Starts over at 0.5 s (called after a connection stayed up long enough).
  void reset() => _attempt = 0;

  /// Attempts made since the last reset.
  int get attempts => _attempt;
}
