// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'error_code.dart';

class ErrorCodeMapper extends EnumMapper<ErrorCode> {
  ErrorCodeMapper._();

  static ErrorCodeMapper? _instance;
  static ErrorCodeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ErrorCodeMapper._());
    }
    return _instance!;
  }

  static ErrorCode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ErrorCode decode(dynamic value) {
    switch (value) {
      case r'VERSION_MISMATCH':
        return ErrorCode.versionMismatch;
      case r'UNKNOWN_MESSAGE':
        return ErrorCode.unknownMessage;
      case r'BAD_REQUEST':
        return ErrorCode.badRequest;
      case r'NOT_AUTHENTICATED':
        return ErrorCode.notAuthenticated;
      case r'INVALID_SESSION':
        return ErrorCode.invalidSession;
      case r'ROOM_NOT_FOUND':
        return ErrorCode.roomNotFound;
      case r'ROOM_FULL':
        return ErrorCode.roomFull;
      case r'SPECTATORS_FULL':
        return ErrorCode.spectatorsFull;
      case r'SEAT_OCCUPIED':
        return ErrorCode.seatOccupied;
      case r'ALREADY_SEATED':
        return ErrorCode.alreadySeated;
      case r'NAME_INVALID':
        return ErrorCode.nameInvalid;
      case r'NOT_YOUR_TURN':
        return ErrorCode.notYourTurn;
      case r'INVALID_CHECK':
        return ErrorCode.invalidCheck;
      case r'INVALID_ACTION':
        return ErrorCode.invalidAction;
      case r'BELOW_MIN_RAISE':
        return ErrorCode.belowMinRaise;
      case r'BETTING_NOT_REOPENED':
        return ErrorCode.bettingNotReopened;
      case r'INSUFFICIENT_FUNDS':
        return ErrorCode.insufficientFunds;
      case r'INVALID_AMOUNT':
        return ErrorCode.invalidAmount;
      case r'OUT_OF_SYNC':
        return ErrorCode.outOfSync;
      case r'HOST_ONLY_ACTION':
        return ErrorCode.hostOnlyAction;
      case r'HAND_NOT_IN_PROGRESS':
        return ErrorCode.handNotInProgress;
      case r'HAND_IN_PROGRESS':
        return ErrorCode.handInProgress;
      case r'GAME_PAUSED':
        return ErrorCode.gamePaused;
      case r'NOT_PAUSED':
        return ErrorCode.notPaused;
      case r'NOT_ENOUGH_PLAYERS':
        return ErrorCode.notEnoughPlayers;
      case r'UNKNOWN_PLAYER':
        return ErrorCode.unknownPlayer;
      case r'NOTHING_TO_UNDO':
        return ErrorCode.nothingToUndo;
      case r'INVALID_ALLOCATION':
        return ErrorCode.invalidAllocation;
      case r'ILLEGAL_STATE':
        return ErrorCode.illegalState;
      case r'NO_PRESENCE_CHECK':
        return ErrorCode.noPresenceCheck;
      case r'RATE_LIMITED':
        return ErrorCode.rateLimited;
      case r'SUPERSEDED':
        return ErrorCode.superseded;
      case r'ROOM_CRASHED':
        return ErrorCode.roomCrashed;
      case r'INTERNAL_ERROR':
        return ErrorCode.internalError;
      case r'UPDATE_REQUIRED':
        return ErrorCode.updateRequired;
      case r'UNKNOWN':
        return ErrorCode.unknown;
      default:
        return ErrorCode.values[35];
    }
  }

  @override
  dynamic encode(ErrorCode self) {
    switch (self) {
      case ErrorCode.versionMismatch:
        return r'VERSION_MISMATCH';
      case ErrorCode.unknownMessage:
        return r'UNKNOWN_MESSAGE';
      case ErrorCode.badRequest:
        return r'BAD_REQUEST';
      case ErrorCode.notAuthenticated:
        return r'NOT_AUTHENTICATED';
      case ErrorCode.invalidSession:
        return r'INVALID_SESSION';
      case ErrorCode.roomNotFound:
        return r'ROOM_NOT_FOUND';
      case ErrorCode.roomFull:
        return r'ROOM_FULL';
      case ErrorCode.spectatorsFull:
        return r'SPECTATORS_FULL';
      case ErrorCode.seatOccupied:
        return r'SEAT_OCCUPIED';
      case ErrorCode.alreadySeated:
        return r'ALREADY_SEATED';
      case ErrorCode.nameInvalid:
        return r'NAME_INVALID';
      case ErrorCode.notYourTurn:
        return r'NOT_YOUR_TURN';
      case ErrorCode.invalidCheck:
        return r'INVALID_CHECK';
      case ErrorCode.invalidAction:
        return r'INVALID_ACTION';
      case ErrorCode.belowMinRaise:
        return r'BELOW_MIN_RAISE';
      case ErrorCode.bettingNotReopened:
        return r'BETTING_NOT_REOPENED';
      case ErrorCode.insufficientFunds:
        return r'INSUFFICIENT_FUNDS';
      case ErrorCode.invalidAmount:
        return r'INVALID_AMOUNT';
      case ErrorCode.outOfSync:
        return r'OUT_OF_SYNC';
      case ErrorCode.hostOnlyAction:
        return r'HOST_ONLY_ACTION';
      case ErrorCode.handNotInProgress:
        return r'HAND_NOT_IN_PROGRESS';
      case ErrorCode.handInProgress:
        return r'HAND_IN_PROGRESS';
      case ErrorCode.gamePaused:
        return r'GAME_PAUSED';
      case ErrorCode.notPaused:
        return r'NOT_PAUSED';
      case ErrorCode.notEnoughPlayers:
        return r'NOT_ENOUGH_PLAYERS';
      case ErrorCode.unknownPlayer:
        return r'UNKNOWN_PLAYER';
      case ErrorCode.nothingToUndo:
        return r'NOTHING_TO_UNDO';
      case ErrorCode.invalidAllocation:
        return r'INVALID_ALLOCATION';
      case ErrorCode.illegalState:
        return r'ILLEGAL_STATE';
      case ErrorCode.noPresenceCheck:
        return r'NO_PRESENCE_CHECK';
      case ErrorCode.rateLimited:
        return r'RATE_LIMITED';
      case ErrorCode.superseded:
        return r'SUPERSEDED';
      case ErrorCode.roomCrashed:
        return r'ROOM_CRASHED';
      case ErrorCode.internalError:
        return r'INTERNAL_ERROR';
      case ErrorCode.updateRequired:
        return r'UPDATE_REQUIRED';
      case ErrorCode.unknown:
        return r'UNKNOWN';
    }
  }
}

extension ErrorCodeMapperExtension on ErrorCode {
  String toValue() {
    ErrorCodeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ErrorCode>(this) as String;
  }
}

