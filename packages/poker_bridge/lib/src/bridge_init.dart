import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:logging/logging.dart';

import 'bridge_exception.dart';
import 'bridge_guard.dart';
import 'rust/api/logging.dart';
import 'rust/frb_generated.dart';

final _log = Logger('poker_bridge');

/// Loads the native library and routes Rust logs to the platform log. Call once at startup,
/// before using [ServerController]. Safe to call again; later calls do nothing.
///
/// [rustLogFilter] uses the `RUST_LOG` syntax. [libraryPath] loads the library from that file
/// instead of the one bundled with the app (end-to-end tests run against a `cargo build`).
///
/// Throws [BridgeException] if the library cannot be loaded.
Future<void> initBridge({
  String rustLogFilter = 'info',
  String? libraryPath,
}) async {
  if (RustLib.instance.initialized) {
    return;
  }
  await guardBridge(() async {
    await RustLib.init(
      externalLibrary: libraryPath == null
          ? null
          : ExternalLibrary.open(libraryPath),
    );
    initLogging(filter: rustLogFilter);
  });
  _log.info('native library loaded');
}
