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
  const SessionState({
    this.link = const LinkState(),
    this.room = const RoomState(),
    this.serverUri,
    this.isHost = false,
    this.playerId,
    this.role,
  });

  final LinkState link;
  final RoomState room;

  /// Server this session talks to, once attached.
  final String? serverUri;
  final bool isHost;

  /// This device's player id, once the server told it (`JOINED`, `ROOM_CREATED`) or the stored
  /// session knew it.
  final String? playerId;

  /// Role from `JOINED`; `null` after a plain `RESUME` (use [isSeated] then).
  final Role? role;

  bool get isAttached => serverUri != null;

  /// Whether this device has a seat in the room view. The server decides; spectators have none.
  bool get isSeated {
    final id = playerId;
    final view = room.view;
    return id != null && view != null && view.seats.any((seat) => seat.playerId == id);
  }

  /// The seat of this device, if any.
  SeatView? get mySeat {
    final id = playerId;
    final view = room.view;
    if (id == null || view == null) return null;
    for (final seat in view.seats) {
      if (seat.playerId == id) return seat;
    }
    return null;
  }

  SessionState copyWith({LinkState? link, RoomState? room, String? playerId, Role? role}) => SessionState(
    link: link ?? this.link,
    room: room ?? this.room,
    serverUri: serverUri,
    isHost: isHost,
    playerId: playerId ?? this.playerId,
    role: role ?? this.role,
  );
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier());

/// Owns the [RoomClient] of the room the user is in and turns its messages into [SessionState].
class SessionNotifier extends Notifier<SessionState> {
  RoomClient? _client;

  /// The server knows this session: a `RESUME` was accepted or a join went through. Until then a
  /// failure belongs to the join attempt and must not touch the stored session of another room.
  bool _established = false;
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  @override
  SessionState init() => const SessionState();

  /// Connects to [uri] and sends [first] (`RESUME` to re-attach, `JOIN_ROOM` to join).
  /// [playerId] is known when re-attaching from a stored session.
  void attach({required Uri uri, required ClientMessage first, required bool host, String? playerId}) {
    unawaited(_detach());
    final client = ref.read(roomClientFactoryProvider)(uri, first);
    _client = client;
    _established = first is Resume;
    state = SessionState(serverUri: uri.toString(), isHost: host, playerId: playerId);
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
    final forget = _established;
    _established = false;
    // The synchronous part of detaching (timers, subscriptions) runs at once. Closing the socket
    // can take a while when the peer is gone, so nothing that matters waits for it.
    final detaching = _detach();
    state = const SessionState();
    if (forget) await ref.read(tokenStoreProvider).clear();
    unawaited(detaching.catchError((Object error) => _log.info('closing the socket failed: $error')));
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
    if (_established &&
        failure != null &&
        failure != LinkFailure.refused &&
        failure != LinkFailure.versionMismatch &&
        failure != LinkFailure.rateLimited) {
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
    final body = envelope.body;
    state = body is Joined ? state.copyWith(room: room, playerId: body.playerId, role: body.role) : state.copyWith(room: room);
  }

  void _onCredentials(RoomCredentials credentials) {
    final uri = state.serverUri;
    if (uri == null) return;
    _established = true;
    final id = credentials.playerId;
    if (id != null && id != state.playerId) state = state.copyWith(playerId: id);
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
