import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/server_address.dart';

final _log = Logger('HostFinder');

/// Ports a host may listen on: the default one, then the one it falls back to when that is busy.
const List<int> hostPorts = <int>[7878, 7879];

HostFinder createHostFinder() => LanHostFinder();

/// Finds a hosted room by asking every address of the device's own /24 networks whether it holds
/// the room: `GET /v1/room/{code}` on the host port. Plain unicast HTTP, so it works on every
/// platform without multicast permissions or entitlements (LocalSend falls back to the same scan).
///
/// Only the answer `exists: true` counts, and nothing is listed: a host reveals nothing about
/// rooms whose code the asker does not already know. A rogue server on the network can at most
/// see the code being asked for and then the player's name.
final class LanHostFinder implements HostFinder {
  LanHostFinder({
    Future<List<String>> Function()? candidates,
    this.ports = hostPorts,
    this.concurrency = 48,
    this.probeTimeout = const Duration(milliseconds: 700),
    this.deadline = const Duration(seconds: 12),
  }) : _candidates = candidates ?? _lanCandidates;

  final Future<List<String>> Function() _candidates;
  final List<int> ports;

  /// Probes in flight at once.
  final int concurrency;

  /// Per attempt: connecting plus the answer.
  final Duration probeTimeout;

  /// The whole search gives up after this.
  final Duration deadline;

  @override
  bool get isSupported => true;

  @override
  HostSearch search(String roomCode) => _Search(this, roomCode)..start();

  @override
  LobbyBrowse browse() => _Browse(this)..start();

  /// Every other address of the /24 around each of the device's own addresses (at most three
  /// networks), in order of how likely the network is the LAN.
  static Future<List<String>> _lanCandidates() async {
    final own = (await listLocalAddresses()).take(3).toList();
    return candidatesAround(own);
  }

  /// The addresses to try for [own] device addresses: each /24 without the device itself.
  static List<String> candidatesAround(List<String> own) {
    final seen = <String>{...own};
    final result = <String>[];
    for (final address in own) {
      final parts = address.split('.');
      if (parts.length != 4) continue;
      final prefix = parts.take(3).join('.');
      for (var i = 1; i <= 254; i++) {
        final candidate = '$prefix.$i';
        if (seen.add(candidate)) result.add(candidate);
      }
    }
    return result;
  }
}

final class _Search implements HostSearch {
  _Search(this._finder, this._code);

  final LanHostFinder _finder;
  final String _code;
  final Completer<DiscoveredHost?> _done = Completer<DiscoveredHost?>();
  HttpClient? _client;
  Timer? _deadline;
  bool _cancelled = false;

  @override
  Future<DiscoveredHost?> get result => _done.future;

  void start() {
    _deadline = Timer(_finder.deadline, cancel);
    unawaited(_run());
  }

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _finish(null);
  }

  void _finish(DiscoveredHost? host) {
    _deadline?.cancel();
    _client?.close(force: true);
    _client = null;
    if (!_done.isCompleted) _done.complete(host);
  }

  Future<void> _run() async {
    try {
      final candidates = await _finder._candidates();
      if (_cancelled) return;
      final client = HttpClient()..connectionTimeout = _finder.probeTimeout;
      _client = client;
      _log.info('looking for room on ${candidates.length} addresses');
      for (final port in _finder.ports) {
        final found = await _scan(client, candidates, port);
        if (found != null) {
          _finish(found);
          return;
        }
        if (_cancelled) return;
      }
      _finish(null);
    } on Object catch (error) {
      _log.warning('search failed: ${error.runtimeType}');
      _finish(null);
    }
  }

  Future<DiscoveredHost?> _scan(HttpClient client, List<String> hosts, int port) async {
    var next = 0;
    DiscoveredHost? found;
    Future<void> worker() async {
      while (found == null && !_cancelled) {
        final index = next++;
        if (index >= hosts.length) return;
        if (await _probe(client, hosts[index], port)) found ??= DiscoveredHost('${hosts[index]}:$port');
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < _finder.concurrency; i++) worker()]);
    return found;
  }

  Future<bool> _probe(HttpClient client, String host, int port) async {
    try {
      final request = await client.getUrl(Uri(scheme: 'http', host: host, port: port, path: '/v1/room/$_code')).timeout(_finder.probeTimeout);
      final response = await request.close().timeout(_finder.probeTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().timeout(_finder.probeTimeout);
        return false;
      }
      // The answer is a few dozen bytes; refuse anything bigger instead of buffering it.
      final bytes = <int>[];
      await for (final chunk in response.timeout(_finder.probeTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 2048) return false;
      }
      final body = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      return body is Map<String, dynamic> && body['exists'] == true;
    } on Object {
      return false;
    }
  }
}

/// Asks every candidate address for its open games (`GET /v1/lobbies`) and reports each game as
/// soon as it is found. Unlike a search by code it does not stop at the first answer.
final class _Browse implements LobbyBrowse {
  _Browse(this._finder);

  final LanHostFinder _finder;
  final StreamController<List<DiscoveredLobby>> _updates = StreamController<List<DiscoveredLobby>>.broadcast();
  final Completer<void> _done = Completer<void>();
  final List<DiscoveredLobby> _found = <DiscoveredLobby>[];
  HttpClient? _client;
  Timer? _deadline;
  bool _cancelled = false;

  @override
  Stream<List<DiscoveredLobby>> get lobbies => _updates.stream;

  @override
  Future<void> get done => _done.future;

  void start() {
    _deadline = Timer(_finder.deadline, cancel);
    unawaited(_run());
  }

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _finish();
  }

  void _finish() {
    _deadline?.cancel();
    _client?.close(force: true);
    _client = null;
    if (!_done.isCompleted) _done.complete();
    unawaited(_updates.close());
  }

  Future<void> _run() async {
    try {
      final candidates = await _finder._candidates();
      if (_cancelled) return;
      final client = HttpClient()..connectionTimeout = _finder.probeTimeout;
      _client = client;
      _log.info('browsing ${candidates.length} addresses for open games');
      for (final port in _finder.ports) {
        await _scan(client, candidates, port);
        if (_cancelled) return;
      }
    } on Object catch (error) {
      _log.warning('browse failed: ${error.runtimeType}');
    }
    if (!_cancelled) _finish();
  }

  Future<void> _scan(HttpClient client, List<String> hosts, int port) async {
    var next = 0;
    Future<void> worker() async {
      while (!_cancelled) {
        final index = next++;
        if (index >= hosts.length) return;
        await _probe(client, hosts[index], port);
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < _finder.concurrency; i++) worker()]);
  }

  Future<void> _probe(HttpClient client, String host, int port) async {
    try {
      final request = await client.getUrl(Uri(scheme: 'http', host: host, port: port, path: '/v1/lobbies')).timeout(_finder.probeTimeout);
      final response = await request.close().timeout(_finder.probeTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().timeout(_finder.probeTimeout);
        return;
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(_finder.probeTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) return;
      }
      final body = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      final list = body is Map<String, dynamic> ? body['lobbies'] : null;
      if (list is! List) return;
      final hostAndPort = '$host:$port';
      var grew = false;
      for (final entry in list.take(16)) {
        final lobby = DiscoveredLobby.tryParse(entry, hostAndPort);
        if (lobby != null && !_found.contains(lobby)) {
          _found.add(lobby);
          grew = true;
        }
      }
      if (grew && !_cancelled && !_updates.isClosed) _updates.add(List<DiscoveredLobby>.unmodifiable(_found));
    } on Object {
      return;
    }
  }
}
