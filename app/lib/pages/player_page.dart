import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_credits/model/solo_result.dart';
import 'package:poker_credits/pages/solo_result_page.dart';
import 'package:poker_credits/model/runout_pacer.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/provider/solo_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/seat_order.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/guide/guide_sheet.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_dialog.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/brutal/brutal_tag.dart';
import 'package:poker_credits/widget/table/blind_status.dart';
import 'package:poker_credits/widget/table/seat_order_sheet.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_credits/widget/player/action_buttons.dart';
import 'package:poker_credits/widget/player/opponent_strip.dart';
import 'package:poker_credits/widget/player/raise_slider.dart';
import 'package:poker_credits/widget/player/rebuy_sheet.dart';
import 'package:poker_credits/widget/player/turn_alert.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The player's controller: portrait, one thumb. It shows your chips, whose turn it is and, on
/// your turn, the buttons the server allows. It never decides a rule and never shows the table.
///
/// With [solo] it is the table of a single-player game: the same controller with the blinds in the
/// top bar, every stack in view, and the controls of a game nobody else is waiting for (pause and
/// end instead of top up, sit out and leave). The server decides all of it.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.solo = false});

  final bool solo;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with Refena, WidgetsBindingObserver {
  /// The three small buttons share a height that fits a two-line label on a narrow phone.
  static const double _secondaryHeight = 64;

  Timer? _ticker;
  final TurnAlertGate _gate = TurnAlertGate();

  /// The action counter of the action already sent, so a second tap before the answer is ignored.
  int? _sentSeq;

  /// Whether my own cards are face up, and for which hand that was decided. A new hand starts from
  /// the setting again, so cards never carry over open.
  bool _faceUp = false;
  int? _cardsHand;

  /// Reveals a run-out one street at a time; the result waits until the last card is down.
  final RunoutPacer _pacer = RunoutPacer();

  /// Single-player games: how many finishing places were already announced (`null` until the first
  /// view, so places from before this screen opened are not announced), the lines still shown and
  /// the hand they were announced in.
  int? _seenFinishes;
  final List<Finish> _outLines = <Finish>[];
  int _outLinesHand = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ensureRef((ref) {
      if (ref.read(settingsProvider).keepAwake) ref.read(wakeLockProvider).enable();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: the socket is probably dead, so reconnect and let the server
    // send a fresh snapshot (a `RESUME`, never a second join).
    // A single-player game wakes its own server first (see `SoloTablePage`).
    if (state == AppLifecycleState.resumed && !widget.solo) ref.notifier(sessionProvider).reconnect();
    // Leaving the app (switcher thumbnails, a notification pulled down) never leaves cards open.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      if (_faceUp) setState(() => _faceUp = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(wakeLockProvider).disable();
    super.dispose();
  }

  bool _send(ClientMessage message) => ref.notifier(sessionProvider).send(message);

  void _act(PlayerAction action) {
    final room = ref.read(sessionProvider).room;
    ref.read(hapticsProvider).tap();
    // Only a message that really left counts as sent: with a dead socket the buttons must stay
    // usable for when the link is back.
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

  void _topUp(int? suggestion) {
    showBrutalSheet<void>(
      context: context,
      title: Strings.topUpTitle,
      builder: (sheetContext) => RebuySheet(
        suggestion: suggestion,
        onAsk: (amount) {
          Navigator.of(sheetContext).pop();
          _send(RequestRebuy(amount: amount));
        },
      ),
    );
  }

  Future<void> _leaveTable() async {
    final yes = await confirmBrutal(
      context: context,
      title: Strings.leaveTableTitle,
      message: Strings.leaveTableBody,
      confirmLabel: Strings.leaveTable,
      cancelLabel: Strings.cancel,
      danger: true,
    );
    if (!yes) return;
    _send(const LeaveTable());
    await _exit();
  }

  /// Back (the arrow, the system gesture or key): asks first while seated, because leaving gives
  /// the seat up; leaves straight away when there is no game to lose.
  void _onBack() {
    final session = ref.read(sessionProvider);
    if (widget.solo) {
      _soloBack(session);
      return;
    }
    final inGame = session.link.failure == null && session.room.ended == null && session.room.view != null && session.mySeat != null;
    if (inGame) {
      _leaveTable();
    } else {
      _exit();
    }
  }

  Future<void> _exit({bool keep = false}) async {
    if (widget.solo) {
      final solo = ref.notifier(soloProvider);
      await (keep ? solo.suspend() : solo.leave());
    } else {
      await ref.read(joinProvider).leave();
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Back in a single-player game: while it is on, the game is saved and can be resumed; when it is
  /// over or gone there is nothing to keep.
  Future<void> _soloBack(SessionState session) async {
    final view = session.room.view;
    final over = view != null && SoloResult.from(view, session.playerId, const SoloStats()) != null;
    if (over || session.link.failure != null || session.room.ended != null || view == null) {
      await _exit();
      return;
    }
    final keep = await confirmBrutal(
      context: context,
      title: Strings.soloLeaveTitle,
      message: Strings.soloLeaveBody,
      confirmLabel: Strings.soloSaveExit,
      cancelLabel: Strings.keepPlaying,
    );
    if (keep) await _exit(keep: true);
  }

  /// Ends a single-player game for good, after asking.
  Future<void> _endSolo() async {
    final yes = await confirmBrutal(
      context: context,
      title: Strings.soloEndTitle,
      message: Strings.soloEndBody,
      confirmLabel: Strings.soloEnd,
      cancelLabel: Strings.cancel,
      danger: true,
    );
    if (yes) await _exit();
  }

  void _seeResult() => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const SoloResultPage()));

  /// Keeps the lines "Maya is out (6th)" of the last two hands.
  void _syncOut(RoomView view) {
    final seen = _seenFinishes ?? view.finishOrder.length;
    final fresh = newlyOut(view.finishOrder, seen);
    _seenFinishes = view.finishOrder.length;
    if (fresh.isNotEmpty) {
      _outLines.addAll(fresh);
      _outLinesHand = view.handNumber;
    }
    if (_outLines.isNotEmpty && view.handNumber > _outLinesHand + 1) _outLines.clear();
  }

  /// Vibration and sound once per turn; see [TurnAlertGate].
  void _alertOnce(SessionState session) {
    final view = session.room.view;
    final prompt = session.room.prompt;
    if (view == null || prompt == null || prompt.playerId != session.playerId) return;
    if (!_gate.shouldFire(prompt: prompt, handNumber: view.handNumber)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(hapticsProvider).yourTurn();
      ref.read(soundProvider).yourTurn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    // One thumb column: on a tablet or TV it stays phone-sized in the middle.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: PaperScaffold(
        body: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _body(context, session)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SessionState session) {
    final failure = session.link.failure;
    final ended = session.room.ended;
    if (failure != null || ended != null) {
      final text = failure != null ? linkFailureText(failure) : (ended == RoomEnd.crashed ? Strings.linkFailedCrashed : Strings.linkFailedExpired);
      return _panel(context, Strings.roomEndedTitle, text);
    }
    final view = session.room.view;
    if (view == null) return _connecting(context, session);
    final seat = session.mySeat;
    if (seat == null) return _panel(context, Strings.noSeat, Strings.noSeat);
    _alertOnce(session);
    return _controller(context, session, view, seat);
  }

  Widget _panel(BuildContext context, String title, String text) {
    final c = BrutalTheme.of(context).colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(BrutalMetrics.gapM),
          child: BrutalCard(
            header: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  text.toUpperCase(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.ink),
                ),
                const SizedBox(height: BrutalMetrics.gapM),
                BrutalButton(label: Strings.leaveRoom, kind: BrutalButtonKind.primary, onPressed: _exit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _connecting(BuildContext context, SessionState session) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      children: <Widget>[
        if (!session.link.isLive) _linkBanner(session.link),
        Expanded(
          child: Center(
            child: Text(
              Strings.reconnecting.toUpperCase(),
              style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 32, color: c.ink),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(BrutalMetrics.gapM),
          child: BrutalButton(label: Strings.leaveRoom, onPressed: _exit),
        ),
      ],
    );
  }

  Widget _linkBanner(LinkState link) {
    final stuck = link.stillTrying(ref.read(clockProvider)());
    return BrutalBanner(
      message: stuck ? Strings.stillTrying : Strings.reconnecting,
      kind: BrutalBannerKind.warning,
      actionLabel: stuck ? Strings.retry : null,
      onAction: stuck ? () => ref.notifier(sessionProvider).reconnect() : null,
    );
  }

  /// Starts every hand from the "show my cards at once" setting.
  void _syncCards(RoomView view, bool startOpen) {
    if (_cardsHand == view.handNumber) return;
    _cardsHand = view.handNumber;
    _faceUp = startOpen;
  }

  Widget _dock(RoomState room, SeatView seat, bool fourColour) {
    final cards = seat.hasFolded ? null : room.visibleHoleCards;
    // Dealt but the private message is still on its way: show the backs, not "no cards".
    if (cards == null && seat.hasCards && !seat.hasFolded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
        child: CardRow(cards: <PokerCard?>[null, null], size: CardSize.hero, gap: BrutalMetrics.gapS, alignment: MainAxisAlignment.center),
      );
    }
    return HoleCardsDock(cards: cards, faceUp: _faceUp, onToggle: () => setState(() => _faceUp = !_faceUp), fourColour: fourColour);
  }

  Widget _controller(BuildContext context, SessionState session, RoomView rawView, SeatView rawSeat) {
    final c = BrutalTheme.of(context).colors;
    final settings = context.ref.watch(settingsProvider);
    // Cards of a single-player game are always virtual, even before the first hand.
    final showCards = session.room.showsCards || widget.solo;
    _syncCards(rawView, settings.cardsFaceUp);
    // While a run-out is dealt the screen shows the table as it was: see RunoutPacer.paced.
    final view = _pacer.paced(rawView, ref.read(clockProvider)(), instant: MediaQuery.of(context).disableAnimations);
    final seat = view.seats.where((s) => s.playerId == rawSeat.playerId).firstOrNull ?? rawSeat;
    final board = view.board;
    final result = view.result;
    final room = session.room;
    final live = session.link.isLive;
    final now = ref.read(clockProvider)();
    final remaining = room.turnRemainingMs(now);
    final prompt = room.prompt;
    final myPrompt = prompt != null && prompt.playerId == seat.playerId && view.activeSeat == seat.seatIndex && !view.paused ? prompt : null;
    final myTurn = myPrompt != null;
    final acting = view.activeSeat == null ? null : view.seats.where((s) => s.seatIndex == view.activeSeat).firstOrNull;
    final pending = view.pendingRebuys.where((r) => r.playerId == seat.playerId).firstOrNull;
    final inFlight = _sentSeq == room.nextActionSeq && room.lastError == null;

    final solo = widget.solo;
    if (solo) _syncOut(rawView);
    final finished = solo ? SoloResult.from(rawView, session.playerId, const SoloStats()) : null;
    final over = finished != null;
    final headsUp = solo && !over && view.seats.length == 2;

    final String title;
    String? detail;
    if (finished != null) {
      title = finished.won ? Strings.soloWon : Strings.soloOut;
      detail = '${Strings.ordinal(finished.place)} ${Strings.soloOutOf} ${finished.of}';
    } else if (myTurn) {
      title = Strings.yourTurn;
      detail = remaining == null ? null : '${clock(remaining)} ${Strings.turnLeft}';
    } else if (acting != null) {
      title = '${Strings.waitingFor} ${acting.name}';
      detail = remaining == null ? null : clock(remaining);
    } else {
      title = view.phase == WirePhase.lobby || view.phase == WirePhase.nextHandPrep ? Strings.waitingForHand : phaseLabel(view.phase);
      detail = seat.isSittingOut ? Strings.youAreOut : null;
    }

    final check = widget.solo ? null : room.presenceCheck;
    // At huge text sizes the whole controller scrolls, so the action buttons stay reachable; at
    // normal sizes it fills the screen and the buttons sit at the bottom.
    return CustomScrollView(
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (solo) _SoloTopBar(blinds: view.blinds, onBack: _onBack) else _TopBar(roomCode: view.roomCode, link: session.link, onBack: _onBack),
              if (!live) _linkBanner(session.link),
              if (view.paused) const BrutalBanner(message: Strings.gamePaused, kind: BrutalBannerKind.warning),
              if (room.lastError != null) BrutalBanner(message: errorText(room.lastError!.code), kind: BrutalBannerKind.error),
              if (pending != null && !solo)
                BrutalBanner(message: pending.approved ? Strings.topUpApproved : '${Strings.topUpPending}: ${pending.amount}'),
              if (check != null && check.subjectPlayerId != seat.playerId) _presenceStrip(check),
              Padding(
                padding: const EdgeInsets.all(BrutalMetrics.gapM),
                child: _StackBlock(seat: seat),
              ),
              if (showCards) ...<Widget>[
                OpponentStrip(
                  seats: view.seats,
                  myPlayerId: seat.playerId,
                  showStacks: solo,
                  activeSeat: solo ? view.activeSeat : null,
                  // A new turn (hand, street or bet) starts the thinking bar again.
                  turnKey: '${view.handNumber}:${view.phase.name}:${view.activeSeat}:${view.totalPot}',
                  paused: view.paused,
                ),
                const SizedBox(height: BrutalMetrics.gapS),
              ],
              if (!solo && guestMayChooseSeat(view.phase))
                Padding(
                  padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapM, 0, BrutalMetrics.gapM, BrutalMetrics.gapM),
                  child: BrutalButton(
                    label: '${Strings.seatLabel(seatNumber(seat.seatIndex))}: ${Strings.seatsMove}',
                    onPressed: live ? () => showSeatOrderSheet(context, isHost: false) : null,
                  ),
                ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TurnBlock(myTurn: myTurn, title: title, detail: detail),
                        if (solo && (headsUp || _outLines.isNotEmpty)) _SoloNotes(headsUp: headsUp, outLines: List<Finish>.of(_outLines)),
                        const SizedBox(height: BrutalMetrics.gapM),
                        Text(
                          '${Strings.pot.toUpperCase()} ${view.totalPot}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 28, color: c.ink),
                        ),
                        if (showCards) ...<Widget>[
                          const SizedBox(height: BrutalMetrics.gapM),
                          Center(
                            child: BoardView(shown: board, fourColour: settings.fourColourDeck, animate: true),
                          ),
                        ],
                        if (result != null) ...<Widget>[
                          const SizedBox(height: BrutalMetrics.gapM),
                          ShowdownPanel(
                            animate: true,
                            reveals: view.reveals,
                            result: result,
                            fourColour: settings.fourColourDeck,
                            myPlayerId: seat.playerId,
                          ),
                        ],
                        if (room.ticker.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: BrutalMetrics.gapS),
                            child: Text(
                              '> ${describeAction(room.ticker.last)}'.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, color: c.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapM, 0, BrutalMetrics.gapM, BrutalMetrics.gapM),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (showCards) _dock(room, seat, settings.fourColourDeck),
                    if (myPrompt != null) ...<Widget>[
                      ActionButtons(
                        legal: myPrompt.legal,
                        enabled: live && !inFlight,
                        onFold: () => _act(const FoldAction()),
                        onCheck: () => _act(const CheckAction()),
                        onCall: () => _act(const CallAction()),
                        onRaise: () => _raise(myPrompt.legal),
                      ),
                      const SizedBox(height: BrutalMetrics.gapM),
                    ],
                    if (over)
                      BrutalButton(
                        label: Strings.seeResult,
                        kind: BrutalButtonKind.primary,
                        heavy: true,
                        minHeight: BrutalMetrics.tapPlayer,
                        onPressed: _seeResult,
                      )
                    else if (solo)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: BrutalButton(
                              label: view.paused ? Strings.resume : Strings.pause,
                              minHeight: _secondaryHeight,
                              onPressed: live ? () => _send(view.paused ? const ResumeGame() : const Pause()) : null,
                            ),
                          ),
                          const SizedBox(width: BrutalMetrics.gapS),
                          Expanded(
                            child: BrutalButton(
                              label: Strings.soloEnd,
                              kind: BrutalButtonKind.danger,
                              minHeight: _secondaryHeight,
                              onPressed: _endSolo,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: BrutalButton(label: Strings.topUp, minHeight: _secondaryHeight, onPressed: live ? () => _topUp(null) : null),
                          ),
                          const SizedBox(width: BrutalMetrics.gapS),
                          Expanded(
                            child: BrutalButton(
                              label: seat.isSittingOut ? Strings.imBack : Strings.sitOut,
                              minHeight: _secondaryHeight,
                              onPressed: live ? () => _send(SetSittingOut(sittingOut: !seat.isSittingOut)) : null,
                            ),
                          ),
                          const SizedBox(width: BrutalMetrics.gapS),
                          Expanded(
                            child: BrutalButton(
                              label: Strings.leave,
                              kind: BrutalButtonKind.danger,
                              minHeight: _secondaryHeight,
                              onPressed: _leaveTable,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _presenceStrip(PresenceCheck check) {
    return Container(
      color: BrutalTheme.of(context).colors.paper,
      padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text('${Strings.stillHere} ${check.subjectName}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
  const _TopBar({required this.roomCode, required this.link, required this.onBack});

  final String roomCode;
  final LinkState link;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BackCell(onTap: onBack),
          Expanded(
            flex: 3,
            child: TopBarStat(label: Strings.room, value: roomCode),
          ),
          Expanded(
            flex: 3,
            child: TopBarStat(
              label: Strings.connection,
              value: link.isLive ? Strings.live : Strings.reconnecting,
              valueColor: link.isLive ? null : c.accent,
            ),
          ),
          const GuideCell(),
        ],
      ),
    );
  }
}

/// Your chips in large type, with the state tags.
class _StackBlock extends StatelessWidget {
  const _StackBlock({required this.seat});

  final SeatView seat;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${Strings.yourStack} · ${seat.name}'.toUpperCase(),
          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: c.muted),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BrutalNumber(seat.chips, size: 64, color: c.ink),
              ),
            ),
            if (seat.streetBet > 0) ...<Widget>[
              const SizedBox(width: BrutalMetrics.gapM),
              // Shrinks rather than pushing the row wider than the screen at huge text sizes.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${Strings.yourBet.toUpperCase()} ${seat.streetBet}',
                    style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 18, color: c.ink),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: BrutalMetrics.gapS),
        Wrap(
          spacing: BrutalMetrics.gapS,
          runSpacing: BrutalMetrics.gapXs,
          children: <Widget>[
            if (seat.hasFolded) const BrutalTag(Strings.folded),
            if (seat.isAllIn) const BrutalTag(Strings.allIn, kind: BrutalTagKind.danger),
            if (seat.isSittingOut) const BrutalTag(Strings.sittingOut),
          ],
        ),
      ],
    );
  }
}

/// The top bar of a single-player game: the blinds and when they rise, where the room code and the
/// connection are in an ordinary game.
class _SoloTopBar extends StatelessWidget {
  const _SoloTopBar({required this.blinds, required this.onBack});

  final BlindsView? blinds;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BackCell(onTap: onBack),
          Expanded(child: BlindStatusCells(blinds: blinds)),
          const GuideCell(),
        ],
      ),
    );
  }
}

/// Short lines under the turn block: the heads-up announcement and who went out.
class _SoloNotes extends StatelessWidget {
  const _SoloNotes({required this.headsUp, required this.outLines});

  final bool headsUp;
  final List<Finish> outLines;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final style = TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 14, color: c.ink);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: BrutalMetrics.gapS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (headsUp) Text('> ${Strings.headsUp}'.toUpperCase(), textAlign: TextAlign.center, style: style),
            for (final out in outLines.reversed.take(2))
              Text('> ${Strings.outLine(out.name, out.place)}'.toUpperCase(), textAlign: TextAlign.center, style: style),
          ],
        ),
      ),
    );
  }
}
