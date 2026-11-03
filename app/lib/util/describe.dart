import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// One ticker line such as `BOB RAISES TO 60`. Text only; no rules.
String describeAction(ActionPerformed a) {
  final name = a.playerName;
  final base = switch (a.kind) {
    ActionKind.fold => '$name folds',
    ActionKind.check => '$name checks',
    ActionKind.call => '$name calls ${a.amount}',
    ActionKind.bet => '$name bets ${a.amount}',
    ActionKind.raise => '$name raises to ${a.amount}',
    ActionKind.unknown => '$name acts',
  };
  final allIn = a.allIn ? ' (${Strings.allIn})' : '';
  final auto = a.auto ? ' (${Strings.autoTag})' : '';
  return '$base$allIn$auto';
}

/// Label for the top bar.
String phaseLabel(WirePhase phase) => switch (phase) {
  WirePhase.lobby => 'Lobby',
  WirePhase.preFlop => 'Pre-flop',
  WirePhase.flop => 'Flop',
  WirePhase.turn => 'Turn',
  WirePhase.river => 'River',
  WirePhase.allInRunout => 'All-in',
  WirePhase.showdown => 'Showdown',
  WirePhase.nextHandPrep => 'Between hands',
  WirePhase.paused => 'Paused',
};

/// `m:ss` for a countdown.
String clock(int milliseconds) {
  final total = (milliseconds / 1000).ceil();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Words for a link that gave up.
String linkFailureText(LinkFailure failure) => switch (failure) {
  LinkFailure.roomGone => Strings.linkFailedRoomGone,
  LinkFailure.invalidSession => Strings.linkFailedSession,
  LinkFailure.superseded => Strings.linkFailedSuperseded,
  LinkFailure.roomCrashed => Strings.linkFailedCrashed,
  LinkFailure.roomExpired => Strings.linkFailedExpired,
  LinkFailure.versionMismatch => Strings.linkFailedVersion,
  LinkFailure.rateLimited => Strings.linkFailedRate,
  LinkFailure.refused => Strings.linkFailedRefused,
};

/// Words for a server error shown while joining or acting.
String errorText(ErrorCode code) => switch (code) {
  ErrorCode.roomFull => Strings.errRoomFull,
  ErrorCode.spectatorsFull => Strings.errSpectatorsFull,
  ErrorCode.seatOccupied => Strings.errSeatOccupied,
  ErrorCode.alreadySeated => Strings.errAlreadySeated,
  ErrorCode.nameInvalid => Strings.errNameInvalid,
  ErrorCode.roomNotFound => Strings.errRoomNotFound,
  ErrorCode.handInProgress => Strings.errHandInProgress,
  _ => Strings.errGeneric,
};
