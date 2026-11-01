import 'package:poker_credits/platform/host_server.dart';

/// Web and any platform without dart:io: hosting is not possible (ADR-014 rule 4).
HostServer createHostServer() => const _UnsupportedHostServer();

final class _UnsupportedHostServer implements HostServer {
  const _UnsupportedHostServer();

  @override
  bool get isSupported => false;
}
