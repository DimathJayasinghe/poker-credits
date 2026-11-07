/// Platform seam: finding the device that hosts a room, from its room code alone (ADR-012, ADR-014).
library;

import 'dart:async';

import 'package:poker_credits/model/join_link.dart';

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

/// An open game found on the local network: a room still in its lobby with a free seat.
class DiscoveredLobby {
  const DiscoveredLobby({
    required this.hostAndPort,
    required this.roomCode,
    required this.hostName,
    required this.playerCount,
    required this.maxPlayers,
    this.isVirtual = false,
  });

  /// Reads one entry of the server's `lobbies` list. The answer comes from the network, so
  /// nothing in it is trusted: a malformed entry gives `null`, the name is cut to a printable
  /// length and the counts are clamped.
  static DiscoveredLobby? tryParse(Object? json, String hostAndPort) {
    if (json is! Map<String, dynamic>) return null;
    final code = json['roomCode'];
    final name = json['hostName'];
    final count = json['playerCount'];
    final max = json['maxPlayers'];
    if (code is! String || name is! String || count is! int || max is! int) return null;
    final normalized = JoinLink.normalizeRoomCode(code);
    if (normalized == null || max < 2 || max > 10) return null;
    final cleaned = name.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();
    return DiscoveredLobby(
      hostAndPort: hostAndPort,
      roomCode: normalized,
      hostName: cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned,
      playerCount: count.clamp(0, max),
      maxPlayers: max,
      isVirtual: json['cardMode'] == 'VIRTUAL',
    );
  }

  /// `address:port`, ready for `JoinLink`.
  final String hostAndPort;
  final String roomCode;
  final String hostName;
  final int playerCount;
  final int maxPlayers;

  /// The room deals cards in the app. Older hosts do not say, which means real cards.
  final bool isVirtual;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredLobby &&
      other.hostAndPort == hostAndPort &&
      other.roomCode == roomCode &&
      other.hostName == hostName &&
      other.playerCount == playerCount &&
      other.maxPlayers == maxPlayers &&
      other.isVirtual == isVirtual;

  @override
  int get hashCode => Object.hash(hostAndPort, roomCode, hostName, playerCount, maxPlayers, isVirtual);
}

/// A scan of the local network for open games. [lobbies] emits the full list each time it grows;
/// [done] completes when the scan is over (finished, timed out or cancelled). It never throws.
abstract interface class LobbyBrowse {
  Stream<List<DiscoveredLobby>> get lobbies;
  Future<void> get done;

  /// Stops probing; [done] completes.
  void cancel();
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

  /// Lists the open games on the local network.
  LobbyBrowse browse();
}
