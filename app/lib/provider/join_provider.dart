import 'package:logging/logging.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = Logger('Join');

/// Joins a game somebody else hosts, or goes back to one this device was playing in.
///
/// It owns no state of its own: the socket and everything the server says live in
/// [sessionProvider]; this only builds the first message.
final joinProvider = Provider<JoinService>((ref) => JoinService(ref));

class JoinService {
  JoinService(this._ref);

  final Ref _ref;

  /// Whether this platform can look for a host by room code.
  bool get canFind => _ref.read(hostFinderProvider).isSupported;

  /// Looks for the device that hosts [roomCode] on the local network.
  HostSearch find(String roomCode) => _ref.read(hostFinderProvider).search(roomCode);

  /// Lists the open games on the local network.
  LobbyBrowse browse() => _ref.read(hostFinderProvider).browse();

  /// Opens a socket to [link] and sends `JOIN_ROOM`. Any earlier attempt is dropped first (a
  /// fixable error such as a bad name is retried this way, with the fields corrected).
  void join({required JoinLink link, required String name, bool spectator = false}) {
    _ref
        .notifier(sessionProvider)
        .attach(
          uri: link.webSocketUri,
          first: JoinRoom(roomCode: link.roomCode, name: name.trim(), spectator: spectator),
          host: false,
        );
  }

  /// Re-attaches to the room this device last played in as a guest. Returns false when there is
  /// no stored guest session. The server decides whether the session is still valid.
  Future<bool> restore() async {
    final stored = await _ref.read(tokenStoreProvider).read();
    if (stored == null || stored.isHost) return false;
    final uri = Uri.tryParse(stored.serverUri);
    if (uri == null) return false;
    _log.info('resuming room ${stored.roomCode}');
    _ref
        .notifier(sessionProvider)
        .attach(
          uri: uri,
          first: Resume(roomCode: stored.roomCode, sessionToken: stored.sessionToken),
          host: false,
          playerId: stored.playerId,
        );
    return true;
  }

  /// Gives up an attempt or leaves the room; forgets the stored session only if one was made.
  Future<void> leave() => _ref.notifier(sessionProvider).leave();
}
