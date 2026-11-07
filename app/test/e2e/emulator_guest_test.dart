import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_protocol/poker_protocol.dart';

import 'support/device.dart';

/// A manual check against a host running in the Android emulator (not part of the automatic run).
///
/// 1. Host a game in the app on the emulator and note the room code.
/// 2. `adb forward tcp:17878 tcp:7878`
/// 3. `EMULATOR_ROOM=<code> POKER_BRIDGE_LIB=... fvm flutter test test/e2e/emulator_guest_test.dart`
///
/// A guest on this machine joins by typed address (the first certificate is taken, as a phone
/// does), takes a seat and stays until the host presses start; then it plays a hand to the end.
/// Pass `EMULATOR_HOLD=<seconds>` to stay seated longer.
void main() {
  final room = Platform.environment['EMULATOR_ROOM'];
  final skip = room == null || e2eSkipReason != null ? 'set EMULATOR_ROOM and POKER_BRIDGE_LIB (see the comment above)' : null;
  final hold = int.tryParse(Platform.environment['EMULATOR_HOLD'] ?? '') ?? 90;

  test(
    'a guest on this machine joins the host in the emulator and plays a hand',
    () async {
      final ana = Device('ana');
      addTearDown(ana.dispose);
      await initBridge(libraryPath: nativeLibraryPath);
      await ana.joinSeated(JoinLink(hostAndPort: '127.0.0.1:17878', roomCode: room!), 'Ana');
      expect(ana.view!.seats.map((s) => s.name), containsAll(<String>['Ana']));
      // ignore: avoid_print
      print('seated: ${ana.view!.seats.map((s) => s.name).toList()}; waiting for the host to start a hand');

      await eventually('the host started a hand', () => ana.view!.phase != WirePhase.lobby, timeout: Duration(seconds: hold));
      // ignore: avoid_print
      print('hand started: phase ${ana.view!.phase}');
      // Fold whenever it is our turn, until the hand is over.
      await eventually(
        'the hand ended',
        () {
          ana.actFold();
          return ana.view!.phase == WirePhase.nextHandPrep || ana.view!.phase == WirePhase.lobby;
        },
        timeout: const Duration(seconds: 120),
      );
      expect(ana.link.phase, LinkPhase.live);
    },
    skip: skip,
    timeout: Timeout(Duration(seconds: hold + 200)),
  );
}
