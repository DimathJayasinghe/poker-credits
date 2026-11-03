import 'package:logging/logging.dart';
import 'package:poker_credits/platform/wake_lock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final _log = Logger('WakeLock');

WakeLock createWakeLock() => const _PluginWakeLock();

final class _PluginWakeLock implements WakeLock {
  const _PluginWakeLock();

  @override
  Future<void> enable() => _run(() => WakelockPlus.enable());

  @override
  Future<void> disable() => _run(() => WakelockPlus.disable());

  Future<void> _run(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error) {
      _log.warning('wake lock unavailable', error);
    }
  }
}
