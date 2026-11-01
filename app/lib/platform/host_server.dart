/// Platform seam for hosting the embedded game server (ADR-014).
///
/// Native builds get the real implementation (the Rust bridge, Phase 3); web gets an
/// "unsupported" stub. Feature code only talks to [HostServer].
library;

export 'host_server_stub.dart' if (dart.library.io) 'host_server_io.dart';

/// Contract implemented by each platform variant of the host server.
abstract interface class HostServer {
  /// Whether this platform can host a game at all.
  bool get isSupported;
}
