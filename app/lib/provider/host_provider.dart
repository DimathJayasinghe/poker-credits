import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = Logger('Host');

/// Where the host flow stands.
enum HostPhase { idle, starting, ready, failed }

class HostState {
  const HostState({this.phase = HostPhase.idle, this.room, this.addresses = const <String>[], this.error});

  final HostPhase phase;
  final HostedRoom? room;

  /// LAN addresses other devices can use, best first.
  final List<String> addresses;
  final HostException? error;

  /// `host:port` strings to type, one per address.
  List<String> get joinAddresses {
    final port = room?.port;
    if (port == null) return const <String>[];
    return <String>[for (final address in addresses) '$address:$port'];
  }
}

final hostProvider = NotifierProvider<HostNotifier, HostState>((ref) => HostNotifier());

/// Starts the embedded server, creates the room and connects the host's own UI to it over
/// loopback, exactly like any other client (ADR-004).
class HostNotifier extends Notifier<HostState> {
  @override
  HostState init() => const HostState();

  Uri _loopback(int port) => Uri.parse('ws://127.0.0.1:$port/v1/ws');

  /// Hosts a new game.
  Future<void> start({required String hostName, required RoomConfig config}) async {
    if (state.phase == HostPhase.starting) return;
    state = const HostState(phase: HostPhase.starting);
    try {
      final room = await ref.read(hostServerProvider).hostGame(hostName: hostName, config: config);
      await ref
          .read(tokenStoreProvider)
          .write(
            StoredSession(
              serverUri: _loopback(room.port).toString(),
              roomCode: room.roomCode,
              sessionToken: room.sessionToken,
              hostToken: room.hostToken,
              playerId: room.playerId,
            ),
          );
      final addresses = await _addresses();
      _connect(room);
      state = HostState(phase: HostPhase.ready, room: room, addresses: addresses);
    } on HostException catch (error) {
      _log.warning('hosting failed', error);
      state = HostState(phase: HostPhase.failed, error: error);
    }
  }

  /// Re-attaches to the room this device hosted before the app was closed. Returns false when
  /// there is nothing to resume.
  Future<bool> restore() async {
    final stored = await ref.read(tokenStoreProvider).read();
    final hostToken = stored?.hostToken;
    if (stored == null || hostToken == null) return false;
    state = const HostState(phase: HostPhase.starting);
    try {
      final port = await ref.read(hostServerProvider).startServer();
      final room = HostedRoom(
        roomCode: stored.roomCode,
        playerId: stored.playerId ?? '',
        sessionToken: stored.sessionToken,
        hostToken: hostToken,
        port: port,
      );
      _connect(room);
      state = HostState(phase: HostPhase.ready, room: room, addresses: await _addresses());
      return true;
    } on HostException catch (error) {
      _log.warning('could not resume hosting', error);
      state = HostState(phase: HostPhase.failed, error: error);
      return false;
    }
  }

  /// The app returned to the foreground: make sure the server still runs, then reconnect.
  Future<void> onForeground() async {
    if (state.phase != HostPhase.ready) return;
    try {
      await ref.read(hostServerProvider).ensureRunning();
    } on HostException catch (error) {
      _log.warning('server could not be restarted', error);
      state = HostState(phase: HostPhase.failed, room: state.room, addresses: state.addresses, error: error);
      return;
    }
    ref.notifier(sessionProvider).reconnect();
  }

  /// Ends hosting: leaves the room, stops the server and forgets the session.
  Future<void> stop() async {
    await ref.notifier(sessionProvider).leave();
    await ref.read(hostServerProvider).stop();
    state = const HostState();
  }

  void _connect(HostedRoom room) {
    ref
        .notifier(sessionProvider)
        .attach(
          uri: _loopback(room.port),
          first: Resume(roomCode: room.roomCode, sessionToken: room.sessionToken, hostToken: room.hostToken),
          host: true,
        );
  }

  Future<List<String>> _addresses() async {
    try {
      return await ref.read(localAddressesProvider)();
    } on Object catch (error) {
      _log.warning('cannot list local addresses', error);
      return const <String>[];
    }
  }
}
