import 'package:logging/logging.dart';

import 'bridge_exception.dart';
import 'bridge_guard.dart';
import 'rust/api/logging.dart';
import 'rust/frb_generated.dart';

final _log = Logger('poker_bridge');

/// Loads the native library and routes Rust logs to the platform log. Call once at startup,
/// before using [ServerController]. Safe to call again; later calls do nothing.
///
/// [rustLogFilter] uses the `RUST_LOG` syntax.
///
/// Throws [BridgeException] if the library cannot be loaded.
Future<void> initBridge({String rustLogFilter = 'info'}) async {
  if (RustLib.instance.initialized) {
    return;
  }
  await guardBridge(() async {
    await RustLib.init();
    initLogging(filter: rustLogFilter);
  });
  _log.info('native library loaded');
}
