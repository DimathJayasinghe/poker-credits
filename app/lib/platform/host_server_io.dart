import 'package:poker_credits/platform/host_server.dart';

/// Native platforms: hosting is supported once the Rust bridge lands in Phase 3.
/// This is the only place that will import packages/poker_bridge.
HostServer createHostServer() => const _NativeHostServer();

final class _NativeHostServer implements HostServer {
  const _NativeHostServer();

  // Becomes true when the bridge can start the embedded server (Phase 3).
  @override
  bool get isSupported => false;
}
