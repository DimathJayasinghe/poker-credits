import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = Logger('Session');

/// The link plus the room as the server last described it.
class SessionState {
  const SessionState({this.link = const LinkState(), this.room = const RoomState(), this.serverUri, this.isHost = false});

  final LinkState link;
  final RoomState room;

  /// Server this session talks to, once attached.
  final String? serverUri;
  final bool isHost;

  bool get isAttached => serverUri != null;

  SessionState copyWith({LinkState? link, RoomState? room}) =>
      SessionState(link: link ?? this.link, room: room ?? this.room, serverUri: serverUri, isHost: isHost);
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier());

/// Owns the [RoomClient] of the room the user is in and turns its messages into [SessionState].
class SessionNotifier extends Notifier<SessionState> {
  RoomClient? _client;
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  @override
  SessionState init() => const SessionState();

  /// Connects to [uri] and sends [first] (`RESUME` for a host, `JOIN_ROOM` for a player).
  void attach({required Uri uri, required ClientMessage first, required bool host}) {
    unawaited(_detach());
    final client = ref.read(roomClientFactoryProvider)(uri, first);
    _client = client;
    state = SessionState(serverUri: uri.toString(), isHost: host);
    _subscriptions
      ..add(client.states.listen(_onLink))
      ..add(client.messages.listen(_onMessage))
      ..add(client.credentialChanges.listen(_onCredentials));
    client.start();
  }

  /// Sends a message; false when there is no live socket (nothing is queued).
  bool send(ClientMessage message) => _client?.send(message) ?? false;

  /// Reconnects at once: the app returned to the foreground, or the user pressed Retry.
  void reconnect() => _client?.reconnectNow();

  /// Leaves the room: closes the socket and forgets the stored session.
  Future<void> leave() async {
    await _detach();
    await ref.read(tokenStoreProvider).clear();
    state = const SessionState();
  }

  /// Closes the client without touching the stored session (app shutdown).
  @override
  void dispose() {
    unawaited(_detach());
    super.dispose();
  }

  Future<void> _detach() async {
    // Everything that stops timers runs before the first await, so a disposed scope leaves
    // nothing pending.
    final client = _client;
    _client = null;
    final subscriptions = List<StreamSubscription<Object?>>.of(_subscriptions);
    _subscriptions.clear();
    final closing = client?.close();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    await closing;
  }

  void _onLink(LinkState link) {
    state = state.copyWith(link: link);
    final failure = link.failure;
    if (failure != null && failure != LinkFailure.refused && failure != LinkFailure.versionMismatch && failure != LinkFailure.rateLimited) {
      // The room or the session is gone; the stored tokens are useless now.
      unawaited(ref.read(tokenStoreProvider).clear());
    }
  }

  void _onMessage(Envelope<ServerMessage> envelope) {
    final now = ref.read(clockProvider)();
    var room = state.room.apply(envelope.body, localNow: now);
    if (room.needsResync) {
      _log.info('state version gap, reconnecting for a fresh snapshot');
      room = room.resyncRequested();
      _client?.reconnectNow();
    }
    state = state.copyWith(room: room);
  }

  void _onCredentials(RoomCredentials credentials) {
    final uri = state.serverUri;
    if (uri == null) return;
    unawaited(
      ref
          .read(tokenStoreProvider)
          .write(
            StoredSession(
              serverUri: uri,
              roomCode: credentials.roomCode,
              sessionToken: credentials.sessionToken,
              hostToken: credentials.hostToken,
              playerId: credentials.playerId,
            ),
          ),
    );
  }
}
