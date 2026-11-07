import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/features.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/platform/token_store.dart';
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

  /// Where this session's tokens are saved. A single-player game keeps its own, so it never
  /// replaces or erases the hosted or joined game saved in [TokenSlot.main].
  TokenSlot _slot = TokenSlot.main;

  /// The server knows this session: a `RESUME` was accepted or a join went through. Until then a
  /// failure belongs to the join attempt and must not touch the stored session of another room.
  bool _established = false;
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  /// A search for the host's new address ran during the current outage. Reset when the link is
  /// live again or the user presses Retry.
  bool _rediscoveryTried = false;

  @override
  SessionState init() => const SessionState();

  /// Connects to [uri] and sends [first] (`RESUME` to re-attach, `JOIN_ROOM` to join).
  /// [playerId] is known when re-attaching from a stored session. [keepRoom] keeps showing the
  /// last room view while the new connection comes up (the host moved to another address): the
  /// next `SNAPSHOT` replaces it, so nothing stale survives. [slot] is where the tokens of this
  /// session are saved.
  void attach({
    required Uri uri,
    required ClientMessage first,
    required bool host,
    String? playerId,
    bool keepRoom = false,
    TokenSlot slot = TokenSlot.main,
  }) {
    unawaited(_detach());
    _slot = slot;
    final client = ref.read(roomClientFactoryProvider)(uri, first);
    _client = client;
    _established = first is Resume;
    final previous = state;
    state = SessionState(
      room: keepRoom ? previous.room : const RoomState(),
      serverUri: uri.toString(),
      isHost: host,
      playerId: playerId,
      role: keepRoom ? previous.role : null,
    );
    _subscriptions
      ..add(client.states.listen(_onLink))
      ..add(client.messages.listen(_onMessage))
      ..add(client.credentialChanges.listen(_onCredentials));
    client.start();
  }

  /// Shows [failure] for [uri] without opening a connection, for a host the app already knows it
  /// cannot reach safely (an older version that speaks no TLS). The state is what a failed
  /// [attach] would leave, so the screens need no special case.
  void refuse({required Uri uri, required LinkFailure failure}) {
    unawaited(_detach());
    _established = false;
    state = SessionState(
      serverUri: uri.toString(),
      link: LinkState(phase: LinkPhase.failed, failure: failure),
    );
  }

  /// Sends a message; false when there is no live socket (nothing is queued).
  bool send(ClientMessage message) => _client?.send(message) ?? false;

  /// Reconnects at once: the app returned to the foreground, or the user pressed Retry.
  void reconnect() {
    _rediscoveryTried = false;
    _client?.reconnectNow();
  }

  /// Leaves the room: closes the socket and forgets the stored session.
  Future<void> leave() async {
    final forget = _established;
    _established = false;
    // The synchronous part of detaching (timers, subscriptions) runs at once. Closing the socket
    // can take a while when the peer is gone, so nothing that matters waits for it.
    final detaching = _detach();
    state = const SessionState();
    if (forget) await ref.read(tokenStoreProvider).clear(slot: _slot);
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
    if (link.isLive) _rediscoveryTried = false;
    // A guest whose host does not answer after a few attempts looks for the room again: the host
    // may have a new address (Wi-Fi reconnect, DHCP lease) and the room code finds it.
    if (!state.isHost && _established && !link.isLive && link.failure == null && link.attempt >= 3 && !_rediscoveryTried) {
      _rediscoveryTried = true;
      unawaited(rediscover());
    }
    final failure = link.failure;
    if (_established &&
        failure != null &&
        failure != LinkFailure.refused &&
        failure != LinkFailure.versionMismatch &&
        failure != LinkFailure.updateRequired &&
        failure != LinkFailure.hostNotTrusted &&
        failure != LinkFailure.hostOutdated &&
        failure != LinkFailure.rateLimited) {
      // The room or the session is gone; the stored tokens are useless now.
      unawaited(ref.read(tokenStoreProvider).clear(slot: _slot));
    }
  }

  /// Looks for the stored room by its code on the local network and, if the host moved, resumes
  /// there. The server still checks the session token, so a wrong answer cannot get anybody in.
  Future<void> rediscover() async {
    final finder = ref.read(hostFinderProvider);
    final stored = await ref.read(tokenStoreProvider).read(slot: _slot);
    if (stored == null || stored.isHost || !finder.isSupported) return;
    final uri = Uri.tryParse(stored.serverUri);
    if (uri == null || !JoinLink.isLanAddress(uri.host)) return;
    final found = await finder.search(stored.roomCode).result;
    if (found == null || state.serverUri != stored.serverUri || state.link.isLive) return;
    // A host that moved still shows the certificate this device pinned. Another device that
    // answers for the same room code does not get the session token.
    final pin = pinOf(uri);
    if (pin != null && found.fingerprint != pin) {
      _log.warning('a device answered for room ${stored.roomCode} with another certificate; ignoring it');
      return;
    }
    final movedBase = Uri.tryParse('${uri.scheme}://${found.hostAndPort}${uri.path}');
    final moved = movedBase == null ? null : withPin(movedBase, pin);
    if (moved == null || moved == uri) return;
    _log.info('host of room ${stored.roomCode} moved');
    await ref
        .read(tokenStoreProvider)
        .write(
          StoredSession(
            serverUri: moved.toString(),
            roomCode: stored.roomCode,
            sessionToken: stored.sessionToken,
            playerId: stored.playerId,
          ),
          slot: _slot,
        );
    if (_client == null || state.link.isLive) return;
    attach(
      uri: moved,
      first: Resume(roomCode: stored.roomCode, sessionToken: stored.sessionToken, features: appFeatures),
      host: false,
      playerId: stored.playerId,
      keepRoom: true,
      slot: _slot,
    );
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
            slot: _slot,
          ),
    );
  }
}
