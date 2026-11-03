import 'dart:async';

import 'package:logging/logging.dart';

import 'bridge_exception.dart';
import 'bridge_guard.dart';
import 'rust/api/server.dart';

final _log = Logger('poker_bridge');

/// The part of a running native server the controller needs. A seam so the controller can be
/// tested without the native library.
abstract interface class NativeServer {
  int get port;
  Stream<RsServerEvent> events();
  Future<bool> isRunning();
  Future<void> stop();
}

/// Starts a native server.
typedef NativeStarter = Future<NativeServer> Function(RsServerConfig config);

class _RustServer implements NativeServer {
  _RustServer(this._handle);

  final RsServerHandle _handle;

  @override
  int get port => _handle.port;

  @override
  Stream<RsServerEvent> events() => _handle.subscribe();

  @override
  Future<bool> isRunning() => _handle.isRunning();

  @override
  Future<void> stop() => _handle.stop();
}

Future<NativeServer> _startRust(RsServerConfig config) async =>
    _RustServer(await startServer(config: config));

/// Owns the embedded server for the host's app.
///
/// Every method throws [BridgeException] on failure and never anything else. After a
/// [BridgeFailureKind.panic] the controller forgets the server, so the next [ensureRunning]
/// starts a fresh one (rooms come back from the data folder).
class ServerController {
  ServerController({NativeStarter? starter}) : _starter = starter ?? _startRust;

  final NativeStarter _starter;
  final _events = StreamController<RsServerEvent>.broadcast();
  NativeServer? _server;
  StreamSubscription<RsServerEvent>? _subscription;
  Future<void>? _starting;

  /// Server events (listening, rooms restored, stopped). Broadcast: listen before [start].
  Stream<RsServerEvent> get events => _events.stream;

  /// The port in use, or `null` while no server is running.
  int? get port => _server?.port;

  bool get hasServer => _server != null;

  /// Starts the server. Does nothing when one is already running.
  Future<void> start(RsServerConfig config) =>
      _starting ??= _start(config)
        ..whenComplete(() => _starting = null).ignore();

  Future<void> _start(RsServerConfig config) async {
    if (_server != null) {
      return;
    }
    final server = await guardBridge(() => _starter(config));
    _server = server;
    _subscription = server.events().listen(
      _events.add,
      onError: (Object error) =>
          _log.warning('server event stream failed', error),
      onDone: () => _log.info('server event stream ended'),
    );
  }

  /// Makes sure a server is running, restarting it if it died. Call when the app returns to the
  /// foreground: the OS may have killed the listener while the app was in the background.
  Future<void> ensureRunning(RsServerConfig config) async {
    final server = _server;
    if (server != null) {
      bool alive;
      try {
        alive = await guardBridge(server.isRunning);
      } on BridgeException catch (error) {
        _log.warning('probe failed, restarting the server', error);
        alive = false;
      }
      if (alive) {
        return;
      }
      await _forget();
    }
    await start(config);
  }

  /// Stops the server. Harmless when none is running.
  Future<void> stop() async {
    final server = _server;
    if (server == null) {
      return;
    }
    // Stop first and let the event stream end by itself: the last event is `stopped`, which
    // listeners should see. Cancelling the subscription first would drop it.
    _server = null;
    await guardBridge(server.stop);
  }

  Future<void> _forget() async {
    _server = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  /// Stops the server and closes [events]. The controller cannot be used afterwards.
  Future<void> dispose() async {
    try {
      await stop();
    } on BridgeException catch (error) {
      _log.warning('stop failed while disposing', error);
    }
    await _subscription?.cancel();
    _subscription = null;
    await _events.close();
  }
}
