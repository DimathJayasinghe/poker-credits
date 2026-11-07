import 'dart:async';

import 'package:logging/logging.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/model/solo_result.dart';
import 'package:poker_credits/net/features.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = Logger('Solo');

/// Where the single-player flow stands.
enum SoloPhase { idle, starting, ready, failed }

class SoloState {
  const SoloState({this.phase = SoloPhase.idle, this.error, this.stats = const SoloStats(), this.hasSaved = false});

  final SoloPhase phase;
  final HostException? error;

  /// A single-player game is saved and Home can offer to resume it.
  final bool hasSaved;

  /// What the player has done in the game that is open.
  final SoloStats stats;

  /// A single-player game is open on this device.
  bool get active => phase == SoloPhase.ready;

  SoloState copyWith({SoloPhase? phase, HostException? error, SoloStats? stats, bool? hasSaved}) =>
      SoloState(phase: phase ?? this.phase, error: error, stats: stats ?? this.stats, hasSaved: hasSaved ?? this.hasSaved);
}

final soloProvider = NotifierProvider<SoloNotifier, SoloState>((ref) => SoloNotifier());

/// Starts a single-player game on the loopback-only server and connects the player's own screen
/// to it, exactly like any other client (ADR-018). The game is saved in [TokenSlot.solo], so it
/// never touches a hosted or joined game saved in the main slot.
class SoloNotifier extends Notifier<SoloState> {
  @override
  SoloState init() => const SoloState();

  /// The table kind of the open game, for its record; `null` when it is not known.
  ({int bots, BotSkill skill})? _kind;

  /// How many opponents the open game started with and at which skill, if known.
  ({int bots, BotSkill skill})? get kind => _kind;

  /// The finished game was already added to the record.
  bool _recorded = false;
  StreamSubscription<Object?>? _watching;

  Uri _loopback(int port) => Uri.parse('ws://127.0.0.1:$port/v1/ws');

  /// The saved single-player game, if there is one.
  Future<StoredSession?> saved() => ref.read(tokenStoreProvider).read(slot: TokenSlot.solo);

  /// Looks at the store and updates [SoloState.hasSaved]; Home calls it when it opens and after
  /// something else (Settings) may have forgotten the game.
  Future<void> refreshSaved() async {
    final has = await saved() != null;
    if (has != state.hasSaved) state = state.copyWith(hasSaved: has);
  }

  /// Starts a new game. Returns false when it could not start; [SoloState.error] says why.
  Future<bool> start({required String name, required SoloConfig solo}) async {
    if (state.phase == SoloPhase.starting) return false;
    state = state.copyWith(phase: SoloPhase.starting);
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
              soloBots: solo.bots,
              soloSkill: solo.skill.name,
            ),
            slot: TokenSlot.solo,
          );
      _kind = (bots: solo.bots, skill: solo.skill);
      _connect(room);
      state = const SoloState(phase: SoloPhase.ready, hasSaved: true);
      return true;
    } on HostException catch (error) {
      _log.warning('could not start a single-player game', error);
      state = state.copyWith(phase: SoloPhase.failed, error: error);
      return false;
    }
  }

  /// Goes back to the saved game. Returns false when there is none or the server cannot run.
  Future<bool> restore() async {
    if (state.phase == SoloPhase.starting) return false;
    final stored = await saved();
    final hostToken = stored?.hostToken;
    if (stored == null || hostToken == null) return false;
    state = state.copyWith(phase: SoloPhase.starting);
    try {
      final port = await ref.read(hostServerProvider).startSoloServer();
      final bots = stored.soloBots;
      final skill = BotSkill.values.asNameMap()[stored.soloSkill];
      _kind = bots != null && skill != null ? (bots: bots, skill: skill) : null;
      _connect(
        HostedRoom(
          roomCode: stored.roomCode,
          playerId: stored.playerId ?? '',
          sessionToken: stored.sessionToken,
          hostToken: hostToken,
          port: port,
        ),
      );
      state = const SoloState(phase: SoloPhase.ready, hasSaved: true);
      return true;
    } on HostException catch (error) {
      _log.warning('could not resume the single-player game', error);
      state = state.copyWith(phase: SoloPhase.failed, error: error);
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
      state = state.copyWith(phase: SoloPhase.failed, error: error);
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
    _unwatch();
    await ref.notifier(sessionProvider).leave();
    await ref.read(hostServerProvider).stop();
    // A game that was never established leaves nothing in the session to clear it.
    await ref.read(tokenStoreProvider).clear(slot: TokenSlot.solo);
    state = const SoloState();
  }

  /// Closes the table screen but keeps the game saved, so Home offers it again.
  Future<void> suspend() async {
    _unwatch();
    final session = ref.notifier(sessionProvider);
    final slot = ref.read(tokenStoreProvider);
    final saved = await slot.read(slot: TokenSlot.solo);
    await session.leave();
    // `leave` forgets the tokens of its slot: put them back, the game itself still exists.
    if (saved != null) await slot.write(saved, slot: TokenSlot.solo);
    await ref.read(hostServerProvider).stop();
    state = const SoloState(hasSaved: true);
  }

  /// Counts the hands and, once, the finished game. Runs on every change of the session.
  void _observe(SessionState session) {
    final view = session.room.view;
    if (view == null || !state.active) return;
    final stats = state.stats.observe(view, session.playerId);
    if (stats != state.stats) state = state.copyWith(stats: stats);
    if (_recorded || SoloResult.from(view, session.playerId, stats) == null) return;
    _recorded = true;
    _record(SoloResult.from(view, session.playerId, stats)!);
  }

  /// Adds a finished game to the record of its table kind, and forgets the saved game: it is over
  /// and cannot be resumed, so it must not be counted a second time.
  void _record(SoloResult result) {
    final kind = _kind;
    if (kind != null) {
      final key = soloRecordKey(kind.bots, kind.skill);
      ref
          .notifier(settingsProvider)
          .update(
            (s) =>
                s.copyWith(soloRecords: <String, SoloRecord>{...s.soloRecords, key: (s.soloRecords[key] ?? const SoloRecord()).after(result.place)}),
          );
    }
    state = state.copyWith(hasSaved: false);
    unawaited(ref.read(tokenStoreProvider).clear(slot: TokenSlot.solo));
  }

  void _unwatch() {
    unawaited(_watching?.cancel());
    _watching = null;
  }

  void _connect(HostedRoom room) {
    _recorded = false;
    _unwatch();
    _watching = ref.stream(sessionProvider).listen((event) => _observe(event.next));
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
