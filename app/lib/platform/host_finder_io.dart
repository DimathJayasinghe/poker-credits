import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/secure_channel_io.dart';
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
///
/// The probes are HTTPS (ADR-019). A host's certificate is self-signed, so nothing is verified
/// here: the finder takes the certificate fingerprint of whoever answers and the join pins that
/// device (trust on first use). Hosts of older versions speak plain HTTP and are not found.
final class LanHostFinder implements HostFinder {
  LanHostFinder({
    Future<List<String>> Function()? candidates,
    this.ports = hostPorts,
    this.concurrency = 48,
    this.probeTimeout = const Duration(milliseconds: 700),
    this.deadline = const Duration(seconds: 12),
    CertHasher? hasher,
  }) : _candidates = candidates ?? _lanCandidates,
       _hasher = hasher;

  final CertHasher? _hasher;
  final Future<List<String>> Function() _candidates;

  /// A client for the probes: TLS 1.3, no authority trusted, and every certificate noted in
  /// [seen] under `address:port` so the answer can be paired with the fingerprint.
  Future<HttpClient> _newClient(Map<String, String> seen) async {
    final hash = _hasher ?? (await _bridgeHasher());
    final context = SecurityContext(withTrustedRoots: false)..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
    return HttpClient(context: context)
      ..connectionTimeout = probeTimeout
      ..badCertificateCallback = (cert, host, port) {
        seen['$host:$port'] = hash(cert.der);
        return true;
      };
  }

  static Future<CertHasher> _bridgeHasher() async {
    await initBridge();
    return (List<int> der) => certFingerprint(der: der);
  }

  @override
  Future<String?> fingerprintOf(String hostAndPort) async {
    final seen = <String, String>{};
    HttpClient? client;
    try {
      client = await _newClient(seen);
      final uri = Uri.parse('https://$hostAndPort/health');
      final request = await client.getUrl(uri).timeout(probeTimeout * 4);
      final response = await request.close().timeout(probeTimeout * 4);
      await response.drain<void>().timeout(probeTimeout * 4);
      final pin = seen['${uri.host}:${uri.port}'];
      return isPin(pin) ? pin : null;
    } on Object {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  Future<bool> speaksPlainHttp(String hostAndPort) async {
    final client = HttpClient()..connectionTimeout = probeTimeout * 4;
    try {
      final request = await client.getUrl(Uri.parse('http://$hostAndPort/health')).timeout(probeTimeout * 4);
      final response = await request.close().timeout(probeTimeout * 4);
      if (response.statusCode != 200) {
        await response.drain<void>().timeout(probeTimeout * 4);
        return false;
      }
      final body = await utf8.decoder.bind(response).join().timeout(probeTimeout * 4);
      // Only our own health answer counts, not any web server that happens to be there.
      return body.length < 512 && body.contains('"status":"healthy"') && body.contains('"protocol"');
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

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
  final Map<String, String> _seen = <String, String>{};
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
      final client = await _finder._newClient(_seen);
      if (_cancelled) {
        client.close(force: true);
        return;
      }
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
        if (await _probe(client, hosts[index], port)) {
          final address = '${hosts[index]}:$port';
          final pin = _seen['${hosts[index]}:$port'];
          found ??= DiscoveredHost(address, fingerprint: isPin(pin) ? pin : null);
        }
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < _finder.concurrency; i++) worker()]);
    return found;
  }

  Future<bool> _probe(HttpClient client, String host, int port) async {
    try {
      final request = await client.getUrl(Uri(scheme: 'https', host: host, port: port, path: '/v1/room/$_code')).timeout(_finder.probeTimeout);
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
  final Map<String, String> _seen = <String, String>{};
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
      final client = await _finder._newClient(_seen);
      if (_cancelled) {
        client.close(force: true);
        return;
      }
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
      final request = await client.getUrl(Uri(scheme: 'https', host: host, port: port, path: '/v1/lobbies')).timeout(_finder.probeTimeout);
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
      final pin = _seen[hostAndPort];
      var grew = false;
      for (final entry in list.take(16)) {
        final lobby = DiscoveredLobby.tryParse(entry, hostAndPort, fingerprint: isPin(pin) ? pin : null);
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
