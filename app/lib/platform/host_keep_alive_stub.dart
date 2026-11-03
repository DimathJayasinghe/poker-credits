import 'package:poker_credits/platform/host_keep_alive.dart';

HostKeepAlive createHostKeepAlive() => const _NoKeepAlive();

final class _NoKeepAlive implements HostKeepAlive {
  const _NoKeepAlive();

  @override
  Future<void> start(String roomCode) async {}

  @override
  Future<void> stop() async {}
}
