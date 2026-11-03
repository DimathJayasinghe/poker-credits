import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/net/backoff.dart';

void main() {
  test('follows 0.5, 1, 2, 4, 8, then 10 s within +-20%', () {
    final backoff = Backoff(random: Random(1));
    final expected = <int>[500, 1000, 2000, 4000, 8000, 10000, 10000, 10000];
    for (final base in expected) {
      final ms = backoff.next().inMilliseconds;
      expect(ms, inInclusiveRange((base * 0.8).round(), (base * 1.2).round()));
    }
  });

  test('reset starts over at 0.5 s', () {
    final backoff = Backoff(random: Random(2));
    for (var i = 0; i < 4; i++) {
      backoff.next();
    }
    backoff.reset();
    expect(backoff.attempts, 0);
    expect(backoff.next().inMilliseconds, lessThanOrEqualTo(600));
  });

  test('jitter actually varies the delay', () {
    final random = Random(3);
    final delays = <int>{};
    for (var i = 0; i < 20; i++) {
      final backoff = Backoff(random: random);
      delays.add(backoff.next().inMilliseconds);
    }
    expect(delays.length, greaterThan(5));
  });
}
