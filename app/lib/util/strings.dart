/// All user-visible strings live here so localisation can be added later mechanically.
/// Widgets uppercase presentation text themselves (docs/UI_DESIGN.md section 6).
abstract final class Strings {
  static const String appName = 'Poker Credits';
  static const String tagline = 'Chips and pots, with real or in-app cards';
  static const String initErrorTitle = 'Startup failed';
  static const String initErrorHint = 'Copy this report when asking for help.';
  static const String initErrorHintRelease =
      'Something went wrong while starting. Quote this ID when asking for help. The technical details stay on this device unless you copy them.';
  static const String initErrorIdHeader = 'Error ID';
  static const String initErrorIdLabel = 'Error ID';
  static const String copyTechnical = 'Copy technical details';
  static const String copy = 'Copy report';
  static const String copied = 'Copied';
  static const String hostGame = 'Host a game';
  static const String hostUnsupported = 'Hosting is not available on this platform';
  static const String comingSoon = 'Coming in the next phases';

  // Navigation
  static const String back = 'Back';
  static const String close = 'Close';
  static const String increase = 'Increase';
  static const String decrease = 'Decrease';
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
  static const String playAlone = 'Play alone';
  static const String playAloneCaption = 'Against computer players. No network needed.';
  static const String resumeSolo = 'Resume solo game';

  // Play alone (setup)
  static const String soloTitle = 'Play alone';
  static const String soloOpponents = 'Opponents';
  static const String soloSkill = 'Skill';
  static const String skillEasy = 'Easy';
  static const String skillNormal = 'Normal';
  static const String skillHard = 'Hard';
  static const String skillEasyCaption = 'Plays by instinct.';
  static const String skillNormalCaption = 'Reads the table.';
  static const String skillHardCaption = 'Reads you and adapts.';
  static const String soloLength = 'Game length';
  static const String lengthQuick = 'Quick';
  static const String lengthStandard = 'Standard';
  static const String lengthLong = 'Long';
  static const String lengthQuickCaption = 'Blinds rise every 6 hands.';
  static const String lengthStandardCaption = 'Blinds rise every 8 hands.';
  static const String lengthLongCaption = 'Blinds rise every 12 hands.';
  static const String soloRules = 'Everyone starts with the same chips. Nobody can buy back in. The last player with chips wins.';
  static const String startSolo = 'Start game';
  static const String soloStarting = 'Starting...';
  static const String soloResumeFailed = 'This game cannot be opened any more.';
  static const String soloRecordNone = 'No finished game at this table yet.';
  static String ordinal(int n) {
    final tens = n % 100;
    if (tens >= 11 && tens <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  /// "Best finish 2nd. Won 1 of 3." for the table kind chosen on the setup screen.
  static String soloRecordLine(int bestPlace, int wins, int played) => 'Best finish ${ordinal(bestPlace)}. Won $wins of $played.';
  static const String blinds = 'Blinds';
  static const String blindsRise = 'Rise in';
  static const String blindsFinalLevel = 'Final level';
  static String handsCount(int n) => n == 1 ? '1 hand' : '$n hands';
  static String outLine(String name, int place) => '$name is out (${ordinal(place)})';
  static const String headsUp = 'Heads-up';
  static const String soloLeaveTitle = 'Leave the game?';
  static const String soloLeaveBody = 'The game is saved. Resume it from the start screen.';
  static const String soloSaveExit = 'Save and exit';
  static const String keepPlaying = 'Keep playing';
  static const String soloEndTitle = 'End this game?';
  static const String soloEndBody = 'You will not be able to resume it.';
  static const String soloEnd = 'End game';
  static const String seeResult = 'See result';
  static const String soloResultTitle = 'Result';
  static const String soloWon = 'You won';
  static const String soloOut = 'You are out';
  static const String soloOutOf = 'of';
  static const String soloStatHands = 'Hands played';
  static const String soloStatWon = 'Hands won';
  static const String soloStatBiggest = 'Biggest win';
  static const String soloStatBest = 'Best hand';
  static const String soloKnockout = 'The hand that decided it';
  static const String playAgain = 'Play again';
  static const String goHome = 'Home';
  static const String soloFailedUnavailable = 'Playing alone is not available on this device.';
  static const String soloFailedStorage = 'The game files cannot be saved on this device.';
  static const String soloFailedUnknown = 'The game could not start. Try again.';

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
  static const String sectionCards = 'Cards';
  static const String fourColourLabel = 'Four-colour deck';
  static const String fourColourCaption = 'Clubs green and diamonds blue, so the suits differ by colour as well as shape.';
  static const String cardsFaceUpLabel = 'Show my cards at once';
  static const String cardsFaceUpCaption = 'Off: your cards stay face down until you tap them, so nobody beside you sees them.';
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
  static const String sectionHelp = 'Help';
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
  static const String thinking = 'Thinking';
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
  static const String linkFailedUpdate = 'This room uses virtual cards. Update the app to join';
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
  static String nearbySeats(String code, int count, int max, {bool virtual = false}) =>
      'Room $code, $count of $max seats taken${virtual ? '. Cards in the app' : ''}';
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
  static const String errUpdateRequired = 'This room uses virtual cards. Update the app to join';
  // Cards
  static const String cardBack = 'Face-down card';

  /// In [CardRank] order, lowest first.
  static const List<String> rankNames = <String>[
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Jack',
    'Queen',
    'King',
    'Ace',
  ];

  /// In [CardSuit] order: clubs, diamonds, hearts, spades.
  static const List<String> suitNames = <String>['clubs', 'diamonds', 'hearts', 'spades'];
  static String cardOf(String rank, String suit) => '$rank of $suit';
  static const String handHighCard = 'High card';
  static const String handPair = 'Pair';
  static const String handTwoPair = 'Two pair';
  static const String handThreeOfAKind = 'Three of a kind';
  static const String handStraight = 'Straight';
  static const String handFlush = 'Flush';
  static const String handFullHouse = 'Full house';
  static const String handFourOfAKind = 'Four of a kind';
  static const String handStraightFlush = 'Straight flush';
  static const String opponents = 'Other players';
  static const String hasCards = 'has cards';
  static const String undoVirtualNote = 'Undo works within one betting round. A card that is turned cannot be taken back.';
  static const String winsTag = 'Wins';
  static String potWonBy(String pot, int amount, String who) => '$pot $amount: $who';
  static const String winnerTag = 'Wins';
  static const String youTag = 'You';
  static const String showdownTitle = 'Showdown';
  static const String wonUncontested = 'Everyone else folded';
  static const String mainPot = 'Main pot';
  static String sidePotNumber(int n) => 'Side pot $n';
  static const String noCards = 'No cards';
  static const String yourCards = 'Your cards';
  static const String tapToShow = 'Tap to show your cards';
  static const String tapToHide = 'Tap to hide your cards';
  static const String holdToLook = 'Hold to look at your cards';
  static const String hideCards = 'Hide';
  static const String showCards = 'Look';
  static const String boardLabel = 'Board';
  static const String cardsHiddenSemantics = 'Your cards are hidden';

  // Card mode
  static const String cardsLabel = 'Cards';
  static const String cardsReal = 'Real cards';
  static const String cardsVirtual = 'Cards in the app';
  static const String hostTrustNote = 'This phone deals and holds every hand. Keep it with you and play fair';
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
  static const String guideIntroBody =
      'Everything you need for a game night, with real cards or cards in the app, in plain words. No account and no internet needed. Never played? Start with the lesson below.';
  static const String guideSectionNight = 'How a night works';
  static const String guideSectionHands = 'Hand rankings';
  static const String guideSectionFlow = 'How a hand plays';
  static const String guideSectionWords = 'Words on the buttons';
  static const String guideSectionRules = 'Rules the app keeps';
  static const String guideSectionDrops = 'If the connection drops';
  static const String guideSectionManners = 'Table manners';
  static const String guideSectionCards = 'Cards in the app';
  static const String guideSectionAlone = 'Play alone';
  static const String guideSectionSafety = 'Play safe';
  static const String guideOpenAll = 'Open all';
  static const String guideCloseAll = 'Close all';
  static const String guideSumNight = 'Host, join, play, get paid';
  static const String guideSumHands = 'Ten hands, strongest first, with pictures';
  static const String guideSumFlow = 'From the blinds to the showdown';
  static const String guideSumCards = 'Your two cards, the board, the showdown';
  static const String guideSumAlone = 'Computer players, skill levels, fair play';
  static const String guideSumWords = 'What each button and term means';
  static const String guideSumRules = 'What the app keeps fair for you';
  static const String guideSumDrops = 'Lost your connection? Your seat is safe';
  static const String guideSumSafety = 'Wi-Fi, the deck and your chips';
  static const String guideSumManners = 'A few habits for real cards';
  static const String guideTabCards = 'Cards';
  static const String guideTabAlone = 'Alone';
  static const String guideTabSafety = 'Safety';
  static const String guideSupportRow = 'Enjoying Poker Credits?';
  static const String guideSupportCaption = 'Support the developer';
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

  // Support
  static const String supportRow = 'Support the developer';
  static const String supportRowCaption = 'Star the project, follow, report a bug';
  static const String supportTitle = 'Support';
  static const String supportHeadline = 'Free, open source, made by one person';
  static const String supportBody =
      'Poker Credits is built and maintained by Dimath Jayasinghe. It has no ads, no accounts and no tracking, and it never sends anything outside your own Wi-Fi. If it made your game night better, these three taps help more than you think.';
  static const String supportStar = 'Star on GitHub';
  static const String supportStarCaption = 'Helps other people find the app';
  static const String supportFollow = 'Follow on GitHub';
  static const String supportFollowCaption = 'Get updates and see what comes next';
  static const String supportIssues = 'Report a bug';
  static const String supportIssuesCaption = 'Suggestions are welcome too';
  static const String supportScan = 'Or scan with another phone';
  static const String supportThanks = 'Thank you for playing.';
  static const String linkCopied = 'Link copied. Paste it into your browser.';
  static const String linkFailed = 'Could not open or copy the link. Type the address shown below.';

  // Splash and terms
  static const String splashLoading = 'Dealing';
  static const String splashSkip = 'Tap to skip';
  static const String termsTitle = 'Before you play';
  static const String termsIntro = 'A few things to know before the first hand. It takes a minute.';
  static const String termsAgree = 'I understand and agree';
  static const String termsAgreeCaption = 'Required to use the app';
  static const String termsAccept = 'Accept and continue';
  static const String termsDecline = 'No thanks, close the app';
  static const String termsRow = 'Terms and safety';
  static const String termsRowCaption = 'Play fair, play safe, trusted Wi-Fi';
  static const String termsVersionLine = 'Version';

  // Walkthroughs and the first-run intro
  static const String tourTitle = 'App tour';
  static const String learnTitle = 'Learn poker';
  static const String walkNext = 'Next';
  static const String walkDone = 'Done';
  static const String walkSkip = 'Skip';
  static String walkStep(int step, int total) => 'Step $step of $total';
  static const String introTitle = 'Welcome';
  static const String introBody =
      'Want a quick look around before the first hand? Both are optional. You can open them again later from Settings or the Guide.';
  static const String introTour = 'Take the app tour';
  static const String introTourCaption = 'How hosting, joining and playing work. About 2 minutes.';
  static const String introLearn = 'Learn poker';
  static const String introLearnCaption = 'New to Texas Hold\'em? The basics in 10 short steps.';
  static const String introSkip = 'Skip, I know my way';
  static const String introSkipCaption = 'Go straight to the app.';
  static const String guideTours = 'Tours';
  static const String helpTourRow = 'App tour';
  static const String helpTourCaption = 'Hosting, joining and playing in 7 steps';
  static const String helpLearnRow = 'Learn poker';
  static const String helpLearnCaption = 'The rules and hands, step by step';
  static const String followToTour = 'Next: see how the app works';
  static const String followToLesson = 'Next: learn the basics of poker';
  static const String guideTourRow = 'Replay the app tour';
  static const String guideTourRowCaption = 'Hosting, joining and playing in 7 steps';
  static const String guideLearnRow = 'Learn poker';
  static const String guideLearnRowCaption = 'A first lesson for new players';
}
