import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/platform/host_server.dart';

void main() {
  test('hosting stays unsupported until the Rust bridge lands (Phase 3)', () {
    expect(createHostServer().isSupported, isFalse);
  });
}
