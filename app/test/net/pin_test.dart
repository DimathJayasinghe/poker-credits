import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/net/pin.dart';

import '../support/fakes.dart';

void main() {
  group('pin shape', () {
    test('43 URL-safe base64 characters', () {
      expect(isPin(testPin), isTrue);
      expect(isPin('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO-_'), isTrue);
      for (final bad in <String?>[
        null,
        '',
        'short',
        '${testPin}A',
        testPin.substring(1),
        '+${testPin.substring(1)}',
        '=${testPin.substring(1)}',
        ' ${testPin.substring(1)}',
      ]) {
        expect(isPin(bad), isFalse, reason: '$bad');
      }
    });
  });

  group('a pin travels in the URI fragment', () {
    final base = Uri.parse('wss://192.168.1.5:7878/v1/ws');

    test('attach, read and strip', () {
      final pinned = withPin(base, testPin);
      expect(pinned.toString(), 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
      expect(pinOf(pinned), testPin);
      expect(withoutPin(pinned), base);
      expect(Uri.parse(pinned.toString()), pinned, reason: 'survives the session store as text');
    });

    test('no pin leaves the address as it is', () {
      expect(withPin(base, null), base);
      expect(pinOf(base), isNull);
      expect(withoutPin(base), base);
    });

    test('a malformed pin is refused when attaching and ignored when reading', () {
      expect(() => withPin(base, 'nope'), throwsArgumentError);
      expect(pinOf(Uri.parse('wss://h:1/v1/ws#pin=nope')), isNull);
      expect(pinOf(Uri.parse('wss://h:1/v1/ws#other=$testPin')), isNull);
    });
  });

  test('only this device counts as loopback', () {
    for (final yes in <String>['127.0.0.1', 'localhost', '::1', '[::1]']) {
      expect(isLoopbackHost(yes), isTrue, reason: yes);
    }
    for (final no in <String>['192.168.1.5', '10.0.0.1', '127.0.0.2.evil.example', 'localhost.evil.example', '0.0.0.0', '']) {
      expect(isLoopbackHost(no), isFalse, reason: no);
    }
  });
}
