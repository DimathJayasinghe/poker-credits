import 'package:poker_credits/platform/wake_lock.dart';

WakeLock createWakeLock() => const _NoWakeLock();

final class _NoWakeLock implements WakeLock {
  const _NoWakeLock();

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}
