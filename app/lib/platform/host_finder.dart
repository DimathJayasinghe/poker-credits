/// Platform seam: finding the device that hosts a room, from its room code alone (ADR-012, ADR-014).
library;

export 'host_finder_stub.dart' if (dart.library.io) 'host_finder_io.dart';

/// Where a hosted room was found.
class DiscoveredHost {
  const DiscoveredHost(this.hostAndPort);

  /// `address:port`, ready for `JoinLink`.
  final String hostAndPort;

  @override
  bool operator ==(Object other) => other is DiscoveredHost && other.hostAndPort == hostAndPort;

  @override
  int get hashCode => hostAndPort.hashCode;
}

/// A search in progress. [result] completes with the host, or `null` when none answered (or the
/// search was cancelled). It never throws.
abstract interface class HostSearch {
  Future<DiscoveredHost?> get result;

  /// Stops probing; [result] completes with `null`.
  void cancel();
}

/// Looks for the host of a room on the local network.
abstract interface class HostFinder {
  /// False where the platform cannot probe the network (web): the app then asks for the address.
  bool get isSupported;

  HostSearch search(String roomCode);
}
