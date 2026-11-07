import 'package:poker_protocol/poker_protocol.dart';

/// Paces the reveal of community cards after an all-in. The server deals the whole run-out in one
/// step; showing it that way would give away the result before anyone saw a card. A single normal
/// street (flop, turn or river) appears at once; a run-out shows its first street at once and the
/// following ones [step] apart. It is pure: the caller passes the time and asks again on each
/// repaint, so nothing here owns a timer.
class RunoutPacer {
  RunoutPacer({this.step = const Duration(milliseconds: 1300)});

  /// Time between the streets of a run-out.
  final Duration step;

  /// Board sizes after each street.
  static const List<int> _streets = <int>[3, 4, 5];

  int? _hand;
  List<PokerCard> _shown = const <PokerCard>[];

  /// A run-out is under way: its first street was shown at [_lastStep].
  bool _running = false;
  DateTime _lastStep = DateTime.fromMillisecondsSinceEpoch(0);

  /// The board cards to draw now for [target], the server's board of [hand]. One street moves per
  /// call at most, so a slow frame never skips a card.
  List<PokerCard> shown(int hand, List<PokerCard> target, DateTime now, {bool instant = false}) {
    final unrelated = _hand != hand || target.length < _shown.length || !_isPrefix(_shown, target);
    if (unrelated || instant) {
      _hand = hand;
      _shown = target;
      _running = false;
      return _shown;
    }
    if (_shown.length < target.length && (!_running || !now.isBefore(_lastStep.add(step)))) {
      final next = _streets.firstWhere((size) => size > _shown.length, orElse: () => target.length);
      _shown = target.sublist(0, next < target.length ? next : target.length);
      _lastStep = now;
      _running = _shown.length < target.length;
    }
    return _shown;
  }

  /// The last view whose whole board was on show: what the table looked like before the payout.
  RoomView? _lastSettled;

  /// [view] as it may be drawn now. While a run-out is still being dealt, the board is the part
  /// shown so far and nothing says how the hand ended: the server has already paid the pots, so
  /// the pot, the stacks and bets come from the last settled view, and the result and revealed
  /// hands are left out. Otherwise [view] comes back unchanged.
  RoomView paced(RoomView view, DateTime now, {bool instant = false}) {
    final board = shown(view.handNumber, view.board, now, instant: instant);
    if (settled(view.board)) {
      _lastSettled = view;
      return view;
    }
    final held = _lastSettled;
    final sameHand = held != null && held.handNumber == view.handNumber;
    final before = <String, SeatView>{
      if (sameHand)
        for (final seat in held.seats) seat.playerId: seat,
    };
    return RoomView(
      roomCode: view.roomCode,
      handNumber: view.handNumber,
      phase: view.phase,
      dealerSeat: view.dealerSeat,
      smallBlindSeat: view.smallBlindSeat,
      bigBlindSeat: view.bigBlindSeat,
      activeSeat: view.activeSeat,
      currentHighBet: view.currentHighBet,
      minRaiseTo: view.minRaiseTo,
      totalPot: sameHand ? held.totalPot : view.totalPot,
      pots: sameHand ? held.pots : view.pots,
      seats: <SeatView>[
        for (final seat in view.seats)
          before[seat.playerId] == null ? seat : seat.copyWith(chips: before[seat.playerId]!.chips, streetBet: before[seat.playerId]!.streetBet),
      ],
      paused: view.paused,
      turnDeadlineMs: view.turnDeadlineMs,
      spectatorCount: view.spectatorCount,
      pendingRebuys: view.pendingRebuys,
      board: board,
    );
  }

  /// Whether everything the server dealt is on show.
  bool settled(List<PokerCard> target) => _shown.length >= target.length;

  static bool _isPrefix(List<PokerCard> shown, List<PokerCard> target) {
    for (var i = 0; i < shown.length; i++) {
      if (i >= target.length || shown[i] != target[i]) return false;
    }
    return true;
  }
}
