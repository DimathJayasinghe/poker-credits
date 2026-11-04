import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/host_finder_io.dart';

/// Answers `GET /v1/room/{code}` like the Poker Credits server: 200 with `exists`.
Future<HttpServer> _host({required String code, int status = 200, String? body}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final asked = request.uri.pathSegments.last;
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(body ?? jsonEncode(<String, Object?>{'exists': asked == code, 'playerCount': 2, 'maxPlayers': 10}));
    unawaited(request.response.close());
  });
  return server;
}

LanHostFinder _finder(List<String> hosts, List<int> ports, {Duration deadline = const Duration(seconds: 5)}) =>
    LanHostFinder(candidates: () async => hosts, ports: ports, probeTimeout: const Duration(milliseconds: 400), deadline: deadline, concurrency: 8);

void main() {
  test('finds the host that holds the room, among addresses that do not answer', () async {
    final server = await _host(code: 'KQ7M');
    addTearDown(() => server.close(force: true));
    final found = await _finder(<String>['127.0.0.2', '127.0.0.1'], <int>[server.port]).search('KQ7M').result;
    expect(found?.hostAndPort, '127.0.0.1:${server.port}');
  });

  test('tries the second port when the first has nobody', () async {
    final server = await _host(code: 'KQ7M');
    addTearDown(() => server.close(force: true));
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = closed.port;
    await closed.close();
    final found = await _finder(<String>['127.0.0.1'], <int>[deadPort, server.port]).search('KQ7M').result;
    expect(found?.hostAndPort, '127.0.0.1:${server.port}');
  });

  test('a host that does not hold the code is not a match', () async {
    final server = await _host(code: 'ABCD');
    addTearDown(() => server.close(force: true));
    expect(await _finder(<String>['127.0.0.1'], <int>[server.port]).search('KQ7M').result, isNull);
  });

  test('answers that are not the expected JSON, not 200 or too big are ignored', () async {
    for (final bad in <(int, String)>[(200, 'hello'), (200, '[1]'), (404, '{"exists":true}'), (200, '{"exists":true,"x":"${'a' * 5000}"}')]) {
      final server = await _host(code: 'KQ7M', status: bad.$1, body: bad.$2);
      addTearDown(() => server.close(force: true));
      expect(
        await _finder(<String>['127.0.0.1'], <int>[server.port]).search('KQ7M').result,
        isNull,
        reason: bad.$2.length > 40 ? 'oversized body' : bad.$2,
      );
    }
  });

  test('nobody on the network ends the search in bounded time', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final watch = Stopwatch()..start();
    final found = await _finder(<String>['127.0.0.1', '127.0.0.3'], <int>[port, port + 1]).search('KQ7M').result;
    expect(found, isNull);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('a silent host cannot stall the search past its deadline', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((_) {});
    final watch = Stopwatch()..start();
    final found = await _finder(<String>['127.0.0.1'], <int>[silent.port], deadline: const Duration(milliseconds: 600)).search('KQ7M').result;
    expect(found, isNull);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('cancel completes the search with nothing, at once', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((_) {});
    final search = _finder(<String>['127.0.0.1'], <int>[silent.port]).search('KQ7M');
    search.cancel();
    expect(await search.result, isNull);
  });

  test('candidates are the other addresses of each /24, without the device itself or duplicates', () {
    final list = LanHostFinder.candidatesAround(<String>['192.168.1.5', '192.168.1.77', '10.0.2.15']);
    expect(list, hasLength(252 + 253));
    expect(list, isNot(contains('192.168.1.5')));
    expect(list, isNot(contains('192.168.1.77')));
    expect(list, contains('192.168.1.1'));
    expect(list, contains('10.0.2.2'));
    expect(list.toSet(), hasLength(list.length));
    expect(LanHostFinder.candidatesAround(<String>[]), isEmpty);
  });

  group('browsing for open games', () {
    Future<HttpServer> lobbyHost(Object? body, {int status = 200}) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(body is String ? body : jsonEncode(body));
        unawaited(request.response.close());
      });
      addTearDown(() => server.close(force: true));
      return server;
    }

    Map<String, Object?> entry(String code, {String host = 'Dimath', int players = 3, int max = 10}) => <String, Object?>{
      'roomCode': code,
      'hostName': host,
      'playerCount': players,
      'maxPlayers': max,
    };

    Future<List<DiscoveredLobby>> lastList(LobbyBrowse browse) async {
      var latest = <DiscoveredLobby>[];
      final sub = browse.lobbies.listen((list) => latest = list);
      await browse.done;
      await sub.cancel();
      return latest;
    }

    test('lists every open game, from every host that answers', () async {
      final one = await lobbyHost(<String, Object?>{
        'lobbies': <Object?>[entry('KQ7M'), entry('ABCD', host: 'Sam', players: 5)],
      });
      final two = await lobbyHost(<String, Object?>{
        'lobbies': <Object?>[entry('WXYZ', host: 'Ann', players: 1)],
      });
      final browse = _finder(<String>['127.0.0.1'], <int>[one.port, two.port]).browse();
      final found = await lastList(browse);
      expect(found.map((l) => l.roomCode), unorderedEquals(<String>['KQ7M', 'ABCD', 'WXYZ']));
      final sam = found.firstWhere((l) => l.roomCode == 'ABCD');
      expect((sam.hostName, sam.playerCount, sam.maxPlayers, sam.hostAndPort), ('Sam', 5, 10, '127.0.0.1:${one.port}'));
    });

    test('an empty list, an unreachable network and a non-200 all end with nothing', () async {
      final empty = await lobbyHost(<String, Object?>{'lobbies': <Object?>[]});
      final refused = await lobbyHost('{}', status: 404);
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = closed.port;
      await closed.close();
      final browse = _finder(<String>['127.0.0.1', '127.0.0.9'], <int>[empty.port, refused.port, deadPort]).browse();
      expect(await lastList(browse), isEmpty);
    });

    test('hostile answers are ignored: wrong shapes, bad codes, oversize bodies, too many entries', () async {
      final bad = <Object?>[
        'hello',
        <Object?>[1],
        <String, Object?>{'lobbies': 'x'},
        <String, Object?>{
          'lobbies': <Object?>[
            1,
            null,
            entry('no'),
            entry('KQ7M', max: 99),
            <String, Object?>{'roomCode': 'KQ7M'},
            <String, Object?>{'roomCode': 5, 'hostName': 'x', 'playerCount': 1, 'maxPlayers': 10},
          ],
        },
        '{"lobbies":[],"x":"${'a' * 9000}"}',
      ];
      for (final body in bad) {
        final server = await lobbyHost(body);
        expect(await lastList(_finder(<String>['127.0.0.1'], <int>[server.port]).browse()), isEmpty, reason: 'hostile answer #${bad.indexOf(body)}');
      }
    });

    test('names from the network are cleaned and counts are kept in range', () {
      final lobby = DiscoveredLobby.tryParse(
        <String, Object?>{'roomCode': 'kq7m', 'hostName': '  ${'x' * 40}\u0007  ', 'playerCount': 99, 'maxPlayers': 10},
        '10.0.0.2:7878',
      )!;
      expect(lobby.roomCode, 'KQ7M');
      expect(lobby.hostName, 'x' * 20);
      expect(lobby.playerCount, 10);
      expect(
        DiscoveredLobby.tryParse(<String, Object?>{'roomCode': 'KQ7M', 'hostName': 'a', 'playerCount': -3, 'maxPlayers': 10}, 'h:1')!.playerCount,
        0,
      );
    });

    test('the same game answered twice is listed once', () async {
      final server = await lobbyHost(<String, Object?>{
        'lobbies': <Object?>[entry('KQ7M'), entry('KQ7M')],
      });
      expect(await lastList(_finder(<String>['127.0.0.1'], <int>[server.port, server.port]).browse()), hasLength(1));
    });

    test('cancel ends the scan at once and a silent host cannot stall it past the deadline', () async {
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(silent.close);
      silent.listen((_) {});
      final cancelled = _finder(<String>['127.0.0.1'], <int>[silent.port]).browse()..cancel();
      await cancelled.done;
      final watch = Stopwatch()..start();
      await _finder(<String>['127.0.0.1'], <int>[silent.port], deadline: const Duration(milliseconds: 600)).browse().done;
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });
}
