import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:logging/logging.dart';

import 'bridge_exception.dart';
import 'rust/api/server.dart';

final _log = Logger('poker_bridge');

/// Runs a bridge call and turns every failure into a [BridgeException]. A Rust panic arrives
/// as `PanicException` (see `docs/SPIKE_BRIDGE_FINDINGS.md`): it is logged with its backtrace
/// and does not take the app down.
Future<T> guardBridge<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on BridgeException {
    rethrow;
  } on PanicException catch (error) {
    _log.severe('Rust panicked inside a bridge call', error);
    throw BridgeException(
      BridgeFailureKind.panic,
      'The embedded server hit an internal error.',
      nativeTrace: error.message,
    );
  } on RsServerError catch (error) {
    throw BridgeException(switch (error.kind) {
      RsServerErrorKind.bind => BridgeFailureKind.bind,
      RsServerErrorKind.dataDir => BridgeFailureKind.dataDir,
      RsServerErrorKind.tls => BridgeFailureKind.tls,
    }, error.toString());
  } on RsRoomError catch (error) {
    throw BridgeException(
      BridgeFailureKind.room,
      error.message,
      code: error.code,
    );
  } on Object catch (error) {
    _log.warning('bridge call failed', error);
    throw BridgeException(BridgeFailureKind.unknown, error.toString());
  }
}
