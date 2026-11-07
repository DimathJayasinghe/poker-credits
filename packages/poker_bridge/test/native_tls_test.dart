// The real native library, a real TLS connection from Dart's own TLS stack. Skipped unless
// POKER_BRIDGE_LIB points at the built library (see native_smoke_test.dart).
//
// This is the interop check for ADR-019: a certificate made by rustls/rcgen is accepted by
// Dart's BoringSSL, its fingerprint computed in Rust matches the one Dart sees on the wire, and
// the host serves nothing in the clear.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_bridge/src/rust/frb_generated.dart';

void main() {
  final libraryPath = Platform.environment['POKER_BRIDGE_LIB'];

  /// How the app connects to a host: TLS 1.3, no certificate authority trusted, the one
  /// certificate it was told to expect.
  HttpClient pinnedClient(
    String? pin, {
    void Function(String seen)? onCertificate,
  }) {
    final context = SecurityContext(withTrustedRoots: false)
      ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
    return HttpClient(context: context)
      ..badCertificateCallback = (cert, host, port) {
        final seen = certFingerprint(der: cert.der);
        onCertificate?.call(seen);
        return seen == pin;
      };
  }

  test(
    'a host on the network speaks TLS 1.3 to Dart, pinned by the fingerprint Rust reports',
    () async {
      await RustLib.init(externalLibrary: ExternalLibrary.open(libraryPath!));
      final dir = await Directory.systemTemp.createTemp('pc-tls-interop');
      addTearDown(() => dir.delete(recursive: true));
      final config = RsServerConfig(
        port: 0,
        exposeOnLan: true,
        dataDir: dir.path,
        serverName: 'interop',
      );

      final controller = ServerController();
      await controller.start(config);
      addTearDown(controller.stop);
      final port = controller.port!;
      final pin = controller.fingerprint!;
      expect(pin, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));

      // The right pin: the HTTPS answer and then a WebSocket upgrade both work.
      var seen = '';
      final client = pinnedClient(pin, onCertificate: (s) => seen = s);
      final request = await client.getUrl(
        Uri.parse('https://127.0.0.1:$port/v1/info'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200);
      expect(body, contains('interop'));
      expect(
        seen,
        pin,
        reason:
            'Rust and Dart agree on the fingerprint of the certificate on the wire',
      );
      client.close();

      final socket = await WebSocket.connect(
        'wss://127.0.0.1:$port/v1/ws',
        customClient: pinnedClient(pin),
      );
      socket.add(jsonEncode(<String, Object?>{'v': 1, 'type': 'PING', 't': 1}));
      await socket.close();

      // Any other certificate is refused by the client.
      final other = pinnedClient('A' * 43);
      await expectLater(
        other
            .getUrl(Uri.parse('https://127.0.0.1:$port/v1/info'))
            .then((r) => r.close()),
        throwsA(isA<HandshakeException>()),
      );
      other.close(force: true);

      // The host does not answer in the clear.
      final plain = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      await expectLater(
        plain
            .getUrl(Uri.parse('http://127.0.0.1:$port/v1/info'))
            .then((r) => r.close())
            .timeout(const Duration(seconds: 3)),
        throwsA(anything),
      );
      plain.close(force: true);

      // A restart keeps the certificate, so guests who pinned it still recognise the host.
      await controller.stop();
      final again = ServerController();
      await again.start(config);
      addTearDown(again.stop);
      expect(again.fingerprint, pin);
    },
    skip: libraryPath == null ? 'set POKER_BRIDGE_LIB to run' : false,
  );
}
