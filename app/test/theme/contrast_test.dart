import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/theme/tokens.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final entry in <String, BrutalColors>{'light': BrutalColors.light, 'dark': BrutalColors.dark}.entries) {
    final c = entry.value;
    group('${entry.key} palette contrast (docs/UI_DESIGN.md section 5)', () {
      test('ink on paper is at least 7:1', () => expect(contrast(c.ink, c.paper), greaterThanOrEqualTo(7)));
      test('muted on paper is at least 4.5:1', () => expect(contrast(c.muted, c.paper), greaterThanOrEqualTo(4.5)));
      test('text on signal is at least 7:1', () => expect(contrast(BrutalColors.light.ink, c.signal), greaterThanOrEqualTo(7)));
      test('text on felt is at least 4.5:1', () => expect(contrast(c.onFelt, c.felt), greaterThanOrEqualTo(4.5)));
      test('text on danger is at least 4.5:1', () => expect(contrast(c.onDanger, c.danger), greaterThanOrEqualTo(4.5)));
      test('text on info is at least 4.5:1', () => expect(contrast(c.onInfo, c.info), greaterThanOrEqualTo(4.5)));
    });
  }
}
