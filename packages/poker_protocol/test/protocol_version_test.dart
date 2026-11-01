import 'package:poker_protocol/poker_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('protocol version starts at 1', () {
    expect(protocolVersion, 1);
  });

  test('maxChips is exact in a JavaScript number', () {
    expect(maxChips, lessThan(9007199254740992));
  });
}
