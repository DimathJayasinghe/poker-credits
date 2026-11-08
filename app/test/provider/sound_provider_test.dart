import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/platform/settings_store.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../support/fakes.dart';

/// The whole chain with the real [Sound]: a live message from the server reaches the audio player,
/// and the one Settings switch decides whether it does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNetwork network;
  late RecordingSoundPlayer player;
  late RefenaContainer container;

  const fold = ActionPerformed(playerId: 'p_1', playerName: 'Ana', kind: ActionKind.fold, amount: 0, chipsRemaining: 900, allIn: false, auto: false);
  const check = ActionPerformed(
    playerId: 'p_1',
    playerName: 'Ana',
    kind: ActionKind.check,
    amount: 0,
    chipsRemaining: 900,
    allIn: false,
    auto: false,
  );

  setUp(() async {
    network = FakeNetwork();
    player = RecordingSoundPlayer();
    container = RefenaContainer(
      overrides: [
        hostFinderProvider.overrideWithValue(FakeHostFinder()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore(AppSettings.defaults)),
        soundPlayerProvider.overrideWithValue(player),
        roomClientFactoryProvider.overrideWithValue((uri, first) => RoomClient(uri: uri, firstMessage: first, transport: network.connect)),
      ],
    );
    await container
        .read(joinProvider)
        .join(
          link: const JoinLink(hostAndPort: '192.168.1.5:7878', roomCode: 'KQ7M'),
          name: 'Ana',
        );
    network.last
      ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 't'))
      ..serverSends(snapshot(view: roomView(seats: [seatView(0, 'Host'), seatView(1, 'Ana')])));
    await pumpEventQueue();
  });

  tearDown(() => container.disposeContainer());

  test('a guest\'s own action reaches the player as its clip', () async {
    network.last.serverSends(fold);
    await pumpEventQueue();
    expect(player.played, ['assets/sounds/fold.wav']);
  });

  test('with Sound off in Settings nothing is played, and turning it on again brings it back', () async {
    container.notifier(settingsProvider).update((s) => s.copyWith(sound: false));
    network.last.serverSends(fold);
    await pumpEventQueue();
    expect(player.played, isEmpty);

    container.notifier(settingsProvider).update((s) => s.copyWith(sound: true));
    network.last.serverSends(check);
    await pumpEventQueue();
    expect(player.played, ['assets/sounds/check.wav']);
  });

  test('a snapshot after a reconnect is silent and sets the baseline again', () async {
    network.last
      ..serverSends(snapshot(version: 5, view: roomView(hand: 4, seats: [seatView(0, 'Host'), seatView(1, 'Ana')])))
      ..serverSends(holeCards('As', 'Kd', hand: 4));
    await pumpEventQueue();
    expect(player.played, isEmpty);
  });

  test('the app in the background is quiet', () async {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    network.last.serverSends(fold);
    await pumpEventQueue();
    expect(player.played, isEmpty);
  });
}
