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
}
