import 'package:flutter/foundation.dart';

/// Where the link to the server stands.
enum LinkPhase {
  /// Not started.
  idle,

  /// Opening the socket or waiting for the first `SNAPSHOT`.
  connecting,

  /// Authenticated and receiving state.
  live,

  /// The socket was lost; waiting for the next attempt.
  waiting,

  /// Gave up (see [LinkState.failure]); the user must act.
  failed,

  /// Closed on purpose.
  closed,
}

/// Why the link gave up (docs/API_AND_EVENTS.md section 6).
enum LinkFailure {
  /// The room does not exist (any more).
  roomGone,

  /// The stored session was refused.
  invalidSession,

  /// Another device took over the seat.
  superseded,

  /// The room crashed too often and is frozen.
  roomCrashed,

  /// The room expired.
  roomExpired,

  /// The app and the server speak different protocol versions.
  versionMismatch,

  /// The server refused too many attempts from this address.
  rateLimited,

  /// The room needs a feature this app lacks (virtual cards): update the app.
  updateRequired,

  /// The server refused the join and the socket was closed (full room, ...).
  refused,
}

/// Snapshot of the link, for banners and buttons.
@immutable
class LinkState {
  const LinkState({
    this.phase = LinkPhase.idle,
    this.attempt = 0,
    this.nextAttemptAt,
    this.downSince,
    this.failure,
    this.message,
  });

  final LinkPhase phase;

  /// Reconnect attempts since the link was last live.
  final int attempt;

  /// When the next attempt starts, while [phase] is [LinkPhase.waiting].
  final DateTime? nextAttemptAt;

  /// When the link was lost (kept across attempts), for the "still trying" prompt.
  final DateTime? downSince;

  final LinkFailure? failure;

  /// Server text for a failure, if any.
  final String? message;

  bool get isLive => phase == LinkPhase.live;

  /// Whether the UI should show "Reconnecting" and disable actions.
  bool get isReconnecting => phase == LinkPhase.connecting && downSince != null || phase == LinkPhase.waiting;

  /// After 30 s without a link the UI offers a manual retry and "Leave room".
  bool stillTrying(DateTime now) => downSince != null && now.difference(downSince!) >= const Duration(seconds: 30);

  @override
  bool operator ==(Object other) =>
      other is LinkState &&
      other.phase == phase &&
      other.attempt == attempt &&
      other.nextAttemptAt == nextAttemptAt &&
      other.downSince == downSince &&
      other.failure == failure &&
      other.message == message;

  @override
  int get hashCode => Object.hash(phase, attempt, nextAttemptAt, downSince, failure, message);

  @override
  String toString() => 'LinkState($phase, attempt $attempt, $failure)';
}
