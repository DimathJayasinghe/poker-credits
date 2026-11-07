import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';

import 'support/device.dart';

/// A manual check with a guest in the Android emulator (not part of the automatic run).
///
/// Run `EMULATOR_HOST=1 POKER_BRIDGE_LIB=... fvm flutter test test/e2e/emulator_host_test.dart`,
/// read the room code it prints, and join it from the emulator's app (the emulator reaches this
/// machine as 10.0.2.2, which the app's own search of the network finds by the room code). The
/// test starts a hand as soon as someone is seated, calls whatever is asked of it, and ends when
/// the hand is over. `EMULATOR_HOLD=<seconds>` sets how long it waits for the guest.
void main() {
  final skip = Platform.environment['EMULATOR_HOST'] == null || e2eSkipReason != null
      ? 'set EMULATOR_HOST and POKER_BRIDGE_LIB (see the comment above)'
      : null;
  final hold = int.tryParse(Platform.environment['EMULATOR_HOLD'] ?? '') ?? 240;

  test(
    'a host on this machine takes a guest from the emulator through a hand',
    () async {
      final host = Device('host');
      addTearDown(host.dispose);
      final room = await host.host(hostName: 'PcHost');
      // ignore: avoid_print
      print('ROOM ${room.roomCode} on port ${room.port}');

      await eventually('a guest sat down', () => host.view!.seats.length >= 2, timeout: Duration(seconds: hold));
      final guest = host.view!.seats.firstWhere((s) => s.name != 'PcHost');
      // ignore: avoid_print
      print('GUEST ${guest.name} connected=${guest.isConnected}');
      await Future<void>.delayed(const Duration(seconds: 2));
      host.container.notifier(sessionProvider).send(const StartHand());
      await eventually('the hand started', () => host.view!.phase != WirePhase.lobby);
      // ignore: avoid_print
      print('HAND started');
      // Check or call whenever it is the host's turn; the guest plays from the emulator. At showdown
      // the host names the winner: the guest, so the emulator shows a win.
      var resolved = false;
      await eventually(
        'the hand ended',
        () {
          if (host.view!.phase == WirePhase.showdown && !resolved) {
            resolved = true;
            final guestId = host.view!.seats.firstWhere((s) => s.name != 'PcHost').playerId;
            host.container
                .notifier(sessionProvider)
                .send(
                  ResolveShowdown(
                    allocations: <WireAllocation>[
                      for (final pot in host.view!.pots) WireAllocation(potIndex: pot.tierIndex, winnerPlayerIds: <String>[guestId]),
                    ],
                  ),
                );
          }
          final prompt = host.session.room.prompt;
          if (prompt != null) {
            final action = prompt.legal.canCheck ? const CheckAction() : const CallAction();
            host.container.notifier(sessionProvider).send(GameAction(actionSeq: host.session.room.nextActionSeq, action: action));
          }
          return host.view!.phase == WirePhase.nextHandPrep;
        },
        timeout: const Duration(seconds: 200),
      );
      final chips = host.view!.seats.map((s) => s.chips).fold<int>(0, (a, b) => a + b);
      // ignore: avoid_print
      print('HAND over, chips ${host.view!.seats.map((s) => '${s.name}:${s.chips}').toList()} total $chips');
      expect(chips, 2000);
    },
    skip: skip,
    timeout: Timeout(Duration(seconds: hold + 400)),
  );
}
