import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// One open WebSocket carrying JSON text frames. A seam so the client can be tested without a
/// network.
abstract interface class Transport {
  /// Text frames from the server. Completes (onDone) when the socket closes.
  Stream<String> get incoming;

  /// Sends one text frame.
  void send(String frame);

  /// Closes the socket.
  Future<void> close();
}

/// Opens a [Transport]; the future fails when the socket cannot be opened.
typedef TransportFactory = Future<Transport> Function(Uri uri);

/// The real thing, on `web_socket_channel` (works on native and web).
Future<Transport> connectWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return _ChannelTransport(channel);
}

class _ChannelTransport implements Transport {
  _ChannelTransport(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<String> get incoming => _channel.stream.where((frame) => frame is String).cast<String>();

  @override
  void send(String frame) => _channel.sink.add(frame);

  @override
  Future<void> close() => _channel.sink.close();
}
