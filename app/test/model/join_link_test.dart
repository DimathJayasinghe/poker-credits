import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/net/pin.dart';

import '../support/fakes.dart';

void main() {
  test('round trips through its text form', () {
    const link = JoinLink(hostAndPort: '192.168.1.5:7878', roomCode: 'KQ7M', fingerprint: testPin);
    expect(JoinLink.tryParse(link.toString()), link);
    expect(link.webSocketUri.toString(), 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
    expect(pinOf(link.webSocketUri), testPin);
  });

  group('the host fingerprint (ADR-019)', () {
    test('travels in the QR text as f', () {
      const link = JoinLink(hostAndPort: '192.168.1.5:7878', roomCode: 'KQ7M', fingerprint: testPin);
      expect(link.toString(), 'pokercredits://join?h=192.168.1.5%3A7878&c=KQ7M&f=$testPin');
    });

    test('an older code without one still parses, and has nothing to pin', () {
      final link = JoinLink.tryParse('pokercredits://join?h=10.0.0.2:7878&c=KQ7M')!;
      expect(link.fingerprint, isNull);
      expect(pinOf(link.webSocketUri), isNull);
      expect(link.webSocketUri.scheme, 'wss', reason: 'never plaintext, with or without a pin');
    });

    test('a damaged or forged fingerprint makes the whole code invalid', () {
      for (final bad in <String>['short', '${testPin}x', testPin.replaceFirst('A', '+'), '']) {
        expect(JoinLink.tryParse('pokercredits://join?h=10.0.0.2:7878&c=KQ7M&f=$bad'), isNull, reason: bad);
      }
    });

    test('links with different fingerprints are different links', () {
      const a = JoinLink(hostAndPort: '10.0.0.2:7878', roomCode: 'KQ7M', fingerprint: testPin);
      expect(a, isNot(a.withFingerprint(otherTestPin)));
      expect(a.withFingerprint(null).fingerprint, isNull);
    });
  });

  test('lowercase room codes are accepted and uppercased', () {
    expect(JoinLink.tryParse('pokercredits://join?h=10.0.0.2:7878&c=kq7m')!.roomCode, 'KQ7M');
  });

  test('anything that is not ours or is malformed is refused', () {
    for (final text in <String>[
      '',
      'https://example.com/join?h=1.2.3.4:7878&c=KQ7M',
      'pokercredits://join?h=1.2.3.4&c=KQ7M',
      'pokercredits://join?h=1.2.3.4:7878&c=KQ0M',
      'pokercredits://join?h=1.2.3.4:7878&c=KQ7',
      'pokercredits://join?h=evil.com/x:7878&c=KQ7M',
      'pokercredits://other?h=1.2.3.4:7878&c=KQ7M',
      '%%%',
    ]) {
      expect(JoinLink.tryParse(text), isNull, reason: text);
    }
  });

  group('typed input', () {
    test('an address gets the default port, an explicit port is kept', () {
      expect(JoinLink.normalizeAddress('192.168.1.5'), '192.168.1.5:7878');
      expect(JoinLink.normalizeAddress(' 10.0.2.2:9000 '), '10.0.2.2:9000');
      expect(JoinLink.normalizeAddress('table.local'), 'table.local:7878');
    });

    test('things that are not an address are refused', () {
      for (final bad in <String>['', 'ws://192.168.1.5:7878', '192.168.1.5/v1', 'a b', '192.168.1.5:0', '192.168.1.5:70000', '192.168.1.5:abc']) {
        expect(JoinLink.normalizeAddress(bad), isNull, reason: bad);
      }
    });

    test('a room code is case-insensitive and uses the server alphabet', () {
      expect(JoinLink.normalizeRoomCode('kq7m'), 'KQ7M');
      expect(JoinLink.normalizeRoomCode(' k q7m '), 'KQ7M');
      expect(JoinLink.normalizeRoomCode('KQ7'), isNull);
      expect(JoinLink.normalizeRoomCode('KQ0M'), isNull, reason: '0 is not in the alphabet');
      expect(JoinLink.normalizeRoomCode('KQ1M'), isNull, reason: '1 is not in the alphabet');
    });
  });
}
