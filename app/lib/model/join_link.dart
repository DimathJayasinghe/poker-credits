import 'package:poker_credits/net/pin.dart';

/// What the host's QR code carries: where the server is, which room to join and the fingerprint
/// of the host's certificate (ADR-019).
///
/// `pokercredits://join?h=192.168.1.5:7878&c=KQ7M&f=<43 characters>`
///
/// The fingerprint is what makes a scanned code safe: the guest talks only to a device that holds
/// the certificate it names. A link without one (an older code, or an address typed by hand) has
/// to be completed first by looking at what the host shows (trust on first use).
class JoinLink {
  const JoinLink({required this.hostAndPort, required this.roomCode, this.fingerprint});

  /// `address:port` of the server on the LAN.
  final String hostAndPort;
  final String roomCode;

  /// Pin of the host's certificate, or `null` when not known yet.
  final String? fingerprint;

  static const String scheme = 'pokercredits';

  /// This link with a fingerprint learned another way.
  JoinLink withFingerprint(String? fingerprint) => JoinLink(hostAndPort: hostAndPort, roomCode: roomCode, fingerprint: fingerprint);

  @override
  String toString() => Uri(
    scheme: scheme,
    host: 'join',
    queryParameters: <String, String>{'h': hostAndPort, 'c': roomCode, 'f': ?fingerprint},
  ).toString();

  /// Secure WebSocket address of the server, pinned to [fingerprint] when there is one.
  Uri get webSocketUri => withPin(Uri.parse('wss://$hostAndPort/v1/ws'), fingerprint);

  /// Parses a scanned code; `null` when it is not ours or is malformed.
  static JoinLink? tryParse(String text) {
    final Uri uri;
    try {
      uri = Uri.parse(text.trim());
    } on FormatException {
      return null;
    }
    if (uri.scheme != scheme || uri.host != 'join') return null;
    final hostAndPort = uri.queryParameters['h'];
    final code = uri.queryParameters['c'];
    final fingerprint = uri.queryParameters['f'];
    if (hostAndPort == null || code == null || !_hostAndPort.hasMatch(hostAndPort) || !_roomCode.hasMatch(code.toUpperCase())) return null;
    // A fingerprint that is present but malformed is a damaged or forged code, not an old one.
    if (fingerprint != null && !isPin(fingerprint)) return null;
    return JoinLink(hostAndPort: hostAndPort, roomCode: code.toUpperCase(), fingerprint: fingerprint);
  }

  /// The port a host listens on unless it picked another one.
  static const int defaultPort = 7878;

  /// Normalises what a person typed (`192.168.1.5`, `192.168.1.5:7878`, `ws://...` is refused) into
  /// `address:port`; `null` when it cannot be an address.
  static String? normalizeAddress(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains(' ')) return null;
    final withPort = trimmed.contains(':') ? trimmed : '$trimmed:$defaultPort';
    if (!_hostAndPort.hasMatch(withPort)) return null;
    final port = int.parse(withPort.substring(withPort.lastIndexOf(':') + 1));
    return port >= 1 && port <= 65535 ? withPort : null;
  }

  /// Normalises a typed room code (case-insensitive, spaces ignored); `null` when invalid.
  static String? normalizeRoomCode(String text) {
    final code = text.replaceAll(' ', '').toUpperCase();
    return _roomCode.hasMatch(code) ? code : null;
  }

  /// Whether [host] is a private IPv4 address (a LAN host that a code search can find again).
  static bool isLanAddress(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final a = octets[0]!, b = octets[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  static final RegExp _hostAndPort = RegExp(r'^[A-Za-z0-9.\-]{1,253}:\d{1,5}$');
  static final RegExp _roomCode = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}$');

  @override
  bool operator ==(Object other) =>
      other is JoinLink && other.hostAndPort == hostAndPort && other.roomCode == roomCode && other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(hostAndPort, roomCode, fingerprint);
}
