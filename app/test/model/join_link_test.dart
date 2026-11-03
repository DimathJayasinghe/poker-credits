import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/join_link.dart';

void main() {
  test('round trips through its text form', () {
    const link = JoinLink(hostAndPort: '192.168.1.5:7878', roomCode: 'KQ7M');
    expect(JoinLink.tryParse(link.toString()), link);
    expect(link.webSocketUri.toString(), 'ws://192.168.1.5:7878/v1/ws');
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
}
