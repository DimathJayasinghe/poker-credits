// Loads the real native library and runs the embedded server. Skipped unless
// POKER_BRIDGE_LIB points at the built library, so the default test run needs no Rust build:
//
//   cargo build -p rust_lib_poker_bridge
//   POKER_BRIDGE_LIB=$PWD/../../target/debug/librust_lib_poker_bridge.so fvm flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_bridge/src/rust/frb_generated.dart';

void main() {
  final libraryPath = Platform.environment['POKER_BRIDGE_LIB'];

  test(
    'the embedded server answers over HTTP and stops',
    () async {
      await RustLib.init(externalLibrary: ExternalLibrary.open(libraryPath!));
      final controller = ServerController();
      final events = <RsServerEvent>[];
      controller.events.listen(events.add);

      await controller.start(
        const RsServerConfig(
          port: 0,
          exposeOnLan: false,
          dataDir: '',
          serverName: 'smoke',
        ),
      );
      final port = controller.port!;
      expect(port, isNonZero);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/v1/info'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      expect(response.statusCode, 200);
      expect(body, contains('smoke'));

      // A second server on the same port is a typed failure, not a crash.
      final second = ServerController();
      await expectLater(
        second.start(
          RsServerConfig(
            port: port,
            exposeOnLan: false,
            dataDir: '',
            serverName: 'again',
          ),
        ),
        throwsA(
          isA<BridgeException>().having(
            (e) => e.kind,
            'kind',
            BridgeFailureKind.bind,
          ),
        ),
      );

      await controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        events.map((e) => e.kind),
        containsAllInOrder([
          RsServerEventKind.listening,
          RsServerEventKind.stopped,
        ]),
      );
    },
    skip: libraryPath == null ? 'set POKER_BRIDGE_LIB to run' : false,
  );
}
