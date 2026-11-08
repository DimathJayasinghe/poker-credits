import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/sound_cues.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_keypad.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

final List<SeatView> _seats = <SeatView>[
  seatView(0, 'Dimath'),
  seatView(1, 'Alice', chips: 940, bet: 20),
  seatView(2, 'Bob', chips: 1200),
];

RoomView _betting({int active = 1}) => roomView(hand: 3, activeSeat: active, pot: 60, seats: _seats, deadline: 1730000021000).copyWith(
  currentHighBet: 20,
  minRaiseTo: 40,
);

const LegalActions _legal = LegalActions(
  canFold: true,
  canCheck: false,
  canCall: true,
  callAmount: 20,
  canRaise: true,
  minRaiseTo: 40,
  maxRaiseTo: 940,
);

TurnPrompt _prompt({int seq = 4, LegalActions legal = _legal}) => TurnPrompt(playerId: 'p_1', seatIndex: 1, nextActionSeq: seq, legal: legal);

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openJoin(WidgetTester tester, TestHarness harness) async {
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
}

Future<void> _fillAndJoin(
  WidgetTester tester, {
  String code = 'kq7m',
  String name = 'Alice',
  String button = 'JOIN',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), code);
  await tester.enterText(fields.at(1), name);
  await tester.ensureVisible(find.text(button));
  await tester.tap(find.text(button));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Joins as Alice (p_1, seat 1) and shows the controller with the first snapshot.
Future<TestHarness> _joined(WidgetTester tester, {RoomView? view, TestHarness? harness}) async {
  _phone(tester);
  final h = harness ?? TestHarness();
  await _openJoin(tester, h);
  await _fillAndJoin(tester);
  h.network.last
    ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
    ..serverSends(snapshot(version: 1, serverTime: h.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: view ?? _betting(active: 2)));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return h;
}

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadFonts);

  testWidgets('joining by code alone finds the host, sends JOIN_ROOM there, then shows the controller', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await _openJoin(tester, harness);
    await _fillAndJoin(tester);

    expect(harness.finder.searched, <String>['KQ7M']);
    expect(harness.network.uris.last.toString(), 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
    final join = harness.network.last.sent.single as JoinRoom;
    expect((join.roomCode, join.name, join.spectator), ('KQ7M', 'Alice', false));
    expect(join.features, contains(featureVirtualCards), reason: 'join_sends_virtual_cards_feature');
    expect(find.text('CONNECTING'), findsOneWidget);

    harness.network.last
      ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 'alice-token'))
      ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting(active: 2)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PlayerPage), findsOneWidget);
    expect(findNumber(940), findsOneWidget, reason: 'my chips in large type');
    expect(find.textContaining('WAITING FOR BOB'), findsOneWidget);
    expect(find.text('FOLD'), findsNothing, reason: 'no buttons when it is not my turn');

    // The session is stored for resuming.
    final stored = await harness.tokens.read();
    expect(stored!.sessionToken, 'alice-token');
    expect(stored.serverUri, 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
    expect(stored.playerId, 'p_1');
    expect(stored.hostToken, isNull);
    await _close(tester);
  });

  testWidgets('a rejected name stays on the page and can be fixed and retried', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await _openJoin(tester, harness);
    await _fillAndJoin(tester);
    harness.network.last.serverSends(const ErrorMessage(code: ErrorCode.nameInvalid, message: 'bad'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(JoinPage), findsOneWidget);
    expect(find.textContaining('USE 1 TO 20 LETTERS'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(1), 'Alice B');
    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump();
    expect(harness.network.opened, hasLength(2), reason: 'a fresh attempt');
    expect((harness.network.last.sent.single as JoinRoom).name, 'Alice B');
    await _close(tester);
  });

  testWidgets('a join that fails never wipes the stored session of another room', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(
      const StoredSession(serverUri: 'wss://10.0.0.9:7878/v1/ws#pin=$testPin', roomCode: 'ABCD', sessionToken: 'keep-me', playerId: 'p_9'),
    );
    final harness = TestHarness(tokens: tokens);
    await _openJoin(tester, harness);
    await _fillAndJoin(tester, code: 'ZZZZ');
    harness.network.last.serverSends(const ErrorMessage(code: ErrorCode.roomNotFound, message: 'no such room'));
    await tester.pump();
    await tester.pump();
    expect(find.text('NO GAME WITH THAT CODE ON THIS ADDRESS'), findsWidgets);
    expect((await tokens.read())?.sessionToken, 'keep-me');
    await _close(tester);
  });

  testWidgets('a full table is explained and the player can watch instead', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await _openJoin(tester, harness);
    await _fillAndJoin(tester);
    harness.network.last.serverSends(const ErrorMessage(code: ErrorCode.roomFull, message: 'full'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('THE TABLE IS FULL'), findsWidgets);
    await tester.ensureVisible(find.text('WATCH ONLY'));
    await tester.tap(find.text('WATCH ONLY'));
    await tester.pump();
    await tester.pump();
    expect((harness.network.last.sent.single as JoinRoom).spectator, isTrue);
    await _close(tester);
  });

  testWidgets('sound effects follow the live messages: my own cards and actions, not the table\'s, and no replay after a snapshot', (tester) async {
    final harness = await _joined(tester);
    expect(harness.sound.cues, isEmpty, reason: 'the first snapshot only sets the baseline');
    harness.network.last
      ..serverSends(holeCards('As', 'Kd', hand: 3))
      ..serverSends(
        const ActionPerformed(playerId: 'p_2', playerName: 'Bo', kind: ActionKind.raise, amount: 40, chipsRemaining: 900, allIn: false, auto: false),
      )
      ..serverSends(
        const ActionPerformed(
          playerId: 'p_1',
          playerName: 'Alice',
          kind: ActionKind.call,
          amount: 40,
          chipsRemaining: 900,
          allIn: false,
          auto: false,
        ),
      );
    await tester.pump();
    expect(harness.sound.cues, [
      SoundCue.call,
    ], reason: 'HOLE_CARDS of the snapshot\'s hand is a replay, Bo\'s raise is the table\'s sound, Alice\'s own call is hers');
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting().copyWith(handNumber: 4)))
      ..serverSends(holeCards('2c', '7d', hand: 4));
    await tester.pump();
    expect(harness.sound.cues, [SoundCue.call, SoundCue.deal], reason: 'a new hand: the deck is the table\'s, the two cards are mine');
    await _close(tester);
  });

  testWidgets('on my turn the server\'s buttons appear, the alert fires once and a second tap is ignored', (tester) async {
    final harness = await _joined(tester);
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting()))
      ..serverSends(_prompt());
    await tester.pump();
    await tester.pump();

    expect(find.text('YOUR TURN'), findsOneWidget);
    expect(find.text('CALL 20'), findsOneWidget);
    expect(find.text('CHECK'), findsNothing, reason: 'the server did not allow a check');
    expect(harness.haptics.turns, 1);
    expect(harness.sound.turns, 1);

    await tester.tap(find.text('CALL 20'));
    await tester.pump();
    final action = harness.network.last.sent.whereType<GameAction>().single;
    expect(action.actionSeq, 4);
    expect(action.action, isA<CallAction>());
    await tester.tap(find.text('CALL 20'), warnIfMissed: false);
    await tester.pump();
    expect(harness.network.last.sent.whereType<GameAction>(), hasLength(1), reason: 'double tap');

    // The server repeats the prompt after a reconnect: no second buzz for the same turn.
    harness.network.last.drop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    harness.network.last
      ..serverSends(snapshot(version: 2, serverTime: harness.clock.millisecondsSinceEpoch, nextActionSeq: 4, view: _betting()))
      ..serverSends(_prompt());
    await tester.pump();
    await tester.pump();
    expect(harness.haptics.turns, 1, reason: 'the same turn is not announced twice');

    // A new turn (higher action counter) is announced.
    harness.network.last
      ..serverSends(const Ack(nextActionSeq: 5, duplicate: false))
      ..serverSends(StateUpdate(stateVersion: 3, view: _betting(active: 2)))
      ..serverSends(StateUpdate(stateVersion: 4, view: _betting()))
      ..serverSends(_prompt(seq: 5));
    await tester.pump();
    await tester.pump();
    expect(harness.haptics.turns, 2);
    await _close(tester);
  });

  testWidgets('no action buttons while a spectator-style prompt is for somebody else', (tester) async {
    final harness = await _joined(tester);
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting(active: 2)))
      ..serverSends(const TurnPrompt(playerId: 'p_2', seatIndex: 2, nextActionSeq: 9, legal: _legal));
    await tester.pump();
    await tester.pump();
    expect(find.text('FOLD'), findsNothing);
    expect(find.text('RAISE'), findsNothing);
    expect(harness.haptics.turns, 0);
    await _close(tester);
  });

  testWidgets('check is offered only when the server allows it, and fold sends FOLD', (tester) async {
    final harness = await _joined(tester);
    const legal = LegalActions(canFold: true, canCheck: true, canCall: false, callAmount: 0, canRaise: false, minRaiseTo: 0, maxRaiseTo: 0);
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting()))
      ..serverSends(_prompt(legal: legal));
    await tester.pump();
    await tester.pump();
    expect(find.text('CHECK'), findsOneWidget);
    expect(find.textContaining('CALL'), findsNothing);
    await tester.tap(find.text('FOLD'));
    await tester.pump();
    expect(harness.network.last.sent.whereType<GameAction>().single.action, isA<FoldAction>());
    await _close(tester);
  });

  testWidgets('raise sheet: the slider ends at the server\'s bounds and all-in is its own action', (tester) async {
    final harness = await _joined(tester);
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting()))
      ..serverSends(_prompt());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('RAISE'));
    await tester.pumpAndSettle();
    expect(find.text('RAISE TO 40'), findsOneWidget, reason: 'starts at the server minimum');
    await tester.tap(find.text('RAISE TO 40'));
    await tester.pumpAndSettle();
    expect((harness.network.last.sent.whereType<GameAction>().single.action as RaiseAction).toAmount, 40);

    // Back to a fresh turn and go all-in.
    harness.network.last
      ..serverSends(const Ack(nextActionSeq: 5, duplicate: false))
      ..serverSends(StateUpdate(stateVersion: 3, view: _betting(active: 2)))
      ..serverSends(StateUpdate(stateVersion: 4, view: _betting()))
      ..serverSends(_prompt(seq: 5));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('RAISE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALL-IN'));
    await tester.pump();
    expect(find.text('ALL-IN 940'), findsOneWidget);
    await tester.tap(find.text('ALL-IN 940'));
    await tester.pumpAndSettle();
    final all = harness.network.last.sent.whereType<GameAction>().last;
    expect(all.action, isA<AllInAction>());
    expect(all.actionSeq, 5);
    await _close(tester);
  });

  testWidgets('buttons are disabled while the link is down', (tester) async {
    final harness = await _joined(tester);
    harness.network.last
      ..serverSends(StateUpdate(stateVersion: 2, view: _betting()))
      ..serverSends(_prompt());
    await tester.pump();
    await tester.pump();
    final before = harness.network.last.sent.length;
    harness.network.last.drop();
    await tester.pump();
    await tester.pump();
    expect(find.text('RECONNECTING'), findsWidgets);
    await tester.tap(find.text('CALL 20'), warnIfMissed: false);
    await tester.pump();
    expect(harness.network.opened.first.sent.length, before);
    await _close(tester);
  });

  testWidgets('coming back to the foreground resumes with the token, never a second join', (tester) async {
    final harness = await _joined(tester);
    final opened = harness.network.opened.length;
    // The order a device really goes through (the framework asserts it).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(harness.network.opened.length, opened + 1);
    final resume = harness.network.last.sent.single as Resume;
    expect((resume.roomCode, resume.sessionToken, resume.hostToken), ('KQ7M', 'alice-token', null));
    expect(resume.features, contains(featureVirtualCards));
    await _close(tester);
  });

  testWidgets('top-up asks the host for an amount', (tester) async {
    final harness = await _joined(tester);
    await tester.tap(find.text('TOP UP'));
    await tester.pumpAndSettle();
    for (final digit in <String>['5', '0', '0']) {
      await tester.tap(find.descendant(of: find.byType(BrutalKeypad), matching: find.text(digit)));
      await tester.pump();
    }
    await tester.tap(find.text('ASK'));
    await tester.pumpAndSettle();
    expect((harness.network.last.sent.last as RequestRebuy).amount, 500);
    await _close(tester);
  });

  testWidgets('a pending top-up is shown, and sitting out toggles', (tester) async {
    final harness = await _joined(
      tester,
      view: _betting(active: 2).copyWith(pendingRebuys: const <PendingRebuyView>[PendingRebuyView(playerId: 'p_1', amount: 500, approved: false)]),
    );
    expect(find.textContaining('TOP-UP REQUESTED: 500'), findsOneWidget);
    await tester.tap(find.text('SIT OUT'));
    await tester.pump();
    expect((harness.network.last.sent.last as SetSittingOut).sittingOut, isTrue);
    await _close(tester);
  });

  testWidgets('leaving the table asks first, tells the server and forgets the session', (tester) async {
    final harness = await _joined(tester);
    await tester.tap(find.text('LEAVE'));
    await tester.pumpAndSettle();
    expect(find.text('LEAVE THE TABLE?'), findsOneWidget);
    await tester.tap(find.text('LEAVE TABLE').last);
    await tester.pumpAndSettle();
    expect(harness.network.last.sent.last, isA<LeaveTable>());
    // The leave chain awaits socket closing; let its microtasks run.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(await harness.tokens.read(), isNull);
    expect(find.byType(PlayerPage), findsNothing);
    await _close(tester);
  });

  testWidgets('the back arrow and the system back both ask before giving up the seat', (tester) async {
    final harness = await _joined(tester);
    expect(find.byType(BackCell), findsOneWidget, reason: 'the player screen has a visible back button');
    await tester.tap(find.byType(BackCell));
    await tester.pumpAndSettle();
    expect(find.text('LEAVE THE TABLE?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsOneWidget, reason: 'cancel stays at the table');
    expect(harness.network.last.sent.whereType<LeaveTable>(), isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('LEAVE THE TABLE?'), findsOneWidget, reason: 'the system back asks too');
    await tester.tap(find.text('LEAVE TABLE').last);
    await tester.pumpAndSettle();
    expect(harness.network.last.sent.last, isA<LeaveTable>());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlayerPage), findsNothing);
    await _close(tester);
  });

  testWidgets('a removed player sees why, with a way out', (tester) async {
    final harness = await _joined(tester);
    harness.network.last.serverSends(StateUpdate(stateVersion: 2, view: roomView(seats: <SeatView>[seatView(0, 'Dimath'), seatView(2, 'Bob')])));
    await tester.pump();
    await tester.pump();
    expect(find.text('YOU DO NOT HAVE A SEAT'), findsWidgets);
    expect(find.text('LEAVE ROOM'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a stored guest session offers "back to my game" and resumes it', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(
      const StoredSession(serverUri: 'wss://192.168.1.5:7878/v1/ws#pin=$testPin', roomCode: 'KQ7M', sessionToken: 'alice-token', playerId: 'p_1'),
    );
    final harness = TestHarness(tokens: tokens);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.pump();
    expect(find.text('RESUME HOSTED GAME KQ7M'), findsNothing);
    await tester.tap(find.text('BACK TO MY GAME KQ7M'));
    await tester.pump();
    await tester.pump();
    final resume = harness.network.last.sent.single as Resume;
    expect((resume.roomCode, resume.sessionToken), ('KQ7M', 'alice-token'));

    harness.network.last.serverSends(snapshot(version: 8, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting(active: 2)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(findNumber(940), findsOneWidget, reason: 'same seat as before the app was killed');
    await _close(tester);
  });

  testWidgets('a spectator can go back at once, no question asked', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    await _openJoin(tester, harness);
    await _fillAndJoin(tester, button: 'WATCH ONLY');
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_w', role: Role.spectator, sessionToken: 'watch-token'))
      ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BackCell), findsOneWidget);
    await tester.tap(find.byType(BackCell));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(TablePage), findsNothing);
    expect(find.text('HOST A GAME'), findsOneWidget, reason: 'back on the home screen');
    await _close(tester);
  });

  testWidgets('watching shows the table without any control', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    await _openJoin(tester, harness);
    await _fillAndJoin(tester, button: 'WATCH ONLY');
    expect((harness.network.last.sent.single as JoinRoom).spectator, isTrue);
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_w', role: Role.spectator, sessionToken: 'watch-token'))
      ..serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TablePage), findsOneWidget);
    expect(find.text('WATCHING'), findsOneWidget);
    expect(find.text('PAUSE'), findsNothing);
    expect(find.text('START HAND'), findsNothing);
    expect(find.text('END GAME'), findsNothing);
    await _close(tester);
  });

  testWidgets('no host answers: says so, offers the address field, and joins by the typed address', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    harness.finder.found = null;
    await _openJoin(tester, harness);
    expect(find.byType(TextField), findsNWidgets(2), reason: 'code and name; the address is not asked for up front');
    await _fillAndJoin(tester);

    expect(harness.network.opened, isEmpty);
    expect(find.textContaining('NO GAME WITH THAT CODE FOUND ON THIS WI-FI'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3), reason: 'the address field appears');

    // Code and name share a line; the address field comes after them.
    await tester.enterText(find.byType(TextField).at(2), '192.168.1.9');
    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump();
    expect(harness.network.uris.last.toString(), 'wss://192.168.1.9:7878/v1/ws#pin=$testPin');
    expect(harness.finder.searched, hasLength(1), reason: 'a typed address skips the search');
    await _close(tester);
  });

  testWidgets('the search can be cancelled, and leaving the page cancels it too', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    harness.finder.manual = true;
    await _openJoin(tester, harness);
    await _fillAndJoin(tester);
    expect(find.text('LOOKING FOR THE GAME ON THIS WI-FI'), findsOneWidget);
    expect(harness.network.opened, isEmpty);

    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    expect(harness.finder.pending.single.cancelled, isTrue);
    expect(find.text('LOOKING FOR THE GAME ON THIS WI-FI'), findsNothing);
    expect(harness.network.opened, isEmpty, reason: 'a cancelled search joins nothing');

    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await _close(tester);
    expect(harness.finder.pending.last.cancelled, isTrue);
  });

  testWidgets('a guest whose host moved finds it again by the room code and resumes there', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(
      const StoredSession(serverUri: 'wss://192.168.1.5:7878/v1/ws#pin=$testPin', roomCode: 'KQ7M', sessionToken: 'alice-token', playerId: 'p_1'),
    );
    final harness = TestHarness(tokens: tokens);
    harness.finder.found = const DiscoveredHost('192.168.1.23:7878', fingerprint: testPin);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('BACK TO MY GAME KQ7M'));
    await tester.pump();
    await tester.pump();
    harness.network.last.serverSends(snapshot(version: 8, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting(active: 2)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final opened = harness.network.opened.length;

    // The host disappears from its old address; attempts fail until the search kicks in.
    harness.network.refuseConnections = true;
    harness.network.last.drop();
    for (var t = 0; t < 120 && harness.finder.searched.isEmpty; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(harness.finder.searched, <String>['KQ7M']);
    harness.network.refuseConnections = false;
    await tester.pump();
    await tester.pump();
    // The next attempt comes after a jittered backoff delay (up to about 12 s), so wait for the
    // event rather than for a fixed time.
    for (var t = 0; t < 30 && harness.network.opened.length <= opened; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(harness.network.uris.last.toString(), 'wss://192.168.1.23:7878/v1/ws#pin=$testPin');
    expect(harness.network.opened.length, greaterThan(opened));
    expect(find.byType(PlayerPage), findsOneWidget, reason: 'the table stays on screen while the new address connects');
    expect(findNumber(940), findsOneWidget, reason: 'with the last known chips, not a blank screen');
    expect(find.text('RECONNECTING'), findsWidgets);
    expect(harness.network.last.sent.single, isA<Resume>());
    expect((await tokens.read())!.serverUri, 'wss://192.168.1.23:7878/v1/ws#pin=$testPin');
    await _close(tester);
  });

  testWidgets('a device that answers for the room code with another certificate is not followed', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(
      const StoredSession(serverUri: 'wss://192.168.1.5:7878/v1/ws#pin=$testPin', roomCode: 'KQ7M', sessionToken: 'alice-token', playerId: 'p_1'),
    );
    final harness = TestHarness(tokens: tokens);
    harness.finder.found = const DiscoveredHost('192.168.1.99:7878', fingerprint: otherTestPin);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('BACK TO MY GAME KQ7M'));
    await tester.pump();
    await tester.pump();
    harness.network.last.serverSends(snapshot(version: 8, serverTime: harness.clock.millisecondsSinceEpoch, view: _betting(active: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    harness.network.refuseConnections = true;
    harness.network.last.drop();
    for (var t = 0; t < 120 && harness.finder.searched.isEmpty; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(harness.finder.searched, <String>['KQ7M'], reason: 'the search still runs');
    harness.network.refuseConnections = false;
    for (var t = 0; t < 30; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      harness.network.uris.every((uri) => uri.host == '192.168.1.5'),
      isTrue,
      reason: 'the session token never goes to the other device: ${harness.network.uris}',
    );
    expect((await tokens.read())!.serverUri, 'wss://192.168.1.5:7878/v1/ws#pin=$testPin');
    await _close(tester);
  });
}
