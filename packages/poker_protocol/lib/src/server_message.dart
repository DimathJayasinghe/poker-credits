import 'package:dart_mappable/dart_mappable.dart';

import 'wire_case.dart';

import 'error_code.dart';
import 'player_action.dart';
import 'room_view.dart';

part 'server_message.mapper.dart';

/// Everything the server may send. The `type` field picks the subclass; a type this client does
/// not know decodes to [UnknownServerMessage].
@MappableClass(discriminatorKey: 'type', caseStyle: screamingSnake)
sealed class ServerMessage with ServerMessageMappable {
  const ServerMessage();
}

/// A message type added by a newer server. Ignore it.
@MappableClass(discriminatorValue: MappableClass.useAsDefault)
class UnknownServerMessage extends ServerMessage with UnknownServerMessageMappable {
  const UnknownServerMessage();
}

/// Cloud mode: the room exists and you are its host.
@MappableClass(discriminatorValue: 'ROOM_CREATED')
class RoomCreated extends ServerMessage with RoomCreatedMappable {
  const RoomCreated({required this.roomCode, required this.hostToken, required this.sessionToken, required this.playerId});

  final String roomCode;
  final String hostToken;
  final String sessionToken;
  final String playerId;
}

/// You are in.
@MappableClass(discriminatorValue: 'JOINED')
class Joined extends ServerMessage with JoinedMappable {
  const Joined({required this.playerId, required this.role, this.seatIndex, required this.sessionToken});

  final String playerId;
  final Role role;
  final int? seatIndex;
  final String sessionToken;
}

/// Full state, sent after joining or resuming.
@MappableClass(discriminatorValue: 'SNAPSHOT')
class Snapshot extends ServerMessage with SnapshotMappable {
  const Snapshot({required this.stateVersion, required this.serverTime, required this.nextActionSeq, required this.view});

  final int stateVersion;

  /// Server clock in ms; compute the offset to count down `turnDeadlineMs`.
  final int serverTime;
  final int nextActionSeq;
  final RoomView view;
}

/// The state changed.
@MappableClass(discriminatorValue: 'STATE_UPDATE')
class StateUpdate extends ServerMessage with StateUpdateMappable {
  const StateUpdate({required this.stateVersion, required this.view});

  final int stateVersion;
  final RoomView view;
}

/// Sent only to the player on turn.
@MappableClass(discriminatorValue: 'TURN_PROMPT')
class TurnPrompt extends ServerMessage with TurnPromptMappable {
  const TurnPrompt({
    required this.playerId,
    required this.seatIndex,
    this.turnDeadlineMs,
    required this.nextActionSeq,
    required this.legal,
  });

  final String playerId;
  final int seatIndex;
  final int? turnDeadlineMs;
  final int nextActionSeq;
  final LegalActions legal;
}

/// Somebody acted (also timeouts, [auto] = true).
@MappableClass(discriminatorValue: 'ACTION_PERFORMED')
class ActionPerformed extends ServerMessage with ActionPerformedMappable {
  const ActionPerformed({
    required this.playerId,
    required this.playerName,
    required this.kind,
    required this.amount,
    required this.chipsRemaining,
    required this.allIn,
    required this.auto,
  });

  final String playerId;
  final String playerName;
  final ActionKind kind;
  final int amount;
  final int chipsRemaining;
  final bool allIn;
  final bool auto;
}

/// Your `GAME_ACTION` was applied (or was a duplicate).
@MappableClass(discriminatorValue: 'ACK')
class Ack extends ServerMessage with AckMappable {
  const Ack({required this.nextActionSeq, required this.duplicate});

  final int nextActionSeq;
  final bool duplicate;
}

/// A request failed. [details] carries numbers such as `minRaiseTo` for some codes.
@MappableClass(discriminatorValue: 'ERROR')
class ErrorMessage extends ServerMessage with ErrorMessageMappable {
  const ErrorMessage({required this.code, required this.message, this.details});

  final ErrorCode code;
  final String message;
  final Map<String, dynamic>? details;
}

/// A seat went offline or came back.
@MappableClass(discriminatorValue: 'PLAYER_CONNECTION')
class PlayerConnection extends ServerMessage with PlayerConnectionMappable {
  const PlayerConnection({required this.seatIndex, required this.playerId, required this.isConnected});

  final int seatIndex;
  final String playerId;
  final bool isConnected;
}

/// The host froze the game.
@MappableClass(discriminatorValue: 'GAME_PAUSED')
class GamePaused extends ServerMessage with GamePausedMappable {
  const GamePaused({required this.pausedBy, this.reason});

  final String pausedBy;
  final String? reason;
}

/// The host resumed the game.
@MappableClass(discriminatorValue: 'GAME_RESUMED')
class GameResumed extends ServerMessage with GameResumedMappable {
  const GameResumed({required this.resumedBy, this.turnDeadlineMs});

  final String resumedBy;
  final int? turnDeadlineMs;
}

/// The room's task crashed and was rebuilt from disk.
@MappableClass(discriminatorValue: 'ROOM_RECOVERED')
class RoomRecovered extends ServerMessage with RoomRecoveredMappable {
  const RoomRecovered({required this.reason});

  final String reason;
}

/// The room crashed too often and is frozen.
@MappableClass(discriminatorValue: 'ROOM_CRASHED')
class RoomCrashed extends ServerMessage with RoomCrashedMappable {
  const RoomCrashed({required this.reason});

  final String reason;
}

/// The room was idle too long; the socket closes after this.
@MappableClass(discriminatorValue: 'ROOM_EXPIRED')
class RoomExpired extends ServerMessage with RoomExpiredMappable {
  const RoomExpired();
}

/// Answer to `PING`.
@MappableClass(discriminatorValue: 'PONG')
class Pong extends ServerMessage with PongMappable {
  const Pong({required this.t});

  final int t;
}

/// A player was flagged away.
@MappableClass(discriminatorValue: 'PLAYER_AWAY')
class PlayerAway extends ServerMessage with PlayerAwayMappable {
  const PlayerAway({required this.playerId, required this.seatIndex});

  final String playerId;
  final int seatIndex;
}

/// A presence check about [subjectPlayerId] started.
@MappableClass(discriminatorValue: 'PRESENCE_CHECK')
class PresenceCheck extends ServerMessage with PresenceCheckMappable {
  const PresenceCheck({required this.subjectPlayerId, required this.subjectName, required this.deadlineMs});

  final String subjectPlayerId;
  final String subjectName;
  final int deadlineMs;
}

/// A presence check ended.
@MappableClass(discriminatorValue: 'PRESENCE_RESOLVED')
class PresenceResolved extends ServerMessage with PresenceResolvedMappable {
  const PresenceResolved({required this.subjectPlayerId, required this.removed});

  final String subjectPlayerId;
  final bool removed;
}
