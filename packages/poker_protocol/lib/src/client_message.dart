import 'package:dart_mappable/dart_mappable.dart';

import 'wire_case.dart';

import 'player_action.dart';
import 'room_config.dart';

part 'client_message.mapper.dart';

/// Winners of one pot, sent by the host in [ResolveShowdown].
@MappableClass()
class WireAllocation with WireAllocationMappable {
  const WireAllocation({required this.potIndex, required this.winnerPlayerIds});

  /// Pot position, 0 = main pot.
  final int potIndex;
  final List<String> winnerPlayerIds;
}

/// Everything a client may send. The `type` field picks the subclass.
@MappableClass(discriminatorKey: 'type', caseStyle: screamingSnake)
sealed class ClientMessage with ClientMessageMappable {
  const ClientMessage();
}

/// Cloud mode: create a room.
@MappableClass(discriminatorValue: 'CREATE_ROOM')
class CreateRoom extends ClientMessage with CreateRoomMappable {
  const CreateRoom({required this.hostName, required this.config});

  final String hostName;
  final RoomConfig config;
}

/// Take a seat or watch.
@MappableClass(discriminatorValue: 'JOIN_ROOM')
class JoinRoom extends ClientMessage with JoinRoomMappable {
  const JoinRoom({required this.roomCode, required this.name, this.seatIndex, this.spectator = false});

  final String roomCode;
  final String name;

  /// Preferred seat; the first free one when absent.
  final int? seatIndex;

  /// Always written, also when false.
  final bool spectator;
}

/// Re-attach after a lost connection.
@MappableClass(discriminatorValue: 'RESUME')
class Resume extends ClientMessage with ResumeMappable {
  const Resume({required this.roomCode, required this.sessionToken, this.lastStateVersion, this.hostToken});

  final String roomCode;
  final String sessionToken;
  final int? lastStateVersion;

  /// Host proof, only for the host.
  final String? hostToken;
}

/// Host: deal the next hand.
@MappableClass(discriminatorValue: 'START_HAND')
class StartHand extends ClientMessage with StartHandMappable {
  const StartHand();
}

/// Player: act on the turn.
@MappableClass(discriminatorValue: 'GAME_ACTION')
class GameAction extends ClientMessage with GameActionMappable {
  const GameAction({required this.actionSeq, required this.action});

  /// The server's last `nextActionSeq`.
  final int actionSeq;
  final PlayerAction action;
}

/// Host: end the all-in run-out.
@MappableClass(discriminatorValue: 'BEGIN_SHOWDOWN')
class BeginShowdown extends ClientMessage with BeginShowdownMappable {
  const BeginShowdown();
}

/// Host: choose the winner of every pot.
@MappableClass(discriminatorValue: 'RESOLVE_SHOWDOWN')
class ResolveShowdown extends ClientMessage with ResolveShowdownMappable {
  const ResolveShowdown({required this.allocations});

  final List<WireAllocation> allocations;
}

/// Host: take back the last action.
@MappableClass(discriminatorValue: 'UNDO')
class Undo extends ClientMessage with UndoMappable {
  const Undo();
}

/// Host: freeze the game.
@MappableClass(discriminatorValue: 'PAUSE')
class Pause extends ClientMessage with PauseMappable {
  const Pause({this.reason});

  final String? reason;
}

/// Host: unfreeze the game.
@MappableClass(discriminatorValue: 'RESUME_GAME')
class ResumeGame extends ClientMessage with ResumeGameMappable {
  const ResumeGame();
}

/// Host: approve a queued top-up.
@MappableClass(discriminatorValue: 'APPROVE_REBUY')
class ApproveRebuy extends ClientMessage with ApproveRebuyMappable {
  const ApproveRebuy({required this.playerId, required this.amount});

  final String playerId;
  final int amount;
}

/// Host: remove a player.
@MappableClass(discriminatorValue: 'KICK')
class Kick extends ClientMessage with KickMappable {
  const Kick({required this.playerId});

  final String playerId;
}

/// Host: change the settings (lobby only).
@MappableClass(discriminatorValue: 'ROOM_CONFIGURE')
class RoomConfigure extends ClientMessage with RoomConfigureMappable {
  const RoomConfigure({required this.config});

  final RoomConfig config;
}

/// Host: close the room.
@MappableClass(discriminatorValue: 'END_GAME')
class EndGame extends ClientMessage with EndGameMappable {
  const EndGame();
}

/// Player: ask for a top-up.
@MappableClass(discriminatorValue: 'REQUEST_REBUY')
class RequestRebuy extends ClientMessage with RequestRebuyMappable {
  const RequestRebuy({required this.amount});

  final int amount;
}

/// Player: skip or rejoin from the next hand.
@MappableClass(discriminatorValue: 'SET_SITTING_OUT')
class SetSittingOut extends ClientMessage with SetSittingOutMappable {
  const SetSittingOut({required this.sittingOut});

  final bool sittingOut;
}

/// Player: fold and leave the table.
@MappableClass(discriminatorValue: 'LEAVE_TABLE')
class LeaveTable extends ClientMessage with LeaveTableMappable {
  const LeaveTable();
}

/// Player: vote in a presence check.
@MappableClass(discriminatorValue: 'PRESENCE_VOTE')
class PresenceVote extends ClientMessage with PresenceVoteMappable {
  const PresenceVote({required this.playerId, required this.stillPlaying});

  final String playerId;
  final bool stillPlaying;
}

/// Player: "I am still here" (answer to a presence check about oneself).
@MappableClass(discriminatorValue: 'PRESENCE_ACK')
class PresenceAck extends ClientMessage with PresenceAckMappable {
  const PresenceAck();
}

/// Keep-alive and latency probe; the server answers `PONG` with the same [t].
@MappableClass(discriminatorValue: 'PING')
class Ping extends ClientMessage with PingMappable {
  const Ping({required this.t});

  final int t;
}
