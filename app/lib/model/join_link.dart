/// What the host's QR code carries: where the server is and which room to join.
///
/// `pokercredits://join?h=192.168.1.5:7878&c=KQ7M`
class JoinLink {
  const JoinLink({required this.hostAndPort, required this.roomCode});

  /// `address:port` of the server on the LAN.
  final String hostAndPort;
  final String roomCode;

  static const String scheme = 'pokercredits';

  @override
  String toString() => Uri(scheme: scheme, host: 'join', queryParameters: <String, String>{'h': hostAndPort, 'c': roomCode}).toString();

  /// WebSocket address of the server (`ws://` on the LAN, ADR-012).
  Uri get webSocketUri => Uri.parse('ws://$hostAndPort/v1/ws');

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
    if (hostAndPort == null || code == null || !_hostAndPort.hasMatch(hostAndPort) || !_roomCode.hasMatch(code.toUpperCase())) return null;
    return JoinLink(hostAndPort: hostAndPort, roomCode: code.toUpperCase());
  }

  static final RegExp _hostAndPort = RegExp(r'^[A-Za-z0-9.\-]{1,253}:\d{1,5}$');
  static final RegExp _roomCode = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}$');

  @override
  bool operator ==(Object other) => other is JoinLink && other.hostAndPort == hostAndPort && other.roomCode == roomCode;

  @override
  int get hashCode => Object.hash(hostAndPort, roomCode);
}
