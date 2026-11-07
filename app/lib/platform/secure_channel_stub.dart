import 'package:poker_credits/net/pin.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web: the browser checks the certificate itself and cannot pin one, so only `wss://` to a
/// server with a real certificate (and plain loopback for development) works here.
Future<WebSocketChannel> openChannel(Uri uri) async {
  final target = withoutPin(uri);
  if (target.scheme != 'wss' && !isLoopbackHost(target.host)) throw InsecureAddress(target);
  final channel = WebSocketChannel.connect(target);
  await channel.ready;
  return channel;
}
