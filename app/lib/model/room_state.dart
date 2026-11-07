import 'package:flutter/foundation.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// What the client knows about the room, built only from server messages.
///
/// The server is the single source of truth (no poker rules here): this class stores what the
/// server sent and rejects out-of-order updates, nothing else. A `SNAPSHOT` replaces everything.
@immutable
class RoomState {
  const RoomState({
    this.view,
    this.stateVersion = -1,
    this.clockOffsetMs = 0,
    this.nextActionSeq = 0,
    this.prompt,
    this.holeCards,
    this.ticker = const <ActionPerformed>[],
    this.presenceCheck,
    this.lastError,
    this.needsResync = false,
    this.ended,
  });

  /// Latest public view, `null` until the first `SNAPSHOT`.
  final RoomView? view;

  /// Version of [view]; `STATE_UPDATE`s must carry a higher one.
  final int stateVersion;

  /// Server clock minus local clock in ms, from `SNAPSHOT.serverTime`.
  final int clockOffsetMs;

  /// The `actionSeq` to use for the next `GAME_ACTION`; always the server's last value.
  final int nextActionSeq;

  /// What the player on turn may do (only while it is this player's turn).
  final TurnPrompt? prompt;

  /// Virtual cards: this player's own cards, from the private `HOLE_CARDS` message.
  ///
  /// Never read this to draw cards: use [visibleHoleCards], which checks the hand number.
  final HoleCards? holeCards;

  /// Recent actions, newest last, for the ticker.
  final List<ActionPerformed> ticker;

  /// A presence check running now.
  final PresenceCheck? presenceCheck;

  /// Last `ERROR` from the server, for a toast. Cleared by the next accepted message.
  final ErrorMessage? lastError;

  /// A `STATE_UPDATE` skipped a version: the connection layer must send `RESUME`.
  final bool needsResync;

  /// Set when the room is gone for good.
  final RoomEnd? ended;

  /// How many actions the ticker keeps.
  static const int tickerLength = 20;

  /// The two cards to show: [holeCards] only while they belong to the hand on the table. Between
  /// a new hand's `STATE_UPDATE` and its `HOLE_CARDS` this is `null` and the dock shows backs.
  List<PokerCard>? get visibleHoleCards {
    final cards = holeCards;
    final current = view;
    if (cards == null || current == null || cards.handNumber != current.handNumber) return null;
    return cards.cards;
  }

  /// Whether the hand on the table is a virtual-card hand. The view carries no room-wide card
  /// mode, so this reads the signs a virtual hand leaves: a seat holding cards, community cards, a
  /// payout, revealed hands, or cards dealt to me. A real-cards room shows none of them.
  bool get showsCards {
    final current = view;
    if (current == null) return false;
    return visibleHoleCards != null ||
        current.board.isNotEmpty ||
        current.result != null ||
        current.reveals.isNotEmpty ||
        current.seats.any((s) => s.hasCards);
  }

  /// Whether the first snapshot has arrived.
  bool get hasView => view != null;

  /// Server time now, using the offset from the last snapshot.
  int serverNowMs(DateTime localNow) => localNow.millisecondsSinceEpoch + clockOffsetMs;

  /// Milliseconds left on the turn clock, or `null` when there is none.
  int? turnRemainingMs(DateTime localNow) {
    final deadline = view?.turnDeadlineMs;
    if (deadline == null) return null;
    final left = deadline - serverNowMs(localNow);
    return left < 0 ? 0 : left;
  }

  /// Applies one server message and returns the new state (or this one when nothing changes).
  RoomState apply(ServerMessage message, {required DateTime localNow}) {
    switch (message) {
      case Snapshot():
        return RoomState(
          view: message.view,
          stateVersion: message.stateVersion,
          clockOffsetMs: message.serverTime - localNow.millisecondsSinceEpoch,
          nextActionSeq: message.nextActionSeq,
          holeCards: _cardsFor(message.view),
          ticker: ticker,
          presenceCheck: presenceCheck,
        );
      case StateUpdate():
        if (message.stateVersion <= stateVersion) return this;
        if (view != null && message.stateVersion > stateVersion + 1) {
          return _copy(needsResync: true);
        }
        final stale = prompt != null && message.view.activeSeat != prompt!.seatIndex;
        return _copy(
          view: message.view,
          stateVersion: message.stateVersion,
          prompt: stale ? null : prompt,
          clearPrompt: stale,
          clearError: true,
          clearHoleCards: _cardsFor(message.view) == null,
        );
      case HoleCards():
        final held = holeCards;
        if (held != null && message.handNumber < held.handNumber) return this;
        if (held == message) return this;
        return _copy(holeCards: message);
      case TurnPrompt():
        return _copy(prompt: message, nextActionSeq: message.nextActionSeq);
      case ActionPerformed():
        final next = <ActionPerformed>[...ticker, message];
        final trimmed = next.length > tickerLength ? next.sublist(next.length - tickerLength) : next;
        return _copy(ticker: trimmed);
      case Ack():
        return _copy(nextActionSeq: message.nextActionSeq, clearError: true);
      case ErrorMessage():
        return _copy(lastError: message);
      case PresenceCheck():
        return _copy(presenceCheck: message);
      case PresenceResolved():
        return _copy(clearPresence: true);
      case PlayerConnection():
        // Presence is not part of the state version: the server tells it on its own, so a guest
        // who joined (or dropped) after the last state update shows up (or goes) at once.
        final current = view;
        if (current == null) return this;
        final index = current.seats.indexWhere((seat) => seat.seatIndex == message.seatIndex && seat.playerId == message.playerId);
        if (index < 0 || current.seats[index].isConnected == message.isConnected) return this;
        final seats = List<SeatView>.of(current.seats);
        seats[index] = seats[index].copyWith(isConnected: message.isConnected);
        return _copy(view: current.copyWith(seats: seats));
      case RoomCrashed():
        return _copy(ended: RoomEnd.crashed);
      case RoomExpired():
        return _copy(ended: RoomEnd.expired);
      case RoomCreated() || Joined() || GamePaused() || GameResumed() || RoomRecovered() || Pong() || PlayerAway() || UnknownServerMessage():
        // Carried by the next STATE_UPDATE / SNAPSHOT, or handled by the connection layer.
        return this;
    }
  }

  /// The held cards unless [next] makes them stale: a lobby, or a later hand.
  HoleCards? _cardsFor(RoomView next) {
    final held = holeCards;
    if (held == null || next.phase == WirePhase.lobby || next.handNumber > held.handNumber) return null;
    return held;
  }

  /// Clears the resync flag after a `RESUME` was sent.
  RoomState resyncRequested() => _copy(needsResync: false);

  RoomState _copy({
    RoomView? view,
    int? stateVersion,
    int? nextActionSeq,
    TurnPrompt? prompt,
    bool clearPrompt = false,
    HoleCards? holeCards,
    bool clearHoleCards = false,
    List<ActionPerformed>? ticker,
    ErrorMessage? lastError,
    bool clearError = false,
    bool? needsResync,
    bool clearPresence = false,
    PresenceCheck? presenceCheck,
    RoomEnd? ended,
  }) {
    return RoomState(
      view: view ?? this.view,
      stateVersion: stateVersion ?? this.stateVersion,
      clockOffsetMs: clockOffsetMs,
      nextActionSeq: nextActionSeq ?? this.nextActionSeq,
      prompt: clearPrompt ? null : (prompt ?? this.prompt),
      holeCards: clearHoleCards ? null : (holeCards ?? this.holeCards),
      ticker: ticker ?? this.ticker,
      presenceCheck: clearPresence ? null : (presenceCheck ?? this.presenceCheck),
      lastError: clearError ? null : (lastError ?? this.lastError),
      needsResync: needsResync ?? this.needsResync,
      ended: ended ?? this.ended,
    );
  }
}

/// Why a room is over.
enum RoomEnd { crashed, expired }
