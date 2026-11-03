import 'package:dart_mappable/dart_mappable.dart';

import 'wire_case.dart';

part 'error_code.mapper.dart';

/// Machine-readable reason in an `ERROR` message (`docs/API_AND_EVENTS.md` section 6).
///
/// A code this client does not know decodes to [unknown] instead of failing, so a newer server
/// can add codes without breaking an older app.
@MappableEnum(caseStyle: screamingSnake, defaultValue: ErrorCode.unknown)
enum ErrorCode {
  versionMismatch,
  unknownMessage,
  badRequest,
  notAuthenticated,
  invalidSession,
  roomNotFound,
  roomFull,
  spectatorsFull,
  seatOccupied,
  alreadySeated,
  nameInvalid,
  notYourTurn,
  invalidCheck,
  invalidAction,
  belowMinRaise,
  bettingNotReopened,
  insufficientFunds,
  invalidAmount,
  outOfSync,
  hostOnlyAction,
  handNotInProgress,
  handInProgress,
  gamePaused,
  notPaused,
  notEnoughPlayers,
  unknownPlayer,
  nothingToUndo,
  invalidAllocation,
  illegalState,
  noPresenceCheck,
  rateLimited,
  superseded,
  roomCrashed,
  internalError,

  /// Any code added by a newer server.
  unknown,
}
