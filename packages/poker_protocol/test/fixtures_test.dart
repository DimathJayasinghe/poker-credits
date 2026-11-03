import 'dart:convert';
import 'dart:io';

import 'package:poker_protocol/poker_protocol.dart';
import 'package:test/test.dart';

/// Golden files shared with the Rust tests (`crates/poker_server_core/tests/protocol_fixtures.rs`).
/// `protocol/fixtures/v1`, found by walking up from the working directory: the tests run from
/// `packages/poker_protocol` locally and from the repository root in CI.
final Directory fixtureDir = _findFixtures();

Directory _findFixtures() {
  var dir = Directory.current.absolute;
  while (true) {
    final candidate = Directory('${dir.path}${Platform.pathSeparator}protocol${Platform.pathSeparator}fixtures${Platform.pathSeparator}v1');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory('protocol/fixtures/v1');
    dir = parent;
  }
}

/// Every message type the protocol has, with the Dart class it must decode to. A new message
/// without a fixture, or a fixture without an entry here, fails the test on purpose.
const Map<String, Type> clientTypes = {
  'CREATE_ROOM': CreateRoom,
  'JOIN_ROOM': JoinRoom,
  'RESUME': Resume,
  'START_HAND': StartHand,
  'GAME_ACTION': GameAction,
  'BEGIN_SHOWDOWN': BeginShowdown,
  'RESOLVE_SHOWDOWN': ResolveShowdown,
  'UNDO': Undo,
  'PAUSE': Pause,
  'RESUME_GAME': ResumeGame,
  'APPROVE_REBUY': ApproveRebuy,
  'KICK': Kick,
  'ROOM_CONFIGURE': RoomConfigure,
  'END_GAME': EndGame,
  'REQUEST_REBUY': RequestRebuy,
  'SET_SITTING_OUT': SetSittingOut,
  'LEAVE_TABLE': LeaveTable,
  'PRESENCE_VOTE': PresenceVote,
  'PRESENCE_ACK': PresenceAck,
  'PING': Ping,
};

const Map<String, Type> serverTypes = {
  'ROOM_CREATED': RoomCreated,
  'JOINED': Joined,
  'SNAPSHOT': Snapshot,
  'STATE_UPDATE': StateUpdate,
  'TURN_PROMPT': TurnPrompt,
  'ACTION_PERFORMED': ActionPerformed,
  'ACK': Ack,
  'ERROR': ErrorMessage,
  'PLAYER_CONNECTION': PlayerConnection,
  'GAME_PAUSED': GamePaused,
  'GAME_RESUMED': GameResumed,
  'ROOM_RECOVERED': RoomRecovered,
  'ROOM_CRASHED': RoomCrashed,
  'ROOM_EXPIRED': RoomExpired,
  'PONG': Pong,
  'PLAYER_AWAY': PlayerAway,
  'PRESENCE_CHECK': PresenceCheck,
  'PRESENCE_RESOLVED': PresenceResolved,
};

List<File> fixtures(String prefix) =>
    fixtureDir.listSync().whereType<File>().where((f) => f.uri.pathSegments.last.startsWith(prefix) && f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

Map<String, dynamic> asMap(String text) => jsonDecode(text) as Map<String, dynamic>;

void main() {
  test('the fixture folder is found', () {
    expect(fixtureDir.existsSync(), isTrue, reason: 'protocol/fixtures/v1 must exist above the working directory');
  });

  group('client fixtures', () {
    for (final file in fixtures('client_')) {
      final name = file.uri.pathSegments.last;
      test('$name decodes and encodes back to the same JSON', () {
        final text = file.readAsStringSync();
        final expected = asMap(text);
        final envelope = decodeClient(text);
        expect(envelope.body.runtimeType, clientTypes[expected['type']], reason: 'type ${expected['type']}');
        expect(asMap(encodeClient(envelope.body, reqId: envelope.reqId)), expected);
      });
    }

    test('every client message type has a fixture', () {
      final seen = {for (final f in fixtures('client_')) asMap(f.readAsStringSync())['type'] as String};
      expect(seen, containsAll(clientTypes.keys));
      expect(clientTypes.keys, containsAll(seen), reason: 'a fixture has a type with no Dart class');
    });
  });

  group('server fixtures', () {
    for (final file in fixtures('server_')) {
      final name = file.uri.pathSegments.last;
      test('$name decodes and encodes back to the same JSON', () {
        final text = file.readAsStringSync();
        final expected = asMap(text);
        final envelope = decodeServer(text);
        expect(envelope.body.runtimeType, serverTypes[expected['type']], reason: 'type ${expected['type']}');
        expect(asMap(encodeServer(envelope.body, reqId: envelope.reqId)), expected);
      });
    }

    test('every server message type has a fixture', () {
      final seen = {for (final f in fixtures('server_')) asMap(f.readAsStringSync())['type'] as String};
      expect(seen, containsAll(serverTypes.keys));
      expect(serverTypes.keys, containsAll(seen), reason: 'a fixture has a type with no Dart class');
    });
  });

  group('tolerance', () {
    test('an unknown server message type is ignored, not an error', () {
      final envelope = decodeServer('{"v":1,"type":"SOMETHING_NEW","x":1}');
      expect(envelope.body, isA<UnknownServerMessage>());
    });

    test('an unknown error code decodes to ErrorCode.unknown', () {
      final envelope = decodeServer('{"v":1,"type":"ERROR","code":"FROM_THE_FUTURE","message":"m"}');
      expect((envelope.body as ErrorMessage).code, ErrorCode.unknown);
    });

    test('an unknown role is the least privileged one', () {
      final envelope = decodeServer('{"v":1,"type":"JOINED","playerId":"p","role":"CASTLE","sessionToken":"t"}');
      expect((envelope.body as Joined).role, Role.spectator);
    });

    test('extra fields are ignored', () {
      final envelope = decodeServer('{"v":1,"type":"PONG","t":5,"later":true}');
      expect((envelope.body as Pong).t, 5);
    });

    test('optional fields are omitted, flags are always written', () {
      final map = asMap(encodeClient(const JoinRoom(roomCode: 'KQ7M', name: 'A', spectator: false)));
      expect(map.containsKey('seatIndex'), isFalse);
      expect(map['spectator'], isFalse);
      expect(asMap(encodeClient(const StartHand())), {'v': 1, 'type': 'START_HAND'});
    });

    test('garbage is a ProtocolFormatException', () {
      for (final text in ['not json', '[]', '{"v":1}', '{"type":"PONG","t":1}', '{"v":1,"type":"PONG"}']) {
        expect(() => decodeServer(text), throwsA(isA<ProtocolFormatException>()), reason: text);
      }
    });

    test('error details keep their numbers', () {
      final envelope = decodeServer('{"v":1,"type":"ERROR","code":"BELOW_MIN_RAISE","message":"m","details":{"minRaiseTo":40}}');
      expect((envelope.body as ErrorMessage).details, {'minRaiseTo': 40});
    });
  });
}
