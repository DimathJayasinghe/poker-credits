import 'package:dart_mappable/dart_mappable.dart';

part 'room_config.mapper.dart';

/// Room settings chosen by the host.
@MappableClass()
class RoomConfig with RoomConfigMappable {
  const RoomConfig({
    required this.startingChips,
    required this.smallBlind,
    required this.bigBlind,
    required this.ante,
    required this.isTournament,
    required this.blindLevelMinutes,
    required this.turnTimeLimitSeconds,
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
}
