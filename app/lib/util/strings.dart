/// All user-visible strings live here so localisation can be added later mechanically.
/// Widgets uppercase presentation text themselves (docs/UI_DESIGN.md section 6).
abstract final class Strings {
  static const String appName = 'Poker Credits';
  static const String tagline = 'Chips and pots for physical cards';
  static const String initErrorTitle = 'Startup failed';
  static const String initErrorHint = 'Copy this report when asking for help.';
  static const String copy = 'Copy report';
  static const String copied = 'Copied';
  static const String hostGame = 'Host a game';
  static const String hostUnsupported = 'Hosting is not available on this platform';
  static const String comingSoon = 'Coming in the next phases';

  // Host setup
  static const String hostTitle = 'Host a game';
  static const String hostName = 'Your name';
  static const String startingChips = 'Starting chips';
  static const String smallBlind = 'Small blind';
  static const String bigBlind = 'Big blind';
  static const String turnSeconds = 'Seconds per turn (0 = no timer)';
  static const String startHosting = 'Start hosting';
  static const String starting = 'Starting the server...';
  static const String hostFailedPort = 'The port is busy. Close the other app or game and try again.';
  static const String hostFailedStorage = 'The game files cannot be saved on this device.';
  static const String hostFailedCrashed = 'The embedded server hit an internal error. Try again.';
  static const String hostFailedRefused = 'The server refused these settings.';
  static const String hostFailedUnknown = 'Hosting failed.';
  static const String resumeHosting = 'Resume hosted game';
  static const String nameInvalid = 'Use 1 to 20 letters, digits, spaces, - or _';
  static const String numberInvalid = 'Enter a whole number';

  // Table
  static const String room = 'Room';
  static const String hand = 'Hand';
  static const String pot = 'Pot';
  static const String sidePot = 'Side';
  static const String acting = 'Acting';
  static const String waitingForPlayers = 'Waiting for players';
  static const String joinWith = 'Join with the app';
  static const String orType = 'or type';
  static const String roomCode = 'Room code';
  static const String players = 'Players';
  static const String watching = 'Watching';
  static const String noActionsYet = 'No actions yet';

  // Seats
  static const String dealer = 'D';
  static const String smallBlindTag = 'SB';
  static const String bigBlindTag = 'BB';
  static const String allIn = 'All-in';
  static const String folded = 'Folded';
  static const String sittingOut = 'Away';
  static const String offline = 'Offline';
  static const String autoTag = 'Auto';
  static const String bet = 'Bet';

  // Host controls
  static const String startHand = 'Start hand';
  static const String beginShowdown = 'Begin showdown';
  static const String resolveShowdown = 'Pick winners';
  static const String confirmWinners = 'Confirm winners';
  static const String pause = 'Pause';
  static const String resume = 'Resume';
  static const String undo = 'Undo';
  static const String endGame = 'End game';
  static const String endGameTitle = 'End the game?';
  static const String endGameBody = 'Everyone is disconnected and the room is closed.';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String kick = 'Remove player';
  static const String kickTitle = 'Remove this player?';
  static const String approve = 'Approve';
  static const String rebuyRequest = 'wants a top-up of';
  static const String chooseWinners = 'Choose the winner of each pot';
  static const String potLabel = 'Pot';
  static const String noEligible = 'Nobody can win this pot';

  // Link
  static const String reconnecting = 'Reconnecting';
  static const String stillTrying = 'Still trying to reach the server';
  static const String retry = 'Retry';
  static const String leaveRoom = 'Leave room';
  static const String gamePaused = 'Game paused';
  static const String linkFailedRoomGone = 'The room no longer exists';
  static const String linkFailedSession = 'Your session expired';
  static const String linkFailedSuperseded = 'You connected from another device';
  static const String linkFailedCrashed = 'The room crashed and was frozen';
  static const String linkFailedExpired = 'The room expired';
  static const String linkFailedVersion = 'Update the app: it speaks a different protocol version';
  static const String linkFailedRate = 'Too many attempts from this address. Wait a few minutes';
  static const String linkFailedRefused = 'The server refused the connection';
  static const String roomEndedTitle = 'Room closed';
  static const String presenceCheck = 'Is this player still here?';
  static const String presenceHint = 'Players are asked first; your answer is final.';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String lobbyHint = 'Players join with the room code. Press start when everyone is seated.';
  static const String hostingUnavailable = 'Hosting unavailable on this device';
}
