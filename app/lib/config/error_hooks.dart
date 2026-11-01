import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('Error');

/// Installs global error hooks so nothing fails silently or kills the app (docs/RESILIENCE_AND_CRASH_HANDLING.md 2.2).
/// LocalSend only guards child isolates; the main isolate guard is our addition.
void installErrorHooks() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _log.severe('Flutter framework error: ${details.exceptionAsString()}', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _log.severe('Uncaught platform/async error', error, stack);
    return true;
  };
}

/// Zone handler for [runZonedGuarded], the last safety net around `runApp`.
void onZoneError(Object error, StackTrace stack) {
  _log.severe('Uncaught zone error', error, stack);
}
