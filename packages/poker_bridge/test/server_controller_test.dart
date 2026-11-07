import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_bridge/poker_bridge.dart';

const _config = RsServerConfig(
  port: 0,
  exposeOnLan: false,
  dataDir: '',
  serverName: 'test',
);

class _FakeServer implements NativeServer {
  _FakeServer();

  final _controller = StreamController<RsServerEvent>();
  bool running = true;
  bool panicOnProbe = false;
  int stops = 0;

  @override
  int get port => 7878;

  @override
  String? get fingerprint => null;

  @override
  Stream<RsServerEvent> events() => _controller.stream;

  @override
  Future<bool> isRunning() async {
    if (panicOnProbe) {
      throw PanicException('boom');
    }
    return running;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<RsCreatedRoom> createRoom(String hostName, RsRoomConfig config) async {
    if (hostName.isEmpty) {
      throw const RsRoomError(code: 'INVALID_NAME', message: 'name');
    }
    return const RsCreatedRoom(
      roomCode: 'KQ7M',
      playerId: 'p1',
      sessionToken: 's',
      hostToken: 'h',
    );
  }

  void emit(RsServerEvent event) => _controller.add(event);
}

void main() {
  late List<_FakeServer> started;
  late ServerController controller;

  setUp(() {
    started = [];
    controller = ServerController(
      starter: (config) async {
        final server = _FakeServer();
        started.add(server);
        return server;
      },
    );
  });

  tearDown(() => controller.dispose());

  test('start twice starts one server', () async {
    await Future.wait([controller.start(_config), controller.start(_config)]);
    await controller.start(_config);
    expect(started, hasLength(1));
    expect(controller.port, 7878);
  });

  test('server events reach listeners', () async {
    final seen = <RsServerEvent>[];
    controller.events.listen(seen.add);
    await controller.start(_config);
    started.single.emit(
      const RsServerEvent(kind: RsServerEventKind.listening, value: 7878),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen.single.value, 7878);
  });

  test('stop is idempotent and forgets the server', () async {
    await controller.start(_config);
    await controller.stop();
    await controller.stop();
    expect(started.single.stops, 1);
    expect(controller.hasServer, isFalse);
  });

  test('ensureRunning restarts a server that is no longer running', () async {
    await controller.start(_config);
    started.single.running = false;
    await controller.ensureRunning(_config);
    expect(started, hasLength(2));
  });

  test(
    'a panic while probing is survived and the server is restarted',
    () async {
      await controller.start(_config);
      started.single.panicOnProbe = true;
      await controller.ensureRunning(_config);
      expect(started, hasLength(2));
      expect(controller.hasServer, isTrue);
    },
  );

  test('a panic while starting becomes a typed exception', () async {
    final failing = ServerController(
      starter: (_) async => throw PanicException('boom'),
    );
    await expectLater(
      failing.start(_config),
      throwsA(
        isA<BridgeException>().having(
          (e) => e.kind,
          'kind',
          BridgeFailureKind.panic,
        ),
      ),
    );
    expect(failing.hasServer, isFalse);
    // The controller is usable again after the failure.
    await expectLater(failing.start(_config), throwsA(isA<BridgeException>()));
  });

  test(
    'createRoom passes through and maps refusals to a coded exception',
    () async {
      const room = RsRoomConfig(
        startingChips: 0,
        smallBlind: 0,
        bigBlind: 0,
        ante: 0,
        isTournament: false,
        blindLevelMinutes: 10,
        turnTimeLimitSeconds: 30,
        cardMode: RsCardMode.physical,
      );
      await expectLater(
        controller.createRoom('Host', room),
        throwsA(isA<BridgeException>()),
      );
      await controller.start(_config);
      expect((await controller.createRoom('Host', room)).roomCode, 'KQ7M');
      await expectLater(
        controller.createRoom('', room),
        throwsA(
          isA<BridgeException>()
              .having((e) => e.kind, 'kind', BridgeFailureKind.room)
              .having((e) => e.code, 'code', 'INVALID_NAME'),
        ),
      );
    },
  );

  test('a busy port maps to BridgeFailureKind.bind', () async {
    final failing = ServerController(
      starter: (_) async => throw const RsServerError(
        kind: RsServerErrorKind.bind,
        target: '0.0.0.0:7878',
        message: 'in use',
      ),
    );
    await expectLater(
      failing.start(_config),
      throwsA(
        isA<BridgeException>().having(
          (e) => e.kind,
          'kind',
          BridgeFailureKind.bind,
        ),
      ),
    );
  });
}
