import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/host_finder_io.dart';
import 'package:poker_credits/platform/host_server_io.dart';
import 'package:poker_credits/platform/settings_store.dart';
import 'package:poker_credits/platform/sound_player.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../support/fakes.dart';

/// Where the native library of a `cargo build` is. End-to-end tests are skipped without it.
final String? nativeLibraryPath = Platform.environment['POKER_BRIDGE_LIB'];

/// Why the end-to-end tests are skipped, or `null` when they run.
String? get e2eSkipReason => nativeLibraryPath == null ? 'set POKER_BRIDGE_LIB to the built native library to run the end-to-end tests' : null;

/// The usual table: 1000 chips, blinds 5 and 10, real cards on the table.
const RoomConfig e2eTable = RoomConfig(
  startingChips: 1000,
  smallBlind: 5,
  bigBlind: 10,
  ante: 0,
  isTournament: false,
  blindLevelMinutes: 10,
  turnTimeLimitSeconds: 0,
);

/// This machine's own address on a private network (192.168.x.x, 172.16-31.x.x, 10.x.x.x), or
/// `null` when there is none (set by [loadLanAddress]). Connecting to it goes through the real
/// network interface, and a guest treats it as a LAN host (loopback is not one).
String? lanAddress;

/// Looks for [lanAddress]. Call it once before the first test.
Future<void> loadLanAddress() async {
  for (final interface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final address in interface.addresses) {
      if (JoinLink.isLanAddress(address.address)) {
        lanAddress = address.address;
        return;
      }
    }
  }
}

/// Waits until [condition] holds, polling real time (the sockets are real).
Future<void> eventually(String what, bool Function() condition, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out after $timeout waiting for: $what');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Asserts that [condition] stays true for [duration] (nothing happens behind the user's back).
Future<void> staysTrue(String what, bool Function() condition, {Duration duration = const Duration(seconds: 2)}) async {
  final until = DateTime.now().add(duration);
  while (DateTime.now().isBefore(until)) {
    if (!condition()) fail('did not hold: $what');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

/// A finder that waits [delay] before it looks at a certificate: a slow Wi-Fi or a busy phone.
class SlowFinder implements HostFinder {
  SlowFinder(this._inner, this.delay);

  final HostFinder _inner;
  final Duration delay;
  int fingerprintCalls = 0;

  @override
  bool get isSupported => _inner.isSupported;

  @override
  HostSearch search(String roomCode) => _inner.search(roomCode);

  @override
  LobbyBrowse browse() => _inner.browse();

  @override
  Future<String?> fingerprintOf(String hostAndPort) async {
    fingerprintCalls++;
    await Future<void>.delayed(delay);
    return _inner.fingerprintOf(hostAndPort);
  }

  @override
  Future<bool> speaksPlainHttp(String hostAndPort) => _inner.speaksPlainHttp(hostAndPort);
}

/// One phone: the app's own providers, the real native server, the real finder and the real
/// socket client. Only what has no meaning without a screen (wake lock, sound, secure storage)
/// is replaced.
class Device {
  /// The sound effects this phone asked for.
  final FakeSound sound = FakeSound();

  Device(
    this.name, {
    Directory? dir,
    MemoryTokenStore? tokens,
    List<String> searchAddresses = const <String>['127.0.0.1'],
    HostFinder Function(HostFinder real)? wrapFinder,
  }) : dir = dir ?? Directory.systemTemp.createTempSync('pc-e2e-$name-'),
       tokens = tokens ?? MemoryTokenStore() {
    server = NativeHostServer(
      dataDir: () async => this.dir.path,
      init: () => initBridge(libraryPath: nativeLibraryPath, rustLogFilter: Platform.environment['E2E_RUST_LOG'] ?? 'info'),
    );
    final real = LanHostFinder(candidates: () async => searchAddresses);
    finder = wrapFinder == null ? real : wrapFinder(real);
    final settings = MemorySettingsStore(const AppSettings(acceptedTerms: currentTermsVersion, introDone: true, nameAsked: true));
    container = RefenaContainer(
      overrides: [
        hostServerProvider.overrideWithValue(server),
        tokenStoreProvider.overrideWithValue(this.tokens),
        wakeLockProvider.overrideWithValue(FakeWakeLock()),
        hapticsProvider.overrideWithValue(FakeHaptics()),
        soundProvider.overrideWithValue(sound),
        soundPlayerProvider.overrideWithValue(const SilentSoundPlayer()),
        hostFinderProvider.overrideWithValue(finder),
        settingsStoreProvider.overrideWithValue(settings),
        appVersionProvider.overrideWithValue(() async => 'e2e'),
        initialSettingsProvider.overrideWithValue(settings.value),
        hostKeepAliveProvider.overrideWithValue(FakeKeepAlive()),
        localAddressesProvider.overrideWithValue(() async => searchAddresses),
      ],
    );
  }

  final String name;
  final Directory dir;
  final MemoryTokenStore tokens;
  late final NativeHostServer server;
  late final HostFinder finder;
  late final RefenaContainer container;

  SessionState get session => container.read(sessionProvider);
  HostState get hosting => container.read(hostProvider);
  RoomView? get view => session.room.view;
  LinkState get link => session.link;
  Future<StoredSession?> get stored => tokens.read();

  /// Starts hosting a game and waits until this phone's own screen is connected to it.
  Future<HostedRoom> host({RoomConfig config = e2eTable, String hostName = 'Host'}) async {
    await container.notifier(hostProvider).start(hostName: hostName, config: config);
    final room = hosting.room;
    if (room == null) fail('hosting failed: ${hosting.error}');
    await eventually('$name: the host screen is connected', () => link.isLive && view != null);
    return room;
  }

  /// The link a QR code on the host's screen would carry.
  static JoinLink qrOf(HostedRoom room, {String address = '127.0.0.1', bool pinned = true}) =>
      JoinLink(hostAndPort: '$address:${room.port}', roomCode: room.roomCode, fingerprint: pinned ? room.fingerprint : null);

  /// Joins as a player and waits for a seat.
  Future<void> joinSeated(JoinLink link, String playerName) async {
    await container.read(joinProvider).join(link: link, name: playerName);
    await eventually('$name: seated as $playerName', () => session.isSeated);
  }

  /// Folds or checks whenever it is this phone's turn, until [done] holds.
  void actFold() {
    final prompt = session.room.prompt;
    if (prompt == null) return;
    container.notifier(sessionProvider).send(GameAction(actionSeq: session.room.nextActionSeq, action: const FoldAction()));
  }

  bool _killed = false;

  /// The app is killed: sockets close, nothing is said and nothing is cleaned up, so the stored
  /// session stays exactly as it was.
  void kill() {
    if (_killed) return;
    _killed = true;
    container.disposeContainer();
  }

  Future<void> dispose() async {
    if (_killed) {
      await server.stop();
      try {
        await dir.delete(recursive: true);
      } on Object {
        // Best effort: a temp folder.
      }
      return;
    }
    try {
      await container.notifier(sessionProvider).leave();
    } on Object {
      // The server may be gone already.
    }
    await server.stop();
    try {
      await dir.delete(recursive: true);
    } on Object {
      // Best effort: a temp folder.
    }
  }
}
