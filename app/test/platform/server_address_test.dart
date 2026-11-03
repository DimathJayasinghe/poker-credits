import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/platform/server_address_io.dart';

void main() {
  test('private LAN addresses come first and link-local ones are dropped', () {
    expect(
      rankLocalAddresses(<String>['169.254.3.4', '172.20.0.5', '10.0.0.7', '192.168.1.5', '8.8.4.4', '127.0.0.1']),
      <String>['192.168.1.5', '10.0.0.7', '172.20.0.5', '8.8.4.4'],
    );
  });

  test('172.x outside 16-31 is not a private address', () {
    expect(rankLocalAddresses(<String>['172.40.0.1', '10.1.1.1']), <String>['10.1.1.1', '172.40.0.1']);
  });
}
