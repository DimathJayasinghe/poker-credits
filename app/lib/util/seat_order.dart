import 'package:poker_protocol/poker_protocol.dart';

/// Seats on the wire run 0 to 9; people count them from 1.
int seatNumber(int seatIndex) => seatIndex + 1;

/// The seats cannot be changed while a hand is being played: the seat order is the turn order.
/// The server refuses it too (`HAND_IN_PROGRESS`); this only decides whether the controls are on.
bool seatsLocked(WirePhase phase) => phase != WirePhase.lobby && phase != WirePhase.nextHandPrep;

/// Names in table order (seat 1 first, clockwise), for reading the order out loud and checking it
/// against who actually sits where.
List<String> clockwiseNames(Iterable<SeatView> seats) {
  final sorted = seats.toList()..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
  return <String>[for (final seat in sorted) seat.name];
}

/// What tapping seat [target] does in the seat picker, given who is [selected] (host only).
sealed class SeatTap {
  const SeatTap();
}

/// Nothing happens (an occupied seat for a guest, the locked table, the guest's own seat).
final class SeatTapIgnored extends SeatTap {
  const SeatTapIgnored();
}

/// Host: pick up the player in this seat.
final class SeatTapSelect extends SeatTap {
  const SeatTapSelect(this.playerId);
  final String playerId;
}

/// Host: put the picked-up player back down (cancel the pick).
final class SeatTapClear extends SeatTap {
  const SeatTapClear();
}

/// Send this message and clear the pick.
final class SeatTapSend extends SeatTap {
  const SeatTapSend(this.message);
  final ClientMessage message;
}

/// Decides a tap. A guest moves only themselves, and only onto a free seat. The host picks a
/// player first, then a seat; an occupied target swaps the two (the server does the swap).
SeatTap seatTap({
  required bool isHost,
  required String myPlayerId,
  required Map<int, SeatView> seats,
  required int target,
  required String? selected,
  required WirePhase phase,
}) {
  if (seatsLocked(phase)) return const SeatTapIgnored();
  final occupant = seats[target];
  if (!isHost) {
    if (occupant != null) return const SeatTapIgnored();
    return SeatTapSend(ChooseSeat(seatIndex: target));
  }
  if (selected == null) {
    return occupant == null ? const SeatTapIgnored() : SeatTapSelect(occupant.playerId);
  }
  if (occupant?.playerId == selected) return const SeatTapClear();
  return SeatTapSend(MoveSeat(playerId: selected, seatIndex: target));
}
