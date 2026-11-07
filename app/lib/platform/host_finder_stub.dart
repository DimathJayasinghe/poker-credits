import 'dart:async';

import 'package:poker_credits/platform/host_finder.dart';

/// Web cannot open sockets to LAN hosts; the join page asks for the address instead.
HostFinder createHostFinder() => const _NoFinder();

final class _NoFinder implements HostFinder {
  const _NoFinder();

  @override
  bool get isSupported => false;

  @override
  HostSearch search(String roomCode) => _Done();

  @override
  LobbyBrowse browse() => _NoBrowse();

  @override
  Future<String?> fingerprintOf(String hostAndPort) async => null;

  @override
  Future<bool> speaksPlainHttp(String hostAndPort) async => false;
}

final class _NoBrowse implements LobbyBrowse {
  @override
  Stream<List<DiscoveredLobby>> get lobbies => const Stream<List<DiscoveredLobby>>.empty();

  @override
  Future<void> get done async {}

  @override
  void cancel() {}
}

final class _Done implements HostSearch {
  @override
  Future<DiscoveredHost?> get result async => null;

  @override
  void cancel() {}
}
