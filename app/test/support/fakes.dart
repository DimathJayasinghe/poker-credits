import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/net/transport.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/platform/wake_lock.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/util/haptics.dart';
import 'package:poker_credits/util/sound.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

import 'test_app.dart';

/// A scripted socket for tests.
class FakeTransport implements Transport {
  final _incoming = StreamController<String>();
  final List<ClientMessage> sent = <ClientMessage>[];
  bool closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String frame) => sent.add(decodeClient(frame).body);

  /// The server sends [message].
  void serverSends(ServerMessage message) => _incoming.add(encodeServer(message));

  /// The socket drops.
  void drop() => unawaited(_incoming.close());

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Hands out [FakeTransport]s and records every connect.
class FakeNetwork {
  final List<FakeTransport> opened = <FakeTransport>[];
  bool refuseConnections = false;

  FakeTransport get last => opened.last;

  Future<Transport> connect(Uri uri) async {
    if (refuseConnections) throw StateError('connection refused');
    final transport = FakeTransport();
    opened.add(transport);
    return transport;
  }
}

/// Loads the bundled fonts so widget text has real glyph metrics.
Future<void> loadFonts() => loadBrutalFonts();

RoomView roomView({int hand = 1, int? activeSeat, int pot = 0, List<SeatView>? seats, int? deadline}) => RoomView(
  roomCode: 'KQ7M',
  handNumber: hand,
  phase: WirePhase.preFlop,
  activeSeat: activeSeat,
  currentHighBet: 0,
  minRaiseTo: 0,
  totalPot: pot,
  pots: const <PotView>[],
  seats: seats ?? const <SeatView>[],
  paused: false,
  turnDeadlineMs: deadline,
  spectatorCount: 0,
);

Snapshot snapshot({int version = 1, int serverTime = 0, int nextActionSeq = 0, RoomView? view}) =>
    Snapshot(stateVersion: version, serverTime: serverTime, nextActionSeq: nextActionSeq, view: view ?? roomView());

// ---------------------------------------------------------------------------------------------
// App-level fakes
// ---------------------------------------------------------------------------------------------

/// A host server that never touches the native library.
class FakeHostServer implements HostServer {
  FakeHostServer({this.supported = true, this.failure, this.portNumber = 7878});

  final bool supported;
  final HostException? failure;
  final int portNumber;
  int started = 0;
  int ensured = 0;
  int stopped = 0;
  bool running = false;

  @override
  bool get isSupported => supported;

  @override
  int? get port => running ? portNumber : null;

  @override
  Future<int> startServer() async {
    if (failure != null) throw failure!;
    running = true;
    started++;
    return portNumber;
  }

  @override
  Future<HostedRoom> hostGame({required String hostName, required RoomConfig config}) async {
    await startServer();
    return HostedRoom(roomCode: 'KQ7M', playerId: 'p_host', sessionToken: 'sess', hostToken: 'host-secret', port: portNumber);
  }

  @override
  Future<void> ensureRunning() async => ensured++;

  @override
  Future<void> stop() async {
    running = false;
    stopped++;
  }
}

/// Everything a page test needs: fakes wired through provider overrides.
class TestHarness {
  TestHarness({FakeHostServer? host, TokenStore? tokens, this.addresses = const <String>['192.168.1.5']})
    : host = host ?? FakeHostServer(),
      tokens = tokens ?? MemoryTokenStore();

  final FakeHostServer host;
  final TokenStore tokens;
  final List<String> addresses;
  final FakeNetwork network = FakeNetwork();
  final FakeWakeLock wakeLock = FakeWakeLock();
  final FakeHaptics haptics = FakeHaptics();
  final FakeSound sound = FakeSound();
  DateTime clock = DateTime.fromMillisecondsSinceEpoch(1730000000000);

  /// Wraps [child] in a Refena scope with every service replaced by a fake.
  Widget scope(Widget child) => RefenaScope(
    overrides: [
      hostServerProvider.overrideWithValue(host),
      tokenStoreProvider.overrideWithValue(tokens),
      wakeLockProvider.overrideWithValue(wakeLock),
      hapticsProvider.overrideWithValue(haptics),
      soundProvider.overrideWithValue(sound),
      localAddressesProvider.overrideWithValue(() async => addresses),
      clockProvider.overrideWithValue(() => clock),
      roomClientFactoryProvider.overrideWithValue((uri, first) => RoomClient(uri: uri, firstMessage: first, transport: network.connect)),
    ],
    child: child,
  );
}

class FakeHaptics extends Haptics {
  FakeHaptics();

  int turns = 0;
  int taps = 0;

  @override
  Future<void> yourTurn() async => turns++;

  @override
  Future<void> tap() async => taps++;
}

class FakeSound extends Sound {
  FakeSound();

  int turns = 0;

  @override
  Future<void> yourTurn() async => turns++;
}

class FakeWakeLock implements WakeLock {
  int enabled = 0;
  int disabled = 0;

  @override
  Future<void> enable() async => enabled++;

  @override
  Future<void> disable() async => disabled++;
}

SeatView seatView(
  int index,
  String name, {
  int chips = 1000,
  int bet = 0,
  bool folded = false,
  bool allIn = false,
  bool away = false,
  bool connected = true,
}) => SeatView(
  seatIndex: index,
  playerId: 'p_$index',
  name: name,
  chips: chips,
  streetBet: bet,
  hasFolded: folded,
  isAllIn: allIn,
  isSittingOut: away,
  isConnected: connected,
);
