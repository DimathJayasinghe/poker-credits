import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_protocol/poker_protocol.dart';

final _log = Logger('HostServer');

/// Default port for host mode (docs/ARCHITECTURE.md 6.1). Players type it, so it stays fixed
/// unless it is busy.
const int defaultHostPort = 7878;

/// Native platforms: runs the Rust server inside the app. This file and
/// `packages/poker_bridge` are the only places that touch the bridge.
HostServer createHostServer() => NativeHostServer();

/// [HostServer] backed by `ServerController`.
final class NativeHostServer implements HostServer {
  NativeHostServer({ServerController? controller, Future<String> Function()? dataDir, Future<void> Function()? init})
    : _controller = controller ?? ServerController(),
      _dataDir = dataDir ?? _defaultDataDir,
      _init = init ?? (() => initBridge());

  final ServerController _controller;
  final Future<String> Function() _dataDir;
  final Future<void> Function() _init;
  RsServerConfig? _lastConfig;

  @override
  bool get isSupported => true;

  @override
  int? get port => _controller.port;

  @override
  Future<int> startServer() async {
    return _guard(() async {
      await _init();
      // The default port, then one fixed fallback (players probe exactly these two), and only then
      // any free port: players cannot find that one by code, they need the typed address.
      for (final port in <int>[defaultHostPort, defaultHostPort + 1, 0]) {
        try {
          await _controller.start(await _configFor(port: port));
          break;
        } on BridgeException catch (error) {
          if (error.kind != BridgeFailureKind.bind || port == 0) rethrow;
          _log.warning('port $port is busy, trying the next one');
        }
      }
      return _controller.port ?? 0;
    });
  }

  @override
  Future<HostedRoom> hostGame({required String hostName, required RoomConfig config}) async {
    final port = await startServer();
    return _guard(() async {
      final created = await _controller.createRoom(hostName, _toBridge(config));
      return HostedRoom(
        roomCode: created.roomCode,
        playerId: created.playerId,
        sessionToken: created.sessionToken,
        hostToken: created.hostToken,
        port: port,
      );
    });
  }

  @override
  Future<void> ensureRunning() async {
    final config = _lastConfig;
    if (config == null) return;
    await _guard(() async {
      await _init();
      await _controller.ensureRunning(config);
    });
  }

  @override
  Future<void> stop() async {
    try {
      await _controller.stop();
    } on BridgeException catch (error) {
      _log.warning('stop failed', error);
    }
  }

  Future<RsServerConfig> _configFor({required int port}) async {
    final config = RsServerConfig(port: port, exposeOnLan: true, dataDir: await _dataDir(), serverName: Strings.appName);
    _lastConfig = config;
    return config;
  }

  static RsRoomConfig _toBridge(RoomConfig c) => RsRoomConfig(
    startingChips: c.startingChips,
    smallBlind: c.smallBlind,
    bigBlind: c.bigBlind,
    ante: c.ante,
    isTournament: c.isTournament,
    blindLevelMinutes: c.blindLevelMinutes,
    turnTimeLimitSeconds: c.turnTimeLimitSeconds,
  );

  static Future<String> _defaultDataDir() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}${Platform.pathSeparator}rooms';
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on BridgeException catch (error) {
      throw switch (error.kind) {
        BridgeFailureKind.bind => HostException(HostFailure.portBusy, error.message),
        BridgeFailureKind.dataDir => HostException(HostFailure.storage, error.message),
        BridgeFailureKind.room => HostException(HostFailure.refused, error.message, code: error.code),
        BridgeFailureKind.panic => HostException(HostFailure.crashed, error.message),
        BridgeFailureKind.unknown => HostException(HostFailure.unavailable, error.message),
      };
    }
  }
}
