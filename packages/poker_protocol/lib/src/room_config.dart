import 'package:dart_mappable/dart_mappable.dart';

import 'omit.dart';
import 'wire_case.dart';

part 'room_config.mapper.dart';

/// Whether the players hold real cards or the app deals them.
///
/// A room is one or the other for its whole life. A mode this client does not know decodes to
/// [physical], the room that needs no cards from the app.
@MappableEnum(caseStyle: screamingSnake, defaultValue: CardMode.physical)
enum CardMode { physical, virtual }

/// How well the computer players of a single-player game play. An unknown level decodes to
/// [normal].
@MappableEnum(caseStyle: screamingSnake, defaultValue: BotSkill.normal)
enum BotSkill { easy, normal, hard }

/// The extra settings of a single-player game against computer players.
@MappableClass()
class SoloConfig with SoloConfigMappable {
  const SoloConfig({required this.bots, required this.skill, required this.ladderHands});

  /// Computer players at the table, 1 to 9.
  final int bots;

  /// How well they play.
  final BotSkill skill;

  /// Hands played at each blind level.
  final int ladderHands;
}

/// Room settings chosen by the host.
@MappableClass(hook: OmitWhenDefault({'cardMode': 'PHYSICAL'}))
class RoomConfig with RoomConfigMappable {
  const RoomConfig({
    required this.startingChips,
    required this.smallBlind,
    required this.bigBlind,
    required this.ante,
    required this.isTournament,
    required this.blindLevelMinutes,
    required this.turnTimeLimitSeconds,
    this.cardMode = CardMode.physical,
    this.solo,
  });

  /// Stack every player starts with.
  final int startingChips;

  /// Small blind (first level for tournaments).
  final int smallBlind;

  /// Big blind (first level for tournaments).
  final int bigBlind;

  /// Ante, zero for none.
  final int ante;

  /// Escalating blinds instead of fixed ones.
  final bool isTournament;

  /// Minutes per tournament level.
  final int blindLevelMinutes;

  /// Seconds a player has to act, zero for no timer.
  final int turnTimeLimitSeconds;

  /// Real cards (default) or cards dealt by the app.
  final CardMode cardMode;

  /// Set for a single-player game, which is also always virtual cards. Absent for every other room.
  final SoloConfig? solo;
}
