import 'package:poker_protocol/poker_protocol.dart';

/// Table settings a host starts with. Only a starting point: the server validates every value
/// (no poker rules in the app).
const RoomConfig defaultRoomConfig = RoomConfig(
  startingChips: 1000,
  smallBlind: 5,
  bigBlind: 10,
  ante: 0,
  isTournament: false,
  blindLevelMinutes: 10,
  turnTimeLimitSeconds: 30,
);

/// The table of a single-player game: a freeze-out with 75 big blinds each, virtual cards, no
/// turn timer (nobody waits for the person playing) and blinds that rise every
/// [SoloConfig.ladderHands] hands. Only a starting point: the server validates it.
RoomConfig soloRoomConfig(SoloConfig solo) => RoomConfig(
  startingChips: 1500,
  smallBlind: 10,
  bigBlind: 20,
  ante: 0,
  isTournament: true,
  blindLevelMinutes: 10,
  turnTimeLimitSeconds: 0,
  cardMode: CardMode.virtual,
  solo: solo,
);

/// How long a single-player game lasts, as the number of hands played at each blind level.
enum SoloLength {
  quick(6),
  standard(8),
  long(12)
  ;

  const SoloLength(this.ladderHands);

  final int ladderHands;

  /// The length that matches a saved number of hands per level; anything else is [standard].
  static SoloLength fromHands(int hands) => values.firstWhere((l) => l.ladderHands == hands, orElse: () => standard);
}

/// Fewest and most computer players the setup offers (the server accepts the same range).
const int minSoloBots = 1;
const int maxSoloBots = 9;

/// A room created by the embedded server, with the host's credentials.
class HostedRoom {
  const HostedRoom({
    required this.roomCode,
    required this.playerId,
    required this.sessionToken,
    required this.hostToken,
    required this.port,
  });

  final String roomCode;
  final String playerId;
  final String sessionToken;

  /// Proof that this device is the host. Never show it; keep it in the token store.
  final String hostToken;

  /// Port the embedded server listens on.
  final int port;
}

/// Why hosting failed.
enum HostFailure {
  /// This platform cannot host (web), or the native library failed to load.
  unavailable,

  /// The port is in use.
  portBusy,

  /// The server could not store its files.
  storage,

  /// The server refused the room; see [HostException.code].
  refused,

  /// The embedded server hit an internal error and was stopped.
  crashed,

  /// Anything else.
  unknown,
}

/// A failed hosting call. Feature code catches this and nothing platform-specific.
class HostException implements Exception {
  const HostException(this.failure, this.message, {this.code});

  final HostFailure failure;
  final String message;

  /// Wire error code (for example `ROOM_FULL`) when [failure] is [HostFailure.refused].
  final String? code;

  @override
  String toString() => 'HostException(${failure.name}): $message';
}

/// What the app keeps between launches so it can re-attach to a room.
class StoredSession {
  const StoredSession({
    required this.serverUri,
    required this.roomCode,
    required this.sessionToken,
    this.hostToken,
    this.playerId,
    this.soloBots,
    this.soloSkill,
  });

  /// `ws://host:port/v1/ws` of the server that holds the room.
  final String serverUri;
  final String roomCode;
  final String sessionToken;
  final String? hostToken;
  final String? playerId;

  /// Single-player games: how many opponents the game started with and at which skill (the wire
  /// name), so the record of the table kind can be kept after the app was closed.
  final int? soloBots;
  final String? soloSkill;

  bool get isHost => hostToken != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'serverUri': serverUri,
    'roomCode': roomCode,
    'sessionToken': sessionToken,
    if (hostToken != null) 'hostToken': hostToken,
    if (playerId != null) 'playerId': playerId,
    if (soloBots != null) 'soloBots': soloBots,
    if (soloSkill != null) 'soloSkill': soloSkill,
  };

  static StoredSession? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final serverUri = json['serverUri'];
    final roomCode = json['roomCode'];
    final sessionToken = json['sessionToken'];
    if (serverUri is! String || roomCode is! String || sessionToken is! String) return null;
    final hostToken = json['hostToken'];
    final playerId = json['playerId'];
    final soloBots = json['soloBots'];
    final soloSkill = json['soloSkill'];
    return StoredSession(
      serverUri: serverUri,
      roomCode: roomCode,
      sessionToken: sessionToken,
      hostToken: hostToken is String ? hostToken : null,
      playerId: playerId is String ? playerId : null,
      soloBots: soloBots is int ? soloBots : null,
      soloSkill: soloSkill is String ? soloSkill : null,
    );
  }
}
