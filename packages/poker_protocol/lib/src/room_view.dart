import 'package:dart_mappable/dart_mappable.dart';

import 'card.dart';
import 'omit.dart';
import 'wire_case.dart';

part 'room_view.mapper.dart';

/// What a connection may do.
@MappableEnum(caseStyle: screamingSnake, defaultValue: Role.spectator)
enum Role { host, player, spectator }

/// Where the hand is. [paused] is shown instead of the real phase while the game is frozen.
@MappableEnum(caseStyle: screamingSnake, defaultValue: WirePhase.lobby)
enum WirePhase { lobby, preFlop, flop, turn, river, allInRunout, showdown, nextHandPrep, paused }

/// What a hand is worth, lowest first. A category this client does not know decodes to
/// [highCard]; the name is only a label, the server decides who wins.
@MappableEnum(caseStyle: screamingSnake, defaultValue: HandCategory.highCard)
enum HandCategory { highCard, pair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush }

/// One seat at the table.
@MappableClass(hook: OmitWhenDefault({'hasCards': false}))
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
    this.hasCards = false,
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

  /// Virtual cards: this seat still holds face-down cards in the hand being played. Says nothing
  /// about which cards.
  final bool hasCards;
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

/// A hand shown at showdown (virtual cards). Everyone in the room gets these.
@MappableClass(includeCustomMappers: [PokerCardMapper()])
class Reveal with RevealMappable {
  const Reveal({required this.playerId, required this.name, required this.cards, required this.category, required this.bestFive});

  final String playerId;

  /// The player's name for that hand, kept even if they left since.
  final String name;

  /// The two hole cards.
  final List<PokerCard> cards;
  final HandCategory category;

  /// The five cards that make the hand.
  final List<PokerCard> bestFive;
}

/// What one winner received from a pot.
@MappableClass()
class Share with ShareMappable {
  const Share({required this.playerId, required this.name, required this.amount});

  final String playerId;
  final String name;
  final int amount;
}

/// How one pot was paid.
@MappableClass()
class PotResult with PotResultMappable {
  const PotResult({required this.potIndex, required this.amount, required this.winnerPlayerIds, required this.shares});

  /// 0 = main pot.
  final int potIndex;
  final int amount;
  final List<String> winnerPlayerIds;
  final List<Share> shares;
}

/// How the last hand was paid, kept until the next hand starts.
@MappableClass()
class HandResult with HandResultMappable {
  const HandResult({required this.uncontested, required this.pots});

  /// Everyone else folded; no hands were compared.
  final bool uncontested;

  /// Main pot first.
  final List<PotResult> pots;
}

/// One finishing place in a single-player game.
@MappableClass()
class Finish with FinishMappable {
  const Finish({required this.playerId, required this.name, required this.place});

  final String playerId;

  /// Kept here because the seat is gone once a player is out.
  final String name;

  /// 1 = winner, 2 = runner-up, and so on.
  final int place;
}

/// The public state of a room, as sent in `SNAPSHOT` and `STATE_UPDATE`.
@MappableClass(
  includeCustomMappers: [PokerCardMapper()],
  hook: OmitWhenDefault({'board': <Object?>[], 'reveals': <Object?>[], 'finishOrder': <Object?>[]}),
)
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
    this.board = const <PokerCard>[],
    this.reveals = const <Reveal>[],
    this.result,
    this.finishOrder = const <Finish>[],
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

  /// Virtual cards: the community cards shown so far (0, 3, 4 or 5).
  final List<PokerCard> board;

  /// Virtual cards: hands shown at showdown. Empty until betting ends with two or more contenders.
  final List<Reveal> reveals;

  /// Virtual cards: how the last hand was paid. Stays until the next hand is dealt.
  final HandResult? result;

  /// Single-player games: who has gone out, in order, with the winner last. Empty otherwise.
  final List<Finish> finishOrder;
}
