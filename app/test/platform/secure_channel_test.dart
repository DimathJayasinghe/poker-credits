import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:poker_credits/platform/secure_channel_io.dart';

/// A pin-shaped stand-in for the fingerprint, so the tests need no native library. The real hash
/// is checked against the Rust implementation by the bridge tests.
String _fakeHash(List<int> der) => base64Url.encode(der.take(32).toList()).replaceAll('=', '');

String get _certPin {
  final pem = File('test/fixtures/tls/cert.pem').readAsStringSync();
  return _fakeHash(base64.decode(pem.replaceAll(RegExp(r'-----[A-Z ]+-----|\s'), '')));
}

/// A WebSocket echo server over TLS with the test certificate. [requests] counts what reached it.
Future<({HttpServer server, List<String> requests})> _echo({bool tls = true}) async {
  final requests = <String>[];
  final HttpServer server;
  if (tls) {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/tls/cert.pem')
      ..usePrivateKey('test/fixtures/tls/key.pem');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
  } else {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  }
  server.listen((request) async {
    requests.add(request.uri.path);
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen((data) => socket.add('echo:$data'));
  });
  addTearDown(() => server.close(force: true));
  return (server: server, requests: requests);
}

Uri _wss(int port, [String? pin]) => withPin(Uri.parse('wss://127.0.0.1:$port/v1/ws'), pin);

void main() {
  test('the pinned certificate connects and carries frames', () async {
    final host = await _echo();
    final channel = await openChannel(_wss(host.server.port, _certPin), hasher: _fakeHash);
    channel.sink.add('hello');
    expect(await channel.stream.first, 'echo:hello');
    await channel.sink.close();
  });

  test('another certificate is refused before anything is sent', () async {
    final host = await _echo();
    final other = 'Z' * 43;
    await expectLater(openChannel(_wss(host.server.port, other), hasher: _fakeHash), throwsA(isA<PinMismatch>()));
    expect(host.requests, isEmpty, reason: 'the session token would have been in the first message');
  });

  test('a pin that differs in a single character is refused', () async {
    final host = await _echo();
    final pin = _certPin;
    final changed = '${pin.substring(0, 42)}${pin.endsWith('A') ? 'B' : 'A'}';
    await expectLater(openChannel(_wss(host.server.port, changed), hasher: _fakeHash), throwsA(isA<PinMismatch>()));
    expect(host.requests, isEmpty);
  });

  test('a host that speaks plain HTTP is not a secure channel', () async {
    final host = await _echo(tls: false);
    await expectLater(openChannel(_wss(host.server.port, _certPin), hasher: _fakeHash), throwsA(isA<NoSecureChannel>()));
    expect(host.requests, isEmpty);
  });

  test('wss without a pin trusts no self-signed certificate', () async {
    final host = await _echo();
    await expectLater(openChannel(_wss(host.server.port), hasher: _fakeHash), throwsA(isNot(isA<PinMismatch>())));
    expect(host.requests, isEmpty);
  });

  test('plaintext is allowed to this device only', () async {
    final host = await _echo(tls: false);
    final channel = await openChannel(Uri.parse('ws://127.0.0.1:${host.server.port}/v1/ws'), hasher: _fakeHash);
    channel.sink.add('x');
    expect(await channel.stream.first, 'echo:x');
    await channel.sink.close();

    for (final lan in <String>[
      'ws://192.168.1.5:7878/v1/ws',
      'ws://10.0.0.2:7878/v1/ws',
      'ws://example.com/v1/ws',
      'ws://127.0.0.1.evil.example:1/v1/ws',
    ]) {
      await expectLater(openChannel(Uri.parse(lan), hasher: _fakeHash), throwsA(isA<InsecureAddress>()), reason: lan);
    }
  });

  test('a ws address with a pin attached is still plaintext and still refused', () async {
    await expectLater(
      openChannel(withPin(Uri.parse('ws://192.168.1.5:7878/v1/ws'), _certPin), hasher: _fakeHash),
      throwsA(isA<InsecureAddress>()),
    );
  });
}
