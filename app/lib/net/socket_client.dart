import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/net/backoff.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/features.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:poker_credits/net/transport.dart';
import 'package:poker_protocol/poker_protocol.dart';

final _log = Logger('RoomClient');

/// What is needed to re-attach to a room (kept in secure storage by the app).
class RoomCredentials {
  const RoomCredentials({required this.roomCode, required this.sessionToken, this.hostToken, this.playerId});

  final String roomCode;
  final String sessionToken;

  /// Present only for the host.
  final String? hostToken;
  final String? playerId;
}

/// One client connection to a room, with automatic reconnect.
///
/// The first message ([firstMessage]) is `JOIN_ROOM`, `CREATE_ROOM` or `RESUME`. After a lost
/// socket the client always sends `RESUME` with the stored credentials and the last state
/// version it saw (docs/API_AND_EVENTS.md section 5). It never merges state: every `SNAPSHOT`
/// replaces the view (see `RoomState`).
class RoomClient {
  RoomClient({
    required this.uri,
    required ClientMessage firstMessage,
    TransportFactory? transport,
    Backoff? backoff,
    DateTime Function()? now,
    this.pingEvery = const Duration(seconds: 15),
    this.idleAfter = const Duration(seconds: 45),
    this.stableAfter = const Duration(seconds: 10),
  }) : _first = firstMessage,
       _connect = transport ?? connectWebSocket,
       _backoff = backoff ?? Backoff(),
       _now = now ?? DateTime.now {
    _credentials = switch (firstMessage) {
      Resume(:final roomCode, :final sessionToken, :final hostToken) => RoomCredentials(
        roomCode: roomCode,
        sessionToken: sessionToken,
        hostToken: hostToken,
      ),
      _ => null,
    };
  }

  final Uri uri;
  final Duration pingEvery;
  final Duration idleAfter;
  final Duration stableAfter;

  final ClientMessage _first;
  final TransportFactory _connect;
  final Backoff _backoff;
  final DateTime Function() _now;

  final _messages = StreamController<Envelope<ServerMessage>>.broadcast();
  final _states = StreamController<LinkState>.broadcast();
  final _credentialChanges = StreamController<RoomCredentials>.broadcast();

  LinkState _state = const LinkState();
  RoomCredentials? _credentials;
  Transport? _transport;
  StreamSubscription<String>? _subscription;
  Timer? _retryTimer;
  Timer? _pingTimer;
  Timer? _idleTimer;
  DateTime? _liveSince;
  DateTime? _downSince;
  int _lastStateVersion = -1;
  int _generation = 0;
  int _insecureAttempts = 0;
  bool _closed = false;

  /// Every decoded server message, in order.
  Stream<Envelope<ServerMessage>> get messages => _messages.stream;

  /// Link changes.
  Stream<LinkState> get states => _states.stream;

  /// The link now.
  LinkState get state => _state;

  /// Credentials, once known; emitted again when they change (persist them).
  RoomCredentials? get credentials => _credentials;
  Stream<RoomCredentials> get credentialChanges => _credentialChanges.stream;

  /// Opens the first connection.
  void start() {
    if (_closed || _state.phase != LinkPhase.idle) return;
    unawaited(_open());
  }

  /// Sends a message on the current socket. Returns false when there is no live socket (the
  /// caller decides whether to retry); nothing is queued.
  bool send(ClientMessage message, {String? reqId}) {
    final transport = _transport;
    if (transport == null || _closed) return false;
    try {
      transport.send(encodeClient(message, reqId: reqId));
      return true;
    } on Object catch (error) {
      _log.warning('send failed', error);
      _lost(_generation);
      return false;
    }
  }

  /// Drops the socket and reconnects at once (app returned to the foreground, a gap in state
  /// versions, or the user pressed Retry). The backoff starts over.
  void reconnectNow() {
    if (_closed || _state.phase == LinkPhase.idle) return;
    _backoff.reset();
    _retryTimer?.cancel();
    final old = _transport;
    _teardown();
    unawaited(old?.close().catchError((Object _) {}));
    _downSince ??= _now();
    unawaited(_open());
  }

  /// Closes for good.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    final transport = _transport;
    _teardown();
    _setState(LinkState(phase: LinkPhase.closed, downSince: _downSince));
    await transport?.close().catchError((Object _) {});
    await _messages.close();
    await _states.close();
    await _credentialChanges.close();
  }

  // -----------------------------------------------------------------------------------------

  Future<void> _open() async {
    if (_closed) return;
    final generation = ++_generation;
    _setState(LinkState(phase: LinkPhase.connecting, attempt: _backoff.attempts, downSince: _downSince));
    final Transport transport;
    try {
      transport = await _connect(uri);
      _insecureAttempts = 0;
    } on PinMismatch {
      // Not a glitch: somebody else answers at this address. Retrying would only hand it more
      // chances, so the link gives up and the user decides.
      _log.warning('the host showed a different certificate than the pinned one');
      if (generation == _generation) _fail(LinkFailure.hostNotTrusted, null);
      return;
    } on InsecureAddress {
      _log.warning('refusing a plaintext connection to another device');
      if (generation == _generation) _fail(LinkFailure.hostOutdated, null);
      return;
    } on NoSecureChannel {
      // One failed handshake can be a flaky network; two in a row on a first join mean the host is
      // not speaking TLS. A session that was accepted once (or is being resumed) did talk TLS to
      // that host, so a failed handshake there is the network or another device at the old address:
      // keep retrying, and let the search for the room code find the host's new address.
      _log.info('the host does not speak TLS');
      if (generation != _generation) return;
      final firstJoin = _credentials == null && _first is! Resume;
      if (firstJoin && ++_insecureAttempts >= 2) {
        _fail(LinkFailure.hostOutdated, null);
      } else {
        _scheduleRetry();
      }
      return;
    } on Object catch (error) {
      _log.info('connect failed: $error');
      if (generation == _generation) _scheduleRetry();
      return;
    }
    if (_closed || generation != _generation) {
      await transport.close().catchError((Object _) {});
      return;
    }
    _transport = transport;
    _subscription = transport.incoming.listen(
      (frame) => _onFrame(generation, frame),
      onError: (Object error) {
        _log.info('socket error: $error');
        _lost(generation);
      },
      onDone: () => _lost(generation),
    );
    _armTimers(generation);
    final handshake = _handshake();
    try {
      transport.send(encodeClient(handshake));
    } on Object catch (error) {
      _log.info('handshake send failed: $error');
      _lost(generation);
    }
  }

  ClientMessage _handshake() {
    final creds = _credentials;
    if (creds == null) return _first;
    return Resume(
      roomCode: creds.roomCode,
      sessionToken: creds.sessionToken,
      hostToken: creds.hostToken,
      lastStateVersion: _lastStateVersion < 0 ? null : _lastStateVersion,
      features: appFeatures,
    );
  }

  void _armTimers(int generation) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingEvery, (_) {
      if (generation == _generation) send(Ping(t: _now().millisecondsSinceEpoch));
    });
    _resetIdle(generation);
  }

  void _resetIdle(int generation) {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleAfter, () {
      _log.info('no frame for ${idleAfter.inSeconds}s, reconnecting');
      _lost(generation);
    });
  }

  void _onFrame(int generation, String frame) {
    if (generation != _generation || _closed) return;
    _resetIdle(generation);
    final Envelope<ServerMessage> envelope;
    try {
      envelope = decodeServer(frame);
    } on ProtocolFormatException catch (error) {
      _log.warning('dropping a bad frame: $error');
      return;
    }
    final message = envelope.body;
    switch (message) {
      case RoomCreated():
        _setCredentials(
          RoomCredentials(
            roomCode: message.roomCode,
            sessionToken: message.sessionToken,
            hostToken: message.hostToken,
            playerId: message.playerId,
          ),
        );
      case Joined():
        final first = _first;
        final code = first is JoinRoom ? first.roomCode : _credentials?.roomCode;
        if (code != null) {
          _setCredentials(
            RoomCredentials(roomCode: code, sessionToken: message.sessionToken, hostToken: _credentials?.hostToken, playerId: message.playerId),
          );
        }
      case Snapshot():
        _lastStateVersion = message.stateVersion;
        _goLive();
      case StateUpdate():
        if (message.stateVersion > _lastStateVersion) _lastStateVersion = message.stateVersion;
      case ErrorMessage():
        final failure = _fatal(message);
        if (failure != null) {
          _messages.add(envelope);
          _fail(failure, message.message);
          return;
        }
      case RoomCrashed():
        _messages.add(envelope);
        _fail(LinkFailure.roomCrashed, message.reason);
        return;
      case RoomExpired():
        _messages.add(envelope);
        _fail(LinkFailure.roomExpired, null);
        return;
      default:
        break;
    }
    _messages.add(envelope);
  }

  LinkFailure? _fatal(ErrorMessage message) {
    return switch (message.code) {
      ErrorCode.roomNotFound => LinkFailure.roomGone,
      ErrorCode.invalidSession => LinkFailure.invalidSession,
      ErrorCode.superseded => LinkFailure.superseded,
      ErrorCode.roomCrashed => LinkFailure.roomCrashed,
      ErrorCode.versionMismatch => LinkFailure.versionMismatch,
      ErrorCode.updateRequired => LinkFailure.updateRequired,
      // While joining or resuming this is the per-address block, followed by a close. On a live
      // link it is only a warning for a flooded frame: the server closes after the third strike,
      // and that ordinary drop reconnects with backoff on a fresh budget.
      ErrorCode.rateLimited when !_state.isLive => LinkFailure.rateLimited,
      // The server closes the socket after these while joining; once live they are not about us.
      ErrorCode.roomFull || ErrorCode.spectatorsFull when !_state.isLive => LinkFailure.refused,
      _ => null,
    };
  }

  void _goLive() {
    _liveSince = _now();
    _downSince = null;
    _setState(LinkState(phase: LinkPhase.live, attempt: _backoff.attempts));
  }

  void _fail(LinkFailure failure, String? message) {
    _retryTimer?.cancel();
    final transport = _transport;
    _teardown();
    unawaited(transport?.close().catchError((Object _) {}));
    _setState(LinkState(phase: LinkPhase.failed, failure: failure, message: message, downSince: _downSince ?? _now()));
  }

  void _lost(int generation) {
    if (generation != _generation || _closed) return;
    if (_state.phase == LinkPhase.failed) return;
    final liveFor = _liveSince == null ? null : _now().difference(_liveSince!);
    if (liveFor != null && liveFor >= stableAfter) _backoff.reset();
    _liveSince = null;
    final transport = _transport;
    _teardown();
    unawaited(transport?.close().catchError((Object _) {}));
    _downSince ??= _now();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_closed) return;
    _downSince ??= _now();
    final delay = _backoff.next();
    _setState(LinkState(phase: LinkPhase.waiting, attempt: _backoff.attempts, nextAttemptAt: _now().add(delay), downSince: _downSince));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_open()));
  }

  void _teardown() {
    _generation++;
    _pingTimer?.cancel();
    _idleTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _transport = null;
  }

  void _setCredentials(RoomCredentials credentials) {
    _credentials = credentials;
    _credentialChanges.add(credentials);
  }

  void _setState(LinkState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
