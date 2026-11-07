import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../support/fakes.dart';

/// What a typed address does before a socket is opened: look at the host's certificate, and say so
/// when the host is an older version that cannot be reached safely.
void main() {
  late FakeNetwork network;
  late FakeHostFinder finder;
  late RefenaContainer container;

  setUp(() {
    network = FakeNetwork();
    finder = FakeHostFinder();
    container = RefenaContainer(
      overrides: [
        hostFinderProvider.overrideWithValue(finder),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        roomClientFactoryProvider.overrideWithValue((uri, first) => RoomClient(uri: uri, firstMessage: first, transport: network.connect)),
      ],
    );
  });

  tearDown(() => container.disposeContainer());

  const typed = JoinLink(hostAndPort: '192.168.1.5:7878', roomCode: 'KQ7M');

  test('a typed address is pinned to the certificate the host shows', () async {
    await container.read(joinProvider).join(link: typed, name: 'Ana');
    expect(finder.fingerprintRequests, <String>['192.168.1.5:7878']);
    expect(container.read(sessionProvider).serverUri, 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
  });

  test('a host that does not answer the first look is asked once more before joining', () async {
    finder.shown = null;
    await container.read(joinProvider).join(link: typed, name: 'Ana');
    expect(finder.fingerprintRequests, hasLength(2));
  });

  test('a host that speaks plain HTTP is an older version: said at once, nothing is connected', () async {
    finder
      ..shown = null
      ..plainHosts.add('192.168.1.5:7878');
    await container.read(joinProvider).join(link: typed, name: 'Ana');
    final link = container.read(sessionProvider).link;
    expect(link.phase, LinkPhase.failed);
    expect(link.failure, LinkFailure.hostOutdated);
    expect(network.uris, isEmpty, reason: 'no connection was attempted');
  });

  test('a link from a QR code is not looked at again: its fingerprint is the pin', () async {
    await container.read(joinProvider).join(link: typed.withFingerprint(otherTestPin), name: 'Ana');
    expect(finder.fingerprintRequests, isEmpty);
    expect(container.read(sessionProvider).serverUri, 'wss://192.168.1.5:7878/v1/ws#pin=$otherTestPin');
  });

  test('leaving while the host is being looked at connects nothing', () async {
    final pending = container.read(joinProvider).join(link: typed, name: 'Ana');
    await container.read(joinProvider).leave();
    await pending;
    expect(network.uris, isEmpty);
    expect(container.read(sessionProvider).isAttached, isFalse);
  });
}
