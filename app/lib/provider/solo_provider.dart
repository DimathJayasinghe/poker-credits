import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/net/features.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = Logger('Solo');

/// Where the single-player flow stands.
enum SoloPhase { idle, starting, ready, failed }

class SoloState {
  const SoloState({this.phase = SoloPhase.idle, this.error});

  final SoloPhase phase;
  final HostException? error;

  /// A single-player game is open on this device.
  bool get active => phase == SoloPhase.ready;
}

final soloProvider = NotifierProvider<SoloNotifier, SoloState>((ref) => SoloNotifier());

/// Starts a single-player game on the loopback-only server and connects the player's own screen
/// to it, exactly like any other client (ADR-018). The game is saved in [TokenSlot.solo], so it
/// never touches a hosted or joined game saved in the main slot.
class SoloNotifier extends Notifier<SoloState> {
  @override
  SoloState init() => const SoloState();

  Uri _loopback(int port) => Uri.parse('ws://127.0.0.1:$port/v1/ws');

  /// The saved single-player game, if there is one.
  Future<StoredSession?> saved() => ref.read(tokenStoreProvider).read(slot: TokenSlot.solo);

  /// Starts a new game. Returns false when it could not start; [SoloState.error] says why.
  Future<bool> start({required String name, required SoloConfig solo}) async {
    if (state.phase == SoloPhase.starting) return false;
    state = const SoloState(phase: SoloPhase.starting);
    try {
      final room = await ref.read(hostServerProvider).hostSolo(hostName: name, solo: solo);
      // The old saved game (if any) is replaced: there is one single-player game at a time.
      await ref
          .read(tokenStoreProvider)
          .write(
            StoredSession(
              serverUri: _loopback(room.port).toString(),
              roomCode: room.roomCode,
              sessionToken: room.sessionToken,
              hostToken: room.hostToken,
              playerId: room.playerId,
            ),
            slot: TokenSlot.solo,
          );
      _connect(room);
      state = const SoloState(phase: SoloPhase.ready);
      return true;
    } on HostException catch (error) {
      _log.warning('could not start a single-player game', error);
      state = SoloState(phase: SoloPhase.failed, error: error);
      return false;
    }
  }

  /// Goes back to the saved game. Returns false when there is none or the server cannot run.
  Future<bool> restore() async {
    if (state.phase == SoloPhase.starting) return false;
    final stored = await saved();
    final hostToken = stored?.hostToken;
    if (stored == null || hostToken == null) return false;
    state = const SoloState(phase: SoloPhase.starting);
    try {
      final port = await ref.read(hostServerProvider).startSoloServer();
      _connect(
        HostedRoom(
          roomCode: stored.roomCode,
          playerId: stored.playerId ?? '',
          sessionToken: stored.sessionToken,
          hostToken: hostToken,
          port: port,
        ),
      );
      state = const SoloState(phase: SoloPhase.ready);
      return true;
    } on HostException catch (error) {
      _log.warning('could not resume the single-player game', error);
      state = SoloState(phase: SoloPhase.failed, error: error);
      return false;
    }
  }

  /// The app left the foreground: the game pauses, so the computer players do not play while
  /// the screen is off. A game that is already paused or over is left alone.
  void onBackground() {
    if (!state.active) return;
    final room = ref.read(sessionProvider).room;
    if (room.ended != null || room.view?.paused == true) return;
    ref.notifier(sessionProvider).send(const Pause());
  }

  /// The app is back: make sure the server still runs, then reconnect. The game stays paused
  /// until the player presses Resume, so nothing happens behind their back.
  Future<void> onForeground() async {
    if (!state.active) return;
    try {
      await ref.read(hostServerProvider).ensureRunning();
    } on HostException catch (error) {
      _log.warning('the single-player server could not be restarted', error);
      state = SoloState(phase: SoloPhase.failed, error: error);
      return;
    }
    ref.notifier(sessionProvider).reconnect();
  }

  /// Resumes a paused game.
  void resume() {
    if (state.active) ref.notifier(sessionProvider).send(const ResumeGame());
  }

  /// Ends the game: leaves the room, stops the server and forgets the saved game.
  Future<void> leave() async {
    await ref.notifier(sessionProvider).leave();
    await ref.read(hostServerProvider).stop();
    // A game that was never established leaves nothing in the session to clear it.
    await ref.read(tokenStoreProvider).clear(slot: TokenSlot.solo);
    state = const SoloState();
  }

  /// Closes the table screen but keeps the game saved, so Home offers it again.
  Future<void> suspend() async {
    final session = ref.notifier(sessionProvider);
    final slot = ref.read(tokenStoreProvider);
    final saved = await slot.read(slot: TokenSlot.solo);
    await session.leave();
    // `leave` forgets the tokens of its slot: put them back, the game itself still exists.
    if (saved != null) await slot.write(saved, slot: TokenSlot.solo);
    await ref.read(hostServerProvider).stop();
    state = const SoloState();
  }

  void _connect(HostedRoom room) {
    ref
        .notifier(sessionProvider)
        .attach(
          uri: _loopback(room.port),
          first: Resume(
            roomCode: room.roomCode,
            sessionToken: room.sessionToken,
            hostToken: room.hostToken,
            features: appFeatures,
          ),
          host: true,
          playerId: room.playerId.isEmpty ? null : room.playerId,
          slot: TokenSlot.solo,
        );
  }
}
