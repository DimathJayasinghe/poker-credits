import 'dart:io';

import 'package:logging/logging.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('SecureChannel');

/// How long a connection (TCP and TLS) gets before it counts as failed.
const Duration connectTimeout = Duration(seconds: 10);

/// Fingerprint of a DER certificate. A seam so tests need no native library.
typedef CertHasher = String Function(List<int> der);

String _bridgeHash(List<int> der) => certFingerprint(der: der);

/// Opens the WebSocket to [uri].
///
/// - `wss://` with a pin: TLS 1.3, no certificate authority is trusted, and the certificate the
///   host shows must have exactly that fingerprint. The TLS handshake itself proves the host
///   holds the matching key. A different certificate throws [PinMismatch] before anything is
///   sent.
/// - `wss://` without a pin: the system's certificate authorities decide (a cloud server).
/// - `ws://` only to this device. Any other plaintext address throws [InsecureAddress].
///
/// A host that does not speak TLS throws [NoSecureChannel].
Future<WebSocketChannel> openChannel(Uri uri, {CertHasher? hasher}) async {
  final target = withoutPin(uri);
  if (target.scheme == 'ws') {
    if (!isLoopbackHost(target.host)) throw InsecureAddress(target);
    return _connect(target, null);
  }
  final pin = pinOf(uri);
  if (pin == null) return _connect(target, null);
  if (hasher == null) await initBridge();
  final hash = hasher ?? _bridgeHash;
  var mismatch = false;
  final context = SecurityContext(withTrustedRoots: false)..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
  final client = HttpClient(context: context)
    ..connectionTimeout = connectTimeout
    ..badCertificateCallback = (cert, host, port) {
      // Called for every certificate here (no authority is trusted). Accept only the pinned one.
      final matches = hash(cert.der) == pin;
      if (!matches) mismatch = true;
      return matches;
    };
  try {
    return await _connect(target, client);
  } on Object catch (error) {
    client.close(force: true);
    if (mismatch) throw const PinMismatch();
    // The channel wraps what went wrong while connecting.
    final cause = error is WebSocketChannelException ? error.inner : error;
    if (cause is HandshakeException) throw const NoSecureChannel();
    rethrow;
  }
}

Future<WebSocketChannel> _connect(Uri target, HttpClient? client) async {
  final channel = IOWebSocketChannel.connect(target, customClient: client, connectTimeout: connectTimeout);
  try {
    await channel.ready;
  } on Object catch (error) {
    _log.info('cannot open ${target.scheme}://${target.host}:${target.port}: ${error.runtimeType}');
    rethrow;
  }
  return channel;
}
