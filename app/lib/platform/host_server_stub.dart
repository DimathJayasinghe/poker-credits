import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Web and any platform without dart:io: hosting is not possible (ADR-014 rule 4).
HostServer createHostServer() => const _UnsupportedHostServer();

final class _UnsupportedHostServer implements HostServer {
  const _UnsupportedHostServer();

  @override
  bool get isSupported => false;

  @override
  int? get port => null;

  @override
  Future<int> startServer() => Future<int>.error(const HostException(HostFailure.unavailable, 'Hosting is not available on this platform'));

  @override
  Future<HostedRoom> hostGame({required String hostName, required RoomConfig config}) =>
      Future<HostedRoom>.error(const HostException(HostFailure.unavailable, 'Hosting is not available on this platform'));

  @override
  Future<int> startSoloServer() => Future<int>.error(const HostException(HostFailure.unavailable, 'Hosting is not available on this platform'));

  @override
  Future<HostedRoom> hostSolo({required String hostName, required SoloConfig solo}) =>
      Future<HostedRoom>.error(const HostException(HostFailure.unavailable, 'Hosting is not available on this platform'));

  @override
  Future<void> ensureRunning() async {}

  @override
  Future<void> stop() async {}
}
