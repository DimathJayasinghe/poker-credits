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

  // Navigation
  static const String back = 'Back';
  static const String close = 'Close';
  static const String phase = 'Phase';
  static const String connection = 'Connection';
  static const String live = 'Live';
  static const String you = 'You';
  static const String gameSettings = 'Game settings';
  static const String navPlay = 'Play';
  static const String navSettings = 'Settings';
  static const String navGuide = 'Guide';
  static const String switchTheme = 'Switch light and dark';

  // Play (home)
  static const String hostRowCaption = 'Start a table on this device. Others join over Wi-Fi.';
  static const String joinRowCaption = 'Type the room code the host shows you.';

  // Settings
  static const String settingsTitle = 'Settings';
  static const String sectionAppearance = 'Appearance';
  static const String themeLabel = 'Theme';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String textureLabel = 'Paper texture';
  static const String textureCaption = 'Fine grain behind the screens. Turn off for flat colour.';
  static const String sectionTable = 'Table';
  static const String soundLabel = 'Sound';
  static const String soundCaption = 'A beep when it is your turn.';
  static const String vibrationLabel = 'Vibration';
  static const String vibrationCaption = 'A buzz when it is your turn.';
  static const String keepAwakeLabel = 'Keep screen on';
  static const String keepAwakeCaption = 'While a game is open, so the screen never dims.';
  static const String sectionYou = 'You';
  static const String defaultNameLabel = 'Default name';
  static const String defaultNameHint = 'Filled in when you join a game';
  static const String sectionData = 'Data';
  static const String forgetGame = 'Forget saved game';
  static const String forgetGameCaption = 'Stop offering to go back to the last game on this device.';
  static const String forgetGameNothing = 'No saved game on this device.';
  static const String forgetTitle = 'Forget the saved game?';
  static const String forgetBody = 'You will not be able to go back to it from this device. Other players are not affected.';
  static const String forgetConfirm = 'Forget';
  static const String forgetDone = 'Saved game forgotten.';
  static const String sectionAbout = 'About';
  static const String versionLabel = 'Version';
  static const String protocolLabel = 'Protocol';
  static const String licences = 'Open-source licences';

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
  static const String orType = 'or type the address';
  static const String joinByCode = 'Others: tap JOIN, type this code';
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
  // Seat order.
  static const String seatsButton = 'Seats';
  static const String seatsTitle = 'Seat order';
  static const String seatsFree = 'Free';
  static const String seatsYou = 'You';
  static const String seatsLocked = 'Seats are locked while a hand is being played. Change them between hands.';
  static const String seatsHostOnly = 'The game has started, so only the host can move people between seats.';
  static const String seatsHintGuest = 'Tap a free seat to move there. Seat 1 is at the bottom of the table screen and the numbers run clockwise.';
  static const String seatsHintHost =
      'Tap a player, then a seat. A free seat moves them there; a taken seat swaps the two. Numbers run clockwise from the bottom of the table screen.';
  static const String seatsPicked = 'Now tap the seat they should take.';
  static const String seatsClockwise = 'Clockwise from seat 1';
  static const String seatsMove = 'Change seat';
  static String seatLabel(int number) => 'Seat $number';
  static String seatsOrderLine(List<String> names) => names.join(' > ');
  static const String lobbyHint = 'Players join with the room code. Press start when everyone is seated.';
  static const String hostingUnavailable = 'Hosting unavailable on this device';

  // Join
  static const String joinGame = 'Join a game';
  static const String joinTitle = 'Join a game';
  static const String joinCode = 'Room code';
  // Open games on the Wi-Fi.
  static const String nearbyTitle = 'Games on this Wi-Fi';
  static const String nearbyLooking = 'Looking for open games';
  static const String nearbyNone = 'No open games found. Ask the host for the room code, or search again.';
  static const String nearbyAgain = 'Search again';
  static const String nearbyPick = 'Tap a game, then your name, then join.';
  static String nearbySeats(String code, int count, int max) => 'Room $code, $count of $max seats taken';
  static const String searchingHost = 'Looking for the game on this Wi-Fi';
  static const String hostNotFound =
      'No game with that code found on this Wi-Fi. Check the code, and that you are on the same Wi-Fi as the host (not a guest network). Or enter the host address';
  static const String useAddress = 'Enter host address instead';
  static const String useCode = 'Find by code instead';
  static const String joinAddress = 'Host address (192.168.1.5 or 192.168.1.5:7878)';
  static const String joinName = 'Your name';
  static const String joinButton = 'Join';
  static const String watchButton = 'Watch only';
  static const String scanQr = 'Scan QR code';
  static const String scanTitle = 'Scan the host\'s code';
  static const String scanHint = 'Point the camera at the QR code on the table screen.';
  static const String scanNotOurs = 'That is not a Poker Credits code';
  static const String scanCameraFailed = 'The camera cannot be used. Type the address instead.';
  static const String codeInvalid = 'The room code has 4 letters or digits';
  static const String addressInvalid = 'Enter the host address, for example 192.168.1.5';
  static const String connecting = 'Connecting';
  static const String cannotReach = 'Cannot reach the host yet. Still trying';
  static const String resumeGame = 'Back to my game';
  static const String errRoomFull = 'The table is full. You can still watch';
  static const String errSpectatorsFull = 'The room cannot take more watchers';
  static const String errNameTaken = 'That seat or name is taken. Change your name or try again';
  static const String errSeatOccupied = 'That seat is taken';
  static const String errAlreadySeated = 'You already have a seat';
  static const String errNameInvalid = 'Use 1 to 20 letters, digits, spaces, - or _';
  static const String errRoomNotFound = 'No game with that code on this address';
  static const String errHandInProgress = 'A hand is being played. You join the next one';
  static const String errGeneric = 'The server said no';

  // Player controller
  static const String yourTurn = 'Your turn';
  static const String waitingFor = 'Waiting for';
  static const String waitingForHand = 'Waiting for the next hand';
  static const String yourStack = 'Your chips';
  static const String yourBet = 'Your bet';
  static const String fold = 'Fold';
  static const String check = 'Check';
  static const String call = 'Call';
  static const String raise = 'Raise';
  static const String raiseTo = 'Raise to';
  static const String allInAction = 'All-in';
  static const String min = 'Min';
  static const String max = 'All-in';
  static const String topUp = 'Top up';
  static const String topUpTitle = 'Ask the host for chips';
  static const String topUpAsk = 'Ask';
  static const String topUpPending = 'Top-up requested';
  static const String topUpApproved = 'Top-up approved: you get it before the next hand';
  static const String sitOut = 'Sit out';
  static const String imBack = 'I\'m back';
  static const String leave = 'Leave';
  static const String leaveTable = 'Leave table';
  static const String leaveTableTitle = 'Leave the table?';
  static const String leaveTableBody = 'You fold if a hand is running, and your chips leave with you.';
  static const String youAreOut = 'You are sitting out the next hands';
  static const String watchingOnly = 'You are watching';
  static const String noSeat = 'You do not have a seat';
  static const String stillHere = 'Still here?';
  static const String actionRejected = 'The server did not accept that';
  static const String turnLeft = 'left';
  static const String amount = 'Amount';

  // Guide (docs/UI_DESIGN.md section 5); the teaching text itself is in util/guide_content.dart.
  static const String guideTitle = 'Guide';
  static const String guideIntro = 'New to poker? Start here.';
  static const String guideIntroBody = 'Everything you need for a game night with real cards, in plain words. No account, no internet needed.';
  static const String guideSectionNight = 'How a night works';
  static const String guideSectionHands = 'Hand rankings';
  static const String guideSectionFlow = 'How a hand plays';
  static const String guideSectionWords = 'Words on the buttons';
  static const String guideSectionRules = 'Rules the app keeps';
  static const String guideSectionDrops = 'If the connection drops';
  static const String guideSectionManners = 'Table manners';
  static const String guideHandsIntro = 'Strongest first. Make the best five cards from your two and the five shared ones.';
  static const String guideJump = 'Jump to';
  static const String guideHelp = 'Guide';
  static const String guideOpen = 'Open the guide';
  static const String guideOpenFull = 'Open the full guide';
  static const String guideQuickTitle = 'Quick guide';
  static const String guideTabHands = 'Hands';
  static const String guideTabHand = 'A hand';
  static const String guideTabWords = 'Words';
  static const String guideTabRules = 'Rules';
  static const String guideTabDrops = 'Drops';
  static const String guideRankLabel = 'Rank';
}
