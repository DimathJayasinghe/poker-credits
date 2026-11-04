import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/brutal/felt_panel.dart';

void main() {
  test('the table drawing keeps its proportions in any panel', () {
    const sizes = <Size>[Size(390, 180), Size(520, 800), Size(1000, 300), Size(1920, 1080), Size(120, 40), Size(300, 300)];
    for (final size in sizes) {
      final scene = FeltPanel.sceneRect(size);
      expect(scene.width / scene.height, closeTo(FeltPanel.aspect, 1e-9), reason: '$size must not be stretched');
      expect(scene.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(scene.top, greaterThanOrEqualTo(0), reason: '$size');
      expect(scene.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(scene.bottom, lessThanOrEqualTo(size.height), reason: '$size');
      expect(scene.center.dx, closeTo(size.width / 2, 1e-9), reason: 'centred');
      expect(scene.center.dy, closeTo(size.height / 2, 1e-9), reason: 'centred');
    }
  });

  test('no room means no drawing, not a crash', () {
    expect(FeltPanel.sceneRect(Size.zero), Rect.zero);
    expect(FeltPanel.sceneRect(const Size(0, 200)), Rect.zero);
    expect(FeltPanel.sceneRect(const Size(200, 0)), Rect.zero);
  });
}
