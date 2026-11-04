import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_dialog.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/player/action_buttons.dart';
import 'package:poker_credits/widget/player/raise_slider.dart';
import 'package:poker_credits/widget/player/turn_alert.dart';
import 'package:poker_credits/widget/table/action_ticker.dart';
import 'package:poker_credits/widget/table/felt_layout.dart';
import 'package:poker_credits/widget/table/host_controls.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/qr_panel.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_credits/widget/table/showdown_sheet.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Slots around the table; the engine seats at most 10 players.
const int tableSeats = 10;

/// The Table display: dark by default, landscape, readable from across the room. The host sees
/// the controls; with [watching] it is the read-only spectator view (no controls, no seat menu).
class TablePage extends StatefulWidget {
  const TablePage({super.key, this.watching = false});

  final bool watching;

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> with Refena, WidgetsBindingObserver {
  Timer? _ticker;

  /// The host also sits at the table: on their own turn the same server-driven buttons the Player
  /// screen has appear here, so the host never has to time out of a hand.
  final TurnAlertGate _gate = TurnAlertGate();
  int? _sentSeq;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ensureRef((ref) {
      if (ref.read(settingsProvider).keepAwake) ref.read(wakeLockProvider).enable();
    });
    // Repaints about 4 times a second for the turn countdown (the text is derived from the
    // server deadline, nothing is counted locally).
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.watching) {
        ref.notifier(sessionProvider).reconnect();
      } else {
        ref.notifier(hostProvider).onForeground();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(wakeLockProvider).disable();
    super.dispose();
  }

  Future<void> _leave() async {
    if (widget.watching) {
      await ref.read(joinProvider).leave();
    } else {
      await ref.notifier(hostProvider).stop();
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _endGame() async {
    final yes = await confirmBrutal(
      context: context,
      title: Strings.endGameTitle,
      message: Strings.endGameBody,
      confirmLabel: Strings.endGame,
      cancelLabel: Strings.cancel,
      danger: true,
    );
    if (yes) {
      ref.notifier(sessionProvider).send(const EndGame());
      await _leave();
    }
  }

  bool _send(ClientMessage message) => ref.notifier(sessionProvider).send(message);

  void _act(PlayerAction action) {
    final room = ref.read(sessionProvider).room;
    ref.read(hapticsProvider).tap();
    // Only a message that really left counts as sent (see PlayerPage._act).
    if (_send(GameAction(actionSeq: room.nextActionSeq, action: action))) {
      setState(() => _sentSeq = room.nextActionSeq);
    }
  }

  void _raise(LegalActions legal) {
    showBrutalSheet<void>(
      context: context,
      title: Strings.raise,
      builder: (sheetContext) => RaiseSlider(
        legal: legal,
        onConfirm: (action) {
          Navigator.of(sheetContext).pop();
          _act(action);
        },
      ),
    );
  }

  /// The host's own pending decision, or null: the prompt must be for this seat, be the live
  /// turn and not be paused.
  TurnPrompt? _myPrompt(SessionState session, RoomView view) {
    final prompt = session.room.prompt;
    final seat = session.mySeat;
    if (widget.watching || !session.isHost || prompt == null || seat == null) return null;
    if (prompt.playerId != seat.playerId || view.activeSeat != seat.seatIndex || view.paused) return null;
    return prompt;
  }

  void _alertOnce(SessionState session, RoomView view, TurnPrompt? mine) {
    if (mine == null || !_gate.shouldFire(prompt: mine, handNumber: view.handNumber)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(hapticsProvider).yourTurn();
      ref.read(soundProvider).yourTurn();
    });
  }

  void _pickWinners(RoomView view) {
    showBrutalSheet<void>(
      context: context,
      title: Strings.resolveShowdown,
      builder: (sheetContext) => ShowdownSheet(
        pots: view.pots,
        seats: view.seats,
        onConfirm: (allocations) {
          _send(ResolveShowdown(allocations: allocations));
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _seatMenu(SeatView seat) async {
    final yes = await confirmBrutal(
      context: context,
      title: Strings.kickTitle,
      message: seat.name,
      confirmLabel: Strings.kick,
      cancelLabel: Strings.cancel,
      danger: true,
    );
    if (yes) _send(Kick(playerId: seat.playerId));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    final host = context.ref.watch(hostProvider);
    // Follows the app theme (Settings): the table is no longer forced dark.
    return PaperScaffold(body: _body(context, session, host));
  }

  Widget _body(BuildContext context, SessionState session, HostState host) {
    final c = BrutalTheme.of(context).colors;
    final failure = session.link.failure;
    final ended = session.room.ended;
    if (failure != null || ended != null) {
      final text = failure != null ? linkFailureText(failure) : (ended == RoomEnd.crashed ? Strings.linkFailedCrashed : Strings.linkFailedExpired);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: BrutalCard(
            header: Strings.roomEndedTitle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  text.toUpperCase(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.ink),
                ),
                const SizedBox(height: BrutalMetrics.gapM),
                BrutalButton(label: Strings.leaveRoom, kind: BrutalButtonKind.primary, onPressed: _leave),
              ],
            ),
          ),
        ),
      );
    }
    final view = session.room.view;
    if (view == null) {
      return Column(
        children: <Widget>[
          if (session.link.isReconnecting) _linkBanner(session.link),
          Expanded(
            child: Center(
              child: Text(
                Strings.reconnecting.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 32, color: c.ink),
              ),
            ),
          ),
        ],
      );
    }
    final room = session.room;
    final now = ref.read(clockProvider)();
    final remaining = room.turnRemainingMs(now);
    final limit = view.turnDeadlineMs == null ? null : (room.view?.turnDeadlineMs);
    final myId = host.room?.playerId;
    final seatsByIndex = <int, SeatView>{for (final seat in view.seats) seat.seatIndex: seat};
    final acting = view.activeSeat == null ? null : seatsByIndex[view.activeSeat!];
    final mine = _myPrompt(session, view);
    _alertOnce(session, view, mine);
    final inFlight = _sentSeq == room.nextActionSeq && room.lastError == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TopBar(view: view, watching: widget.watching),
        if (!session.link.isLive) _linkBanner(session.link),
        if (view.paused) const BrutalBanner(message: Strings.gamePaused, kind: BrutalBannerKind.warning),
        if (room.presenceCheck != null && session.isHost) _presenceStrip(room.presenceCheck!),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(BrutalMetrics.gapM),
            child: FeltLayout(
              seatCount: tableSeats,
              occupied: seatsByIndex.keys.toSet(),
              center: view.phase == WirePhase.lobby
                  ? QrPanel(roomCode: view.roomCode, addresses: host.joinAddresses)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PotDisplay(total: view.totalPot, pots: view.pots),
                        if (acting != null) ...<Widget>[
                          const SizedBox(height: BrutalMetrics.gapM),
                          Text(
                            '> ${Strings.acting.toUpperCase()}: ${acting.name.toUpperCase()}${remaining == null ? '' : '  ${clock(remaining)}'}',
                            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 20, color: c.onFelt),
                          ),
                        ],
                      ],
                    ),
              seatBuilder: (context, index, width) {
                final seat = seatsByIndex[index]!;
                final isActive = view.activeSeat == index;
                final fraction = isActive && remaining != null && limit != null ? _fraction(remaining, room, view) : null;
                return SeatPlate(
                  seat: seat,
                  isActive: isActive,
                  isDealer: view.dealerSeat == index,
                  isSmallBlind: view.smallBlindSeat == index,
                  isBigBlind: view.bigBlindSeat == index,
                  turnFraction: fraction,
                  onTap: session.isHost && seat.playerId != myId ? () => _seatMenu(seat) : null,
                );
              },
            ),
          ),
        ),
        if (mine != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${Strings.yourTurn}${remaining == null ? '' : '  ${clock(remaining)}'}'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 24, color: c.accent),
                    ),
                    const SizedBox(height: BrutalMetrics.gapS),
                    ActionButtons(
                      legal: mine.legal,
                      enabled: session.link.isLive && !inFlight,
                      onFold: () => _act(const FoldAction()),
                      onCheck: () => _act(const CheckAction()),
                      onCall: () => _act(const CallAction()),
                      onRaise: () => _raise(mine.legal),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (session.isHost) ...<Widget>[
          for (final rebuy in view.pendingRebuys.where((r) => !r.approved)) _rebuyStrip(view, rebuy),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
            child: Row(
              children: <Widget>[
                if (view.phase == WirePhase.lobby)
                  Expanded(
                    child: Text(
                      Strings.lobbyHint.toUpperCase(),
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const Spacer(),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: HostControls(
                      view: view,
                      enabled: session.link.isLive,
                      onSend: _send,
                      onPickWinners: () => _pickWinners(view),
                      onEndGame: _endGame,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ActionTicker(actions: room.ticker),
      ],
    );
  }

  /// Share of the turn clock left. The server sends a deadline, not the length, so the bar
  /// uses the largest remaining time seen for this deadline as "full".
  double? _fraction(int remaining, RoomState room, RoomView view) {
    final deadline = view.turnDeadlineMs;
    if (deadline == null) return null;
    final full = _fullTurn[deadline] ?? (_fullTurn[deadline] = remaining > 0 ? remaining : 1);
    if (_fullTurn.length > 8) _fullTurn.remove(_fullTurn.keys.first);
    return remaining / full;
  }

  final Map<int, int> _fullTurn = <int, int>{};

  Widget _linkBanner(LinkState link) {
    final stuck = link.stillTrying(ref.read(clockProvider)());
    return BrutalBanner(
      message: stuck ? Strings.stillTrying : Strings.reconnecting,
      kind: BrutalBannerKind.warning,
      actionLabel: stuck ? Strings.retry : null,
      onAction: stuck ? () => ref.notifier(sessionProvider).reconnect() : null,
    );
  }

  Widget _rebuyStrip(RoomView view, PendingRebuyView rebuy) {
    final name = view.seats.where((s) => s.playerId == rebuy.playerId).map((s) => s.name).firstOrNull ?? rebuy.playerId;
    return BrutalBanner(
      message: '$name ${Strings.rebuyRequest} ${rebuy.amount}',
      actionLabel: Strings.approve,
      onAction: () => _send(ApproveRebuy(playerId: rebuy.playerId, amount: rebuy.amount)),
    );
  }

  Widget _presenceStrip(PresenceCheck check) {
    return Container(
      decoration: BoxDecoration(
        color: BrutalTheme.of(context).colors.surface,
        border: Border(
          bottom: BorderSide(color: BrutalTheme.of(context).colors.line, width: BrutalMetrics.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text('${Strings.presenceCheck} ${check.subjectName}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          BrutalButton(
            label: Strings.yes,
            onPressed: () => _send(PresenceVote(playerId: check.subjectPlayerId, stillPlaying: true)),
          ),
          const SizedBox(width: BrutalMetrics.gapS),
          BrutalButton(
            label: Strings.no,
            kind: BrutalButtonKind.danger,
            onPressed: () => _send(PresenceVote(playerId: check.subjectPlayerId, stillPlaying: false)),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.view, required this.watching});

  final RoomView view;
  final bool watching;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    TextStyle style(double size) => TextStyle(fontFamily: BrutalFonts.display, fontSize: size, letterSpacing: 0.8, color: c.ink);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
      // Wraps onto a second line on a narrow phone instead of overflowing.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BrutalMetrics.gapM,
        children: <Widget>[
          Text('${Strings.room.toUpperCase()} ${view.roomCode}', style: style(24)),
          Text('${Strings.hand.toUpperCase()} ${view.handNumber}   ${phaseLabel(view.phase).toUpperCase()}', style: style(22)),
          if (watching)
            const BrutalTag(Strings.watching)
          else if (view.spectatorCount > 0)
            Text('${Strings.watching.toUpperCase()} ${view.spectatorCount}', style: style(16)),
        ],
      ),
    );
  }
}
