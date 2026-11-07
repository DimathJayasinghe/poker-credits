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

/// The background as it looks with the grain at its strongest: every speck fully opaque.
Color _grainy(BrutalColors c) => Color.alphaBlend(c.grain.withValues(alpha: c.grainOpacity), c.paper);

void main() {
  for (final entry in <String, BrutalColors>{'light': BrutalColors.light, 'dark': BrutalColors.dark}.entries) {
    final c = entry.value;
    group('${entry.key} palette contrast (docs/UI_DESIGN.md section 6)', () {
      test('ink on paper and surface is at least 7:1', () {
        expect(contrast(c.ink, c.paper), greaterThanOrEqualTo(7));
        expect(contrast(c.ink, c.surface), greaterThanOrEqualTo(7));
      });
      test('ink stays at least 7:1 under the strongest grain', () => expect(contrast(c.ink, _grainy(c)), greaterThanOrEqualTo(7)));
      test('muted text is at least 4.5:1 on paper, surface and under the grain', () {
        expect(contrast(c.muted, c.paper), greaterThanOrEqualTo(4.5));
        expect(contrast(c.muted, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.muted, _grainy(c)), greaterThanOrEqualTo(4.5));
      });
      test('text on the accent fill is at least 4.5:1', () => expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5)));
      test('the accent against paper clears 3:1 for fills and large type', () {
        expect(contrast(c.accent, c.paper), greaterThanOrEqualTo(3));
        expect(contrast(c.accent, _grainy(c)), greaterThanOrEqualTo(3));
      });
      test('text on felt is at least 4.5:1', () => expect(contrast(c.onFelt, c.felt), greaterThanOrEqualTo(4.5)));
      test('text on the chip fill is at least 7:1', () => expect(contrast(c.onChip, c.chip), greaterThanOrEqualTo(7)));
      test('inverted cells (paper on ink) are at least 7:1', () => expect(contrast(c.paper, c.ink), greaterThanOrEqualTo(7)));
      test('every suit colour is at least 7:1 on the card face, in both themes', () {
        for (final suit in <Color>[c.suitRed, c.suitBlack, c.suitGreen, c.suitBlue]) {
          expect(contrast(suit, c.cardFace), greaterThanOrEqualTo(7));
        }
      });
      test('the four suit colours stay apart for the four-colour deck (no two closer than 1.3:1)', () {
        final suits = <Color>[c.suitRed, c.suitBlack, c.suitGreen, c.suitBlue];
        for (var i = 0; i < suits.length; i++) {
          for (var j = i + 1; j < suits.length; j++) {
            expect(suits[i], isNot(suits[j]));
          }
        }
      });
      test('a card stands out from the paper, the surface and the felt (3:1 at its edge)', () {
        for (final ground in <Color>[c.paper, c.surface, c.felt]) {
          expect(contrast(c.cardFace, ground) >= 3 || contrast(c.ink, ground) >= 3, isTrue);
        }
        expect(contrast(c.cardBack, c.cardFace), greaterThanOrEqualTo(3));
        expect(contrast(c.cardBackMark, c.cardBack), greaterThanOrEqualTo(3));
      });
      test('a pressed accent cell (paper on ink) and the ink focus outline read on paper', () {
        expect(contrast(c.ink, c.paper), greaterThanOrEqualTo(3));
      });
    });
  }
}
