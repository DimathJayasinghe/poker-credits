import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:poker_credits/platform/host_keep_alive.dart';

final _log = Logger('HostKeepAlive');

HostKeepAlive createHostKeepAlive() => Platform.isAndroid ? const _AndroidKeepAlive() : const _NoKeepAlive();

/// Talks to `HostService.kt` over a method channel (no plugin: the service is the app's own).
final class _AndroidKeepAlive implements HostKeepAlive {
  const _AndroidKeepAlive();

  static const MethodChannel _channel = MethodChannel('dev.pokercredits/host_service');

  @override
  Future<void> start(String roomCode) => _call('start', <String, Object?>{'roomCode': roomCode});

  @override
  Future<void> stop() => _call('stop');

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      _log.warning('host service $method failed: ${error.code} ${error.message}');
    } on MissingPluginException {
      _log.warning('host service channel is not registered');
    }
  }
}

final class _NoKeepAlive implements HostKeepAlive {
  const _NoKeepAlive();

  @override
  Future<void> start(String roomCode) async {}

  @override
  Future<void> stop() async {}
}
