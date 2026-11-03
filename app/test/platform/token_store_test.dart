import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/token_store_io.dart';

const _session = StoredSession(
  serverUri: 'ws://192.168.1.5:7878/v1/ws',
  roomCode: 'KQ7M',
  sessionToken: 'session-secret',
  hostToken: 'host-secret',
  playerId: 'p_0',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session round-trips through the secure store and can be cleared', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final store = const SecureTokenStore(FlutterSecureStorage());
    expect(await store.read(), isNull);

    await store.write(_session);
    final read = await store.read();
    expect(read?.roomCode, 'KQ7M');
    expect(read?.sessionToken, 'session-secret');
    expect(read?.hostToken, 'host-secret');
    expect(read?.playerId, 'p_0');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('a corrupt entry reads as nothing and is removed', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{'poker_credits.session.v1': '{not json'});
    final store = const SecureTokenStore(FlutterSecureStorage());
    expect(await store.read(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'poker_credits.session.v1'), isNull);
  });
}
