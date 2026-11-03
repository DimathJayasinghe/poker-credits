import 'dart:async';

import 'package:poker_credits/net/transport.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// A scripted socket for tests.
class FakeTransport implements Transport {
  final _incoming = StreamController<String>();
  final List<ClientMessage> sent = <ClientMessage>[];
  bool closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String frame) => sent.add(decodeClient(frame).body);

  /// The server sends [message].
  void serverSends(ServerMessage message) => _incoming.add(encodeServer(message));

  /// The socket drops.
  void drop() => unawaited(_incoming.close());

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Hands out [FakeTransport]s and records every connect.
class FakeNetwork {
  final List<FakeTransport> opened = <FakeTransport>[];
  bool refuseConnections = false;

  FakeTransport get last => opened.last;

  Future<Transport> connect(Uri uri) async {
    if (refuseConnections) throw StateError('connection refused');
    final transport = FakeTransport();
    opened.add(transport);
    return transport;
  }
}

RoomView roomView({int hand = 1, int? activeSeat, int pot = 0, List<SeatView>? seats, int? deadline}) => RoomView(
  roomCode: 'KQ7M',
  handNumber: hand,
  phase: WirePhase.preFlop,
  activeSeat: activeSeat,
  currentHighBet: 0,
  minRaiseTo: 0,
  totalPot: pot,
  pots: const <PotView>[],
  seats: seats ?? const <SeatView>[],
  paused: false,
  turnDeadlineMs: deadline,
  spectatorCount: 0,
);

Snapshot snapshot({int version = 1, int serverTime = 0, int nextActionSeq = 0, RoomView? view}) =>
    Snapshot(stateVersion: version, serverTime: serverTime, nextActionSeq: nextActionSeq, view: view ?? roomView());
