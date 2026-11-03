import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:poker_credits/platform/single_instance.dart';

final _log = Logger('SingleInstance');

/// Loopback port used as the lock. A second launch connects, says "show" and exits (LocalSend
/// does the same with its own port).
const int singleInstancePort = 47878;

/// Claims the lock on desktop. Mobile platforms always get a primary claim.
Future<InstanceClaim> claimSingleInstance({int port = singleInstancePort}) async {
  if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) return _Claim(null);
  try {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    return _Claim(server);
  } on SocketException {
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 1));
      socket.write('show');
      await socket.flush();
      await socket.close();
    } on Object catch (error) {
      _log.warning('another instance holds the port but did not answer', error);
    }
    return const _Secondary();
  }
}

final class _Claim implements InstanceClaim {
  _Claim(this._server);

  final ServerSocket? _server;
  StreamSubscription<Socket>? _subscription;

  @override
  bool get isPrimary => true;

  @override
  void listen(void Function() onSecondLaunch) {
    _subscription = _server?.listen((socket) {
      socket.destroy();
      onSecondLaunch();
    });
  }

  @override
  Future<void> release() async {
    await _subscription?.cancel();
    await _server?.close();
  }

  @override
  void exitProcess() => exit(0);
}

final class _Secondary implements InstanceClaim {
  const _Secondary();

  @override
  bool get isPrimary => false;

  @override
  void listen(void Function() onSecondLaunch) {}

  @override
  Future<void> release() async {}

  @override
  void exitProcess() => exit(0);
}
