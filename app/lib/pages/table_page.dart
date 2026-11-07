import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_credits/model/runout_pacer.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/seat_order.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/guide/guide_sheet.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_dialog.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/player/action_buttons.dart';
import 'package:poker_credits/widget/player/raise_slider.dart';
import 'package:poker_credits/widget/player/turn_alert.dart';
import 'package:poker_credits/widget/table/action_ticker.dart';
import 'package:poker_credits/widget/table/felt_layout.dart';
import 'package:poker_credits/widget/table/host_controls.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/pot_results.dart';
import 'package:poker_credits/widget/table/qr_panel.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_credits/widget/table/table_fit.dart';
import 'package:poker_credits/widget/table/seat_order_sheet.dart';
import 'package:poker_credits/widget/table/showdown_sheet.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Slots around the table; the engine seats at most 10 players.
const int tableSeats = 10;

/// Largest text scale the host table honours, however much height there is (see [TablePage.build]).
const double _maxTextScale = 2;

/// The Table display: follows the app theme, landscape or tablet, readable from across the room.
/// The host sees the controls; with [watching] it is the read-only spectator view (no controls,
/// no seat menu).
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

  /// The seated host's own cards: face up or not, and for which hand that was decided (see
  /// `PlayerPage`). On a screen others can see, cards only show while a finger is held on them.
  bool _faceUp = false;
  int? _cardsHand;

  /// Reveals a run-out one street at a time; plates, winners and START HAND wait for the last card.
  final RunoutPacer _pacer = RunoutPacer();

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      if (_faceUp) setState(() => _faceUp = false);
    }
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

  /// Back (the arrow, the system gesture or key). A spectator, or a screen that has already
  /// ended, leaves at once; the host is asked first because leaving ends the game for everybody.
  void _onBack() {
    final session = ref.read(sessionProvider);
    if (widget.watching || session.link.failure != null || session.room.ended != null) {
      _leave();
    } else {
      _endGame();
    }
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
      maxWidth: wideSheetWidth(context),
      scrolls: false,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      // The table is a game and never scrolls: its text grows only as far as the height allows
      // (see [TableFit.maxTextScale]), and never past 200 %. Every other screen scales to 300 %,
      // and dialogs and sheets opened from here are outside this clamp.
      child: Builder(
        builder: (context) {
          final size = MediaQuery.sizeOf(context);
          final usable = size.height - MediaQuery.paddingOf(context).vertical;
          final wide = TableFit.isWide(Size(size.width, usable));
          final cap = math.min(_maxTextScale, TableFit.maxTextScale(usable, wide: wide));
          final scale = math.min(cap, MediaQuery.textScalerOf(context).scale(14) / 14);
          // Worked out here, outside the safe area: inside it the system bars are already gone.
          final fit = wide ? TableFit.forWide(usable, textScale: scale) : TableFit.forHeight(usable, textScale: scale, width: size.width);
          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: cap,
            child: PaperScaffold(body: Builder(builder: (context) => _body(context, session, host, fit))),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, SessionState session, HostState host, TableFit fit) {
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
    final rawView = session.room.view;
    if (rawView == null) {
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
    final view = _pacer.paced(rawView, now, instant: MediaQuery.of(context).disableAnimations);
    final settled = _pacer.settled(rawView.board);
    final remaining = room.turnRemainingMs(now);
    final limit = view.turnDeadlineMs == null ? null : (room.view?.turnDeadlineMs);
    final myId = host.room?.playerId;
    final seatsByIndex = <int, SeatView>{for (final seat in view.seats) seat.seatIndex: seat};
    final acting = view.activeSeat == null ? null : seatsByIndex[view.activeSeat!];
    final mine = _myPrompt(session, view);
    _alertOnce(session, view, mine);
    final inFlight = _sentSeq == room.nextActionSeq && room.lastError == null;
    final settings = context.ref.watch(settingsProvider);
    final showCards = room.showsCards;
    final board = view.board;
    final result = view.result;
    final revealsById = <String, Reveal>{for (final r in view.reveals) r.playerId: r};
    final winners = <String>{
      if (result != null)
        for (final pot in result.pots) ...pot.winnerPlayerIds,
    };
    final mySeat = widget.watching ? null : session.mySeat;
    if (_cardsHand != view.handNumber) {
      _cardsHand = view.handNumber;
      _faceUp = settings.cardsFaceUp;
    }
    final sharedScreen = MediaQuery.sizeOf(context).width >= FeltLayout.narrowWidth;
    final hasDock = showCards && mySeat != null;
    final lobby = view.phase == WirePhase.lobby;
    final onItsSide = MediaQuery.sizeOf(context).width >= 600 && MediaQuery.sizeOf(context).height < 460;
    final fourColour = settings.fourColourDeck;

    Widget actingLine({required double fontSize}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '> ${Strings.acting.toUpperCase()}: ${acting!.name.toUpperCase()}${remaining == null ? '' : '  ${clock(remaining)}'}',
        style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: fontSize, color: c.onFelt),
      ),
    );
    // The middle of the felt when the table has to be small: the pot with the board beside it, and
    // under them who is to act or who won.
    final compactCenter = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              PotDisplay(total: view.totalPot, pots: view.pots, fontSize: fit.pot, compact: true),
              if (showCards) ...<Widget>[
                const SizedBox(width: BrutalMetrics.gapM),
                BoardView(shown: board, size: fit.boardCard, fourColour: fourColour, slotColor: c.onFelt, animate: true),
              ],
            ],
          ),
        ),
        if (result != null) ...<Widget>[
          const SizedBox(height: BrutalMetrics.gapXs),
          PotResults(result: result, color: c.onFelt),
        ] else if (acting != null && mine == null) ...<Widget>[
          // On my own turn the "your turn" line under the table says it, with the clock.
          const SizedBox(height: BrutalMetrics.gapXs),
          actingLine(fontSize: 14),
        ],
      ],
    );
    FeltLayout felt({bool showCenter = true}) => FeltLayout(
      fit: fit,
      showCenter: showCenter,
      seatCount: tableSeats,
      occupied: seatsByIndex.keys.toSet(),
      center: lobby
          ? QrPanel(roomCode: view.roomCode, addresses: host.joinAddresses)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PotDisplay(total: view.totalPot, pots: view.pots),
                if (showCards) ...<Widget>[
                  const SizedBox(height: BrutalMetrics.gapS),
                  BoardView(shown: board, fourColour: fourColour, slotColor: c.onFelt, animate: true),
                ],
                if (result != null) ...<Widget>[
                  const SizedBox(height: BrutalMetrics.gapS),
                  PotResults(result: result, color: c.onFelt),
                ] else if (acting != null) ...<Widget>[
                  const SizedBox(height: BrutalMetrics.gapM),
                  actingLine(fontSize: 20),
                ],
              ],
            ),
      compactCenter: lobby
          ? QrPanel(roomCode: view.roomCode, addresses: host.joinAddresses, qrSize: onItsSide ? 96 : fit.qr, compact: true)
          : compactCenter,
      framed: !lobby,
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
          seatNumber: seatsLocked(view.phase) ? null : seatNumber(index),
          onTap: session.isHost && seat.playerId != myId ? () => _seatMenu(seat) : null,
          cards: revealsById[seat.playerId]?.cards ?? (showCards && seat.hasCards && !seat.hasFolded ? const <PokerCard?>[null, null] : null),
          isWinner: winners.contains(seat.playerId),
        );
      },
    );
    EdgeInsets blockPad() =>
        EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: fit.isRoomy ? BrutalMetrics.gapS : (fit.isTight ? 2 : BrutalMetrics.gapXs));
    // What sits under the table (or in the pane beside it): the seated host's cards and buttons,
    // then the host's own controls. [width] is the room they get.
    // The seated host's own cards and turn buttons, each on its own (null when not shown).
    ({Widget? hand, Widget? turn}) playerParts() {
      final turn = mine == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${Strings.yourTurn}${remaining == null ? '' : '  ${clock(remaining)}'}'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: fit.isRoomy ? 24 : 18, color: c.accent),
                ),
                SizedBox(height: fit.isRoomy ? BrutalMetrics.gapS : BrutalMetrics.gapXs),
                ActionButtons(
                  legal: mine.legal,
                  enabled: session.link.isLive && !inFlight,
                  onFold: () => _act(const FoldAction()),
                  onCheck: () => _act(const CheckAction()),
                  onCall: () => _act(const CallAction()),
                  onRaise: () => _raise(mine.legal),
                  buttonHeight: fit.button,
                  gap: fit.gap,
                  oneRow: !fit.isRoomy,
                  compact: !fit.isRoomy,
                ),
              ],
            );
      final hand = showCards && mySeat != null
          ? HoleCardsDock(
              cards: mySeat.hasFolded ? null : room.visibleHoleCards,
              faceUp: _faceUp,
              pressToPeek: sharedScreen,
              fourColour: fourColour,
              size: fit.dockCard,
              showHint: fit.isRoomy,
              verticalPadding: fit.isRoomy ? BrutalMetrics.gapS : 2,
              onToggle: () => setState(() => _faceUp = !_faceUp),
            )
          : null;
      return (hand: hand, turn: turn);
    }

    List<Widget> player(double width) {
      final (:hand, :turn) = playerParts();
      // The cards beside the buttons when the width allows, so the two together take one row of height.
      final sideBySide = !fit.isRoomy && hand != null && turn != null && width >= 300;
      return <Widget>[
        if (sideBySide)
          Padding(
            padding: blockPad(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(width: fit.dockCard.width * 2 + BrutalMetrics.gapS, child: hand),
                const SizedBox(width: BrutalMetrics.gapM),
                Expanded(child: turn),
              ],
            ),
          )
        else ...<Widget>[
          if (hand != null)
            Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: hand),
            ),
          if (turn != null)
            Padding(
              padding: blockPad(),
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: turn),
              ),
            ),
        ],
      ];
    }

    List<Widget> hostPart() {
      return <Widget>[
        if (session.isHost) ...<Widget>[
          for (final rebuy in view.pendingRebuys.where((r) => !r.approved)) _rebuyStrip(view, rebuy),
          Padding(
            padding: blockPad(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (lobby && !fit.isTight) ...<Widget>[
                      Text(
                        Strings.lobbyHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.35, color: c.muted),
                      ),
                      const SizedBox(height: BrutalMetrics.gapS),
                    ],
                    HostControls(
                      view: view,
                      enabled: session.link.isLive,
                      onSend: _send,
                      onPickWinners: () => _pickWinners(view),
                      onSeats: () => showSeatOrderSheet(context, isHost: true),
                      onEndGame: _endGame,
                      virtual: showCards,
                      holdStart: !settled,
                      fit: fit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ];
    }

    final hasControls = session.isHost || mine != null || (showCards && mySeat != null);
    final seated = mySeat != null && !widget.watching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TopBar(view: view, watching: widget.watching, onBack: _onBack),
        if (!session.link.isLive) _linkBanner(session.link),
        if (view.paused) const BrutalBanner(message: Strings.gamePaused, kind: BrutalBannerKind.warning),
        if (room.presenceCheck != null && session.isHost) _presenceStrip(room.presenceCheck!),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final around = EdgeInsets.all(fit.isRoomy ? BrutalMetrics.gapM : (fit.isTight ? 6 : BrutalMetrics.gapS));
              // Wide but short (a phone on its side, a window): the controls take a pane at the
              // right, so the table keeps the whole height.
              if (hasControls &&
                  box.maxWidth >= FeltLayout.narrowWidth &&
                  _needsPane(context, box, myTurn: mine != null, host: session.isHost, lobby: lobby, dock: hasDock)) {
                // A seated host has two stacks of controls and gets a wider pane.
                final pane = seated ? (box.maxWidth * 0.46).clamp(360.0, 460.0) : (box.maxWidth * 0.3).clamp(232.0, 380.0);
                final line = BorderSide(color: c.line, width: BrutalMetrics.border);
                // Where the oval cannot fit beside the pane, the seats are a grid and the pot and
                // the board move into the pane (the join code stays above the seats), so the seats
                // get the whole height.
                final seatsBox = Size(box.maxWidth - pane - 2 * around.left, box.maxHeight - 2 * around.top);
                final middleInPane = !lobby && !FeltLayout.ovalFits(seatsBox, FeltLayout.plateHeightFor(context));
                final middle = DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.felt,
                    border: Border.all(color: c.line, width: BrutalMetrics.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(fit.isRoomy ? fit.gap : BrutalMetrics.gapXs),
                    child: Center(child: compactCenter),
                  ),
                );
                final (:hand, :turn) = playerParts();
                // The pot and the board with the seated host's cards beside them, the turn buttons
                // under, then the host's controls: three short rows in place of five.
                final top = middleInPane && hand != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(child: middle),
                          const SizedBox(width: BrutalMetrics.gapS),
                          SizedBox(width: fit.dockCard.width * 2 + BrutalMetrics.gapS, child: hand),
                        ],
                      )
                    : (middleInPane ? middle : hand);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: around,
                        child: felt(showCenter: !middleInPane),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(border: Border(left: line)),
                      child: SizedBox(
                        width: pane,
                        child: LayoutBuilder(
                          // The pane is the last place that scrolls: only when a seated host with
                          // cards, buttons and controls has less height than they need together.
                          builder: (context, paneBox) => SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: paneBox.maxHeight),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    if (top != null) Padding(padding: blockPad(), child: top),
                                    if (turn != null) Padding(padding: blockPad(), child: turn),
                                    ...hostPart(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Padding(padding: around, child: felt()),
                  ),
                  ...player(box.maxWidth),
                  ...hostPart(),
                ],
              );
            },
          ),
        ),
        ActionTicker(actions: room.ticker, compact: !fit.isRoomy),
      ],
    );
  }

  /// Rough height of what sits under the table while it is shown: the turn buttons and the host
  /// controls. Only used to decide whether the oval still fits above them on a wide screen; if not,
  /// the controls move to a pane at the side.
  static const double _turnBlockHeight = 150;

  /// The seated host's cards and their caption.
  static const double _dockHeight = 150;

  static double _hostBlockHeight({required bool lobby}) => 16 + (lobby ? 44 : 0) + 56 + BrutalMetrics.gapS + 48 + 2 * BrutalMetrics.gapS + 60;

  bool _needsPane(
    BuildContext context,
    BoxConstraints box, {
    required bool myTurn,
    required bool host,
    required bool lobby,
    required bool dock,
  }) {
    if (box.maxHeight < 460) return true;
    final chrome = (dock ? _dockHeight : 0) + (myTurn ? _turnBlockHeight : 0) + (host ? _hostBlockHeight(lobby: lobby) : 0) + 2 * BrutalMetrics.gapM;
    return box.maxHeight < FeltLayout.minOvalHeight(context) + chrome;
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
  const _TopBar({required this.view, required this.watching, required this.onBack});

  final RoomView view;
  final bool watching;
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
            child: TopBarStat(label: Strings.room, value: view.roomCode),
          ),
          Expanded(
            flex: 2,
            child: TopBarStat(label: Strings.hand, value: '${view.handNumber}'),
          ),
          Expanded(
            flex: 3,
            child: TopBarStat(label: Strings.phase, value: phaseLabel(view.phase)),
          ),
          if (watching)
            const Expanded(
              flex: 3,
              child: TopBarStat(label: Strings.you, value: Strings.watching),
            )
          else if (view.spectatorCount > 0)
            Expanded(
              flex: 2,
              child: TopBarStat(label: Strings.watching, value: '${view.spectatorCount}'),
            ),
          const GuideCell(),
        ],
      ),
    );
  }
}
