import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

final _seats = <SeatView>[
  seatView(0, 'Alice', chips: 940, bet: 60),
  seatView(1, 'Bob', chips: 1200, bet: 60),
  seatView(3, 'Cara', chips: 0, allIn: true),
  seatView(5, 'Dan', chips: 75, folded: true),
  seatView(7, 'Eve', chips: 500, away: true),
  seatView(8, 'Gus', chips: 880, connected: false),
];

RoomView _betting() => roomView(hand: 7, activeSeat: 1, pot: 210, seats: _seats, deadline: 1730000021000).copyWith(
  dealerSeat: 5,
  smallBlindSeat: 7,
  bigBlindSeat: 8,
  currentHighBet: 60,
  minRaiseTo: 120,
);

Future<void> _openTable(WidgetTester tester, TestHarness harness, RoomView view, {Size size = const Size(1280, 800)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Dimath');
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  // Let the route transition to the table finish.
  await tester.pump(const Duration(milliseconds: 600));
  harness.network.last.serverSends(snapshot(version: 1, serverTime: harness.clock.millisecondsSinceEpoch, view: view));
  await tester.pump();
  await tester.pump();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(loadFonts);

  testWidgets('shows the pot, the acting player with a countdown, tags and the ticker', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting());
    harness.network.last
      ..serverSends(
        const ActionPerformed(
          playerId: 'p_1',
          playerName: 'Bob',
          kind: ActionKind.raise,
          amount: 60,
          chipsRemaining: 1140,
          allIn: false,
          auto: false,
        ),
      )
      ..serverSends(
        const ActionPerformed(playerId: 'p_3', playerName: 'Cara', kind: ActionKind.call, amount: 60, chipsRemaining: 0, allIn: true, auto: false),
      );
    await tester.pump();
    await tester.pump();

    expect(find.text('210'), findsOneWidget);
    expect(find.textContaining('ACTING: BOB'), findsOneWidget);
    expect(find.textContaining('0:21'), findsOneWidget);
    expect(find.text('FOLDED'), findsOneWidget);
    expect(find.text('ALL-IN'), findsWidgets);
    expect(find.text('AWAY'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.textContaining('BOB RAISES TO 60'), findsOneWidget);
    expect(find.textContaining('CARA CALLS 60'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('host buttons only send commands, and are disabled while the link is down', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting());

    await tester.tap(find.text('PAUSE'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<Pause>());
    await tester.tap(find.text('UNDO'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<Undo>());

    // The socket drops: a banner appears and nothing can be sent.
    final before = harness.network.last.sent.length;
    harness.network.last.drop();
    await tester.pump();
    await tester.pump();
    expect(find.text('RECONNECTING'), findsOneWidget);
    await tester.tap(find.text('PAUSE'), warnIfMissed: false);
    await tester.pump();
    expect(harness.network.last.sent.length, before);
    await _close(tester);
  });

  testWidgets('between hands the primary button starts the next hand', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, roomView(hand: 7, seats: _seats).copyWith(phase: WirePhase.nextHandPrep));
    await tester.tap(find.text('START HAND'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<StartHand>());
    await _close(tester);
  });

  testWidgets('all-in run-out: host begins the showdown', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting().copyWith(phase: WirePhase.allInRunout));
    await tester.tap(find.text('BEGIN SHOWDOWN'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<BeginShowdown>());
    await _close(tester);
  });

  testWidgets('showdown: the host picks winners from the server\'s eligible players only', (tester) async {
    final harness = TestHarness();
    final view = _betting().copyWith(
      phase: WirePhase.showdown,
      pots: const <PotView>[
        PotView(tierIndex: 0, amount: 180, eligiblePlayerIds: <String>['p_0', 'p_1', 'p_3']),
        PotView(tierIndex: 1, amount: 30, eligiblePlayerIds: <String>['p_0', 'p_1']),
      ],
    );
    await _openTable(tester, harness, view);
    await tester.tap(find.text('PICK WINNERS'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM WINNERS'), findsOneWidget);
    // Dan (folded) and Eve (not eligible) are not offered.
    expect(find.textContaining('[ ] DAN'), findsNothing);
    expect(find.textContaining('[ ] EVE'), findsNothing);
    final confirm = find.text('CONFIRM WINNERS');
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    expect(harness.network.last.sent.whereType<ResolveShowdown>(), isEmpty, reason: 'every pot needs a winner first');

    await tester.tap(find.textContaining('[ ] CARA'));
    await tester.pump();
    await tester.tap(find.textContaining('[ ] ALICE').first);
    await tester.tap(find.textContaining('[ ] BOB').first);
    await tester.pump();
    await tester.tap(find.textContaining('[ ] ALICE').last);
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final sent = harness.network.last.sent.whereType<ResolveShowdown>().single;
    expect(sent.allocations[0].potIndex, 0);
    expect(sent.allocations[0].winnerPlayerIds, <String>['p_0', 'p_1', 'p_3'].where((id) => id != 'p_3' || true).toList().sublist(0, 3));
    expect(sent.allocations[1].potIndex, 1);
    expect(sent.allocations[1].winnerPlayerIds, <String>['p_0']);
    await _close(tester);
  });

  testWidgets('the host approves a top-up request from the banner', (tester) async {
    final harness = TestHarness();
    final view = roomView(hand: 3, seats: _seats).copyWith(
      phase: WirePhase.nextHandPrep,
      pendingRebuys: const <PendingRebuyView>[PendingRebuyView(playerId: 'p_3', amount: 1000, approved: false)],
    );
    await _openTable(tester, harness, view);
    expect(find.textContaining('CARA WANTS A TOP-UP OF 1000'), findsOneWidget);
    await tester.tap(find.text('APPROVE'));
    await tester.pump();
    final sent = harness.network.last.sent.last as ApproveRebuy;
    expect((sent.playerId, sent.amount), ('p_3', 1000));
    await _close(tester);
  });

  testWidgets('tapping a seat asks before removing a player, never the host\'s own seat', (tester) async {
    final harness = TestHarness();
    final view = roomView(
      hand: 3,
      seats: <SeatView>[
        seatView(0, 'Dimath').copyWith(playerId: 'p_host'),
        seatView(1, 'Bob'),
      ],
    ).copyWith(phase: WirePhase.nextHandPrep);
    await _openTable(tester, harness, view);

    await tester.tap(find.text('DIMATH'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('REMOVE THIS PLAYER?'), findsNothing);

    await tester.tap(find.text('BOB'));
    await tester.pumpAndSettle();
    expect(find.text('REMOVE THIS PLAYER?'), findsOneWidget);
    await tester.tap(find.text('REMOVE PLAYER'));
    await tester.pumpAndSettle();
    expect((harness.network.last.sent.last as Kick).playerId, 'p_1');
    await _close(tester);
  });

  testWidgets('a paused game shows a banner and a resume button', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting().copyWith(paused: true, phase: WirePhase.paused));
    expect(find.text('GAME PAUSED'), findsOneWidget);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<ResumeGame>());
    await _close(tester);
  });

  testWidgets('a presence check asks the host, whose answer is sent for that player', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, roomView(seats: _seats).copyWith(phase: WirePhase.nextHandPrep));
    harness.network.last.serverSends(const PresenceCheck(subjectPlayerId: 'p_7', subjectName: 'Eve', deadlineMs: 1));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('STILL HERE? EVE'), findsOneWidget);
    await tester.tap(find.text('NO'));
    await tester.pump();
    final vote = harness.network.last.sent.last as PresenceVote;
    expect((vote.playerId, vote.stillPlaying), ('p_7', false));
    await _close(tester);
  });

  testWidgets('a lost room ends the game screen with a way out', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting());
    harness.network.last.serverSends(const ErrorMessage(code: ErrorCode.roomNotFound, message: 'gone'));
    await tester.pump();
    await tester.pump();
    expect(find.text('THE ROOM NO LONGER EXISTS'), findsOneWidget);
    expect(await harness.tokens.read(), isNull, reason: 'stale tokens are forgotten');
    await tester.tap(find.text('LEAVE ROOM'));
    await tester.pumpAndSettle();
    expect(find.byType(TablePage), findsNothing);
    expect(harness.host.stopped, 1);
    expect(harness.keepAlive.stopped, 1, reason: 'the background service ends with the game');
    await _close(tester);
  });

  testWidgets('returning to the foreground makes sure the server runs, then reconnects', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting());
    final opened = harness.network.opened.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(harness.host.ensured, 1);
    expect(harness.network.opened.length, opened + 1);
    expect(harness.network.last.sent.single, isA<Resume>());
    await _close(tester);
  });

  testWidgets('the wake lock is released when the table closes', (tester) async {
    final harness = TestHarness();
    await _openTable(tester, harness, _betting());
    expect(harness.wakeLock.enabled, 1);
    await _close(tester);
    expect(harness.wakeLock.disabled, 1);
  });
}
