import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/net/backoff.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

final _start = DateTime(2026, 11, 3, 12);

/// Runs [body] with a client whose clock follows the fake async time.
void _scenario(void Function(FakeAsync async, FakeNetwork net, RoomClient Function(ClientMessage first) make) body) {
  fakeAsync((async) {
    final net = FakeNetwork();
    RoomClient make(ClientMessage first) => RoomClient(
      uri: Uri.parse('ws://127.0.0.1:7878/v1/ws'),
      firstMessage: first,
      transport: net.connect,
      backoff: Backoff(random: Random(7)),
      now: () => _start.add(async.elapsed),
    );
    body(async, net, make);
  });
}

const _join = JoinRoom(roomCode: 'KQ7M', name: 'Alice');
const _joined = Joined(playerId: 'p1', role: Role.player, seatIndex: 1, sessionToken: 'tok');

void _goLive(FakeAsync async, FakeNetwork net) {
  async.flushMicrotasks();
  net.last.serverSends(_joined);
  net.last.serverSends(snapshot(version: 3));
  async.flushMicrotasks();
}

void main() {
  test('joins, goes live on the first snapshot and remembers the credentials', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      async.flushMicrotasks();
      expect(client.state.phase, LinkPhase.connecting);
      expect(net.last.sent.single, isA<JoinRoom>());

      _goLive(async, net);
      expect(client.state.phase, LinkPhase.live);
      expect(client.credentials!.sessionToken, 'tok');
      expect(client.credentials!.roomCode, 'KQ7M');
      client.close();
    });
  });

  test('after a drop it waits, then resumes with the token and the last state version', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      _goLive(async, net);
      net.last.serverSends(StateUpdate(stateVersion: 4, view: roomView()));
      async.flushMicrotasks();

      net.last.drop();
      async.flushMicrotasks();
      expect(client.state.phase, LinkPhase.waiting);
      expect(client.state.isReconnecting, isTrue);
      expect(net.opened, hasLength(1));

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(net.opened, hasLength(2));
      final resume = net.last.sent.single as Resume;
      expect(resume.roomCode, 'KQ7M');
      expect(resume.sessionToken, 'tok');
      expect(resume.lastStateVersion, 4);
      expect(resume.hostToken, isNull);
      client.close();
    });
  });

  test('a host re-attaches with the host token', () {
    _scenario((async, net, make) {
      final client = make(const Resume(roomCode: 'KQ7M', sessionToken: 's', hostToken: 'h'))..start();
      async.flushMicrotasks();
      expect((net.last.sent.single as Resume).hostToken, 'h');
      net.last.serverSends(snapshot());
      async.flushMicrotasks();
      net.last.drop();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect((net.last.sent.single as Resume).hostToken, 'h');
      client.close();
    });
  });

  test('pings every 15 s and treats 45 s of silence as a dead link', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      _goLive(async, net);
      async.elapse(const Duration(seconds: 15));
      expect(net.last.sent.whereType<Ping>(), hasLength(1));

      // The server answers once, then goes quiet.
      net.last.serverSends(const Pong(t: 1));
      async.elapse(const Duration(seconds: 44));
      expect(client.state.isLive, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(net.opened, hasLength(2), reason: 'the silent socket was dropped and a new one opened');
      expect(net.opened.first.closed, isTrue);
      client.close();
    });
  });

  test('backoff keeps growing while connections fail, and resets after a stable link', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      async.flushMicrotasks();
      net.refuseConnections = true;
      net.last.drop();
      async.flushMicrotasks();
      final delays = <Duration>[];
      for (var i = 0; i < 4; i++) {
        final due = client.state.nextAttemptAt!;
        delays.add(due.difference(_start.add(async.elapsed)));
        async.elapse(delays.last);
        async.flushMicrotasks();
      }
      expect(delays[3], greaterThan(delays[0]));
      expect(client.state.attempt, greaterThanOrEqualTo(4));

      // A connection that stays up 10 s earns a fresh 0.5 s start.
      net.refuseConnections = false;
      async.elapse(const Duration(seconds: 12));
      async.flushMicrotasks();
      net.last.serverSends(snapshot(version: 1));
      async.flushMicrotasks();
      expect(client.state.isLive, isTrue);
      async.elapse(const Duration(seconds: 11));
      net.last.serverSends(const Pong(t: 1));
      net.last.drop();
      async.flushMicrotasks();
      final wait = client.state.nextAttemptAt!.difference(_start.add(async.elapsed));
      expect(wait, lessThanOrEqualTo(const Duration(milliseconds: 600)));
      client.close();
    });
  });

  test('a link that drops within 10 s keeps its backoff', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      _goLive(async, net);
      net.last.drop();
      async.flushMicrotasks();
      final first = client.state.nextAttemptAt!.difference(_start.add(async.elapsed));
      async.elapse(first);
      async.flushMicrotasks();
      net.last.serverSends(snapshot(version: 4));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      net.last.drop();
      async.flushMicrotasks();
      final second = client.state.nextAttemptAt!.difference(_start.add(async.elapsed));
      expect(second, greaterThan(const Duration(milliseconds: 700)), reason: 'second step is about 1 s, not 0.5 s');
      client.close();
    });
  });

  test('an invalid session stops the retries and says why', () {
    _scenario((async, net, make) {
      final client = make(const Resume(roomCode: 'KQ7M', sessionToken: 'old'))..start();
      async.flushMicrotasks();
      net.last.serverSends(const ErrorMessage(code: ErrorCode.invalidSession, message: 'no'));
      async.flushMicrotasks();
      expect(client.state.phase, LinkPhase.failed);
      expect(client.state.failure, LinkFailure.invalidSession);
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(net.opened, hasLength(1), reason: 'no retries after a fatal refusal');
      client.close();
    });
  });

  test('being superseded or losing the room is final', () {
    for (final (message, failure) in <(ServerMessage, LinkFailure)>[
      (const ErrorMessage(code: ErrorCode.superseded, message: 'other device'), LinkFailure.superseded),
      (const RoomCrashed(reason: 'frozen'), LinkFailure.roomCrashed),
      (const RoomExpired(), LinkFailure.roomExpired),
      (const ErrorMessage(code: ErrorCode.roomNotFound, message: 'gone'), LinkFailure.roomGone),
    ]) {
      _scenario((async, net, make) {
        final client = make(_join)..start();
        _goLive(async, net);
        net.last.serverSends(message);
        async.flushMicrotasks();
        expect(client.state.failure, failure);
        client.close();
      });
    }
  });

  test('a fixable join error keeps the socket so the user can try again', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      async.flushMicrotasks();
      net.last.serverSends(const ErrorMessage(code: ErrorCode.nameInvalid, message: 'bad name'));
      async.flushMicrotasks();
      expect(client.state.phase, LinkPhase.connecting);
      expect(client.send(const JoinRoom(roomCode: 'KQ7M', name: 'Alice2')), isTrue);
      expect(net.last.sent.last, isA<JoinRoom>());
      client.close();
    });
  });

  test('reconnectNow drops the socket and reconnects at once', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      _goLive(async, net);
      final old = net.last;
      client.reconnectNow();
      async.flushMicrotasks();
      expect(old.closed, isTrue);
      expect(net.opened, hasLength(2));
      expect(net.last.sent.single, isA<Resume>());
      client.close();
    });
  });

  test('send returns false while there is no socket', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      async.flushMicrotasks();
      net.last.drop();
      async.flushMicrotasks();
      expect(client.send(const Ping(t: 1)), isFalse);
      client.close();
    });
  });

  test('"still trying" shows after 30 s down', () {
    _scenario((async, net, make) {
      final client = make(_join)..start();
      _goLive(async, net);
      net.refuseConnections = true;
      net.last.drop();
      async.flushMicrotasks();
      expect(client.state.stillTrying(_start.add(async.elapsed)), isFalse);
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();
      expect(client.state.stillTrying(_start.add(async.elapsed)), isTrue);
      client.close();
    });
  });
}
