import 'package:dart_mappable/dart_mappable.dart';

import 'wire_case.dart';

part 'room_view.mapper.dart';

/// What a connection may do.
@MappableEnum(caseStyle: screamingSnake, defaultValue: Role.spectator)
enum Role { host, player, spectator }

/// Where the hand is. [paused] is shown instead of the real phase while the game is frozen.
@MappableEnum(caseStyle: screamingSnake, defaultValue: WirePhase.lobby)
enum WirePhase { lobby, preFlop, flop, turn, river, allInRunout, showdown, nextHandPrep, paused }

/// One seat at the table.
@MappableClass()
class SeatView with SeatViewMappable {
  const SeatView({
    required this.seatIndex,
    required this.playerId,
    required this.name,
    required this.chips,
    required this.streetBet,
    required this.hasFolded,
    required this.isAllIn,
    required this.isSittingOut,
    required this.isConnected,
  });

  final int seatIndex;
  final String playerId;
  final String name;
  final int chips;
  final int streetBet;
  final bool hasFolded;
  final bool isAllIn;
  final bool isSittingOut;
  final bool isConnected;
}

/// One pot (main pot is tier 0).
@MappableClass()
class PotView with PotViewMappable {
  const PotView({required this.tierIndex, required this.amount, required this.eligiblePlayerIds});

  final int tierIndex;
  final int amount;
  final List<String> eligiblePlayerIds;
}

/// A top-up request, public so the host can approve it (`APPROVE_REBUY`).
@MappableClass()
class PendingRebuyView with PendingRebuyViewMappable {
  const PendingRebuyView({required this.playerId, required this.amount, required this.approved});

  final String playerId;
  final int amount;

  /// The host already approved it; it applies between hands.
  final bool approved;
}

/// The public state of a room, as sent in `SNAPSHOT` and `STATE_UPDATE`.
@MappableClass()
class RoomView with RoomViewMappable {
  const RoomView({
    required this.roomCode,
    required this.handNumber,
    required this.phase,
    this.dealerSeat,
    this.smallBlindSeat,
    this.bigBlindSeat,
    this.activeSeat,
    required this.currentHighBet,
    required this.minRaiseTo,
    required this.totalPot,
    required this.pots,
    required this.seats,
    required this.paused,
    this.turnDeadlineMs,
    required this.spectatorCount,
    this.pendingRebuys = const <PendingRebuyView>[],
  });

  final String roomCode;
  final int handNumber;
  final WirePhase phase;
  final int? dealerSeat;
  final int? smallBlindSeat;
  final int? bigBlindSeat;
  final int? activeSeat;
  final int currentHighBet;
  final int minRaiseTo;
  final int totalPot;
  final List<PotView> pots;
  final List<SeatView> seats;
  final bool paused;

  /// Absolute server time in milliseconds; use the `serverTime` offset for the countdown.
  final int? turnDeadlineMs;
  final int spectatorCount;

  /// Top-ups waiting for the host.
  final List<PendingRebuyView> pendingRebuys;
}
