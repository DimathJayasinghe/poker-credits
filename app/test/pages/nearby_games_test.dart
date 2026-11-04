import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

const _sam = DiscoveredLobby(hostAndPort: '192.168.1.40:7878', roomCode: 'ABCD', hostName: 'Sam', playerCount: 5, maxPlayers: 10);
const _ann = DiscoveredLobby(hostAndPort: '192.168.1.41:7879', roomCode: 'WXYZ', hostName: 'Ann', playerCount: 1, maxPlayers: 10);

Future<TestHarness> _openJoin(WidgetTester tester, {TestHarness? harness}) async {
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = harness ?? TestHarness();
  await tester.pumpWidget(h.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('JOIN A GAME'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the join page starts looking for open games at once and says so', (tester) async {
    final harness = await _openJoin(tester);
    expect(harness.finder.browses, hasLength(1));
    expect(find.text('GAMES ON THIS WI-FI'), findsOneWidget);
    expect(find.text('LOOKING FOR OPEN GAMES'), findsOneWidget);
    expect(find.text('SEARCH AGAIN'), findsNothing, reason: 'not while a scan is running');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('games appear as they are found; tapping one fills the code and joins that address without a search', (tester) async {
    final harness = await _openJoin(tester);
    harness.finder.browses.single.show(const <DiscoveredLobby>[_sam]);
    await tester.pump();
    await tester.pump();
    expect(find.text('SAM'), findsOneWidget);
    expect(find.text('Room ABCD, 5 of 10 seats taken'), findsOneWidget);
    harness.finder.browses.single.show(const <DiscoveredLobby>[_sam, _ann]);
    await tester.pump();
    await tester.pump();
    expect(find.text('ANN'), findsOneWidget);

    await tester.tap(find.text('ANN'));
    await tester.pump();
    final code = tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text;
    expect(code, 'WXYZ');

    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.ensureVisible(find.text('JOIN'));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump();
    expect(harness.finder.searched, isEmpty, reason: 'the address is already known');
    expect(harness.network.uris.last.toString(), 'ws://192.168.1.41:7879/v1/ws');
    final join = harness.network.last.sent.single as JoinRoom;
    expect((join.roomCode, join.name), ('WXYZ', 'Alice'));
    harness.network.last
      ..serverSends(const Joined(playerId: 'p_1', role: Role.player, seatIndex: 1, sessionToken: 't'))
      ..serverSends(
        snapshot(
          version: 1,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(seats: <SeatView>[seatView(1, 'Alice')]).copyWith(phase: WirePhase.lobby),
        ),
      );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(harness.finder.browses.single.cancelled, isTrue, reason: 'leaving the page stops the scan');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a finished scan with nothing says so and offers another search', (tester) async {
    final harness = await _openJoin(tester);
    harness.finder.browses.single.finish();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No open games found'), findsOneWidget);
    await tester.tap(find.text('SEARCH AGAIN'));
    await tester.pump();
    expect(harness.finder.browses, hasLength(2));
    expect(harness.finder.browses.first.cancelled, isTrue);
    expect(find.text('LOOKING FOR OPEN GAMES'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('results of an old scan do not leak into a new one', (tester) async {
    final harness = await _openJoin(tester);
    final first = harness.finder.browses.single;
    first.show(const <DiscoveredLobby>[_sam]);
    first.finish();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('SEARCH AGAIN'));
    await tester.pump();
    expect(find.text('SAM'), findsNothing, reason: 'the list starts over');
    harness.finder.browses.last.show(const <DiscoveredLobby>[_ann]);
    await tester.pump();
    await tester.pump();
    expect(find.text('ANN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('where the network cannot be scanned (web) the card is not shown', (tester) async {
    final harness = TestHarness();
    harness.finder.supported = false;
    await _openJoin(tester, harness: harness);
    expect(harness.finder.browses, isEmpty);
    expect(find.text('GAMES ON THIS WI-FI'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scale in <double>[1, 2, 3]) {
    testWidgets('a long list of games holds at text x$scale on a small phone without overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = TestHarness();
      await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
      await tester.pump();
      await tester.ensureVisible(find.text('JOIN A GAME'));
      await tester.tap(find.text('JOIN A GAME'));
      await tester.pumpAndSettle();
      final many = <DiscoveredLobby>[
        for (var i = 0; i < 6; i++)
          DiscoveredLobby(
            hostAndPort: '192.168.1.$i:7878',
            roomCode: 'AB${i}D'.replaceAll('0', 'E').replaceAll('1', 'F'),
            hostName: 'A very long host name $i',
            playerCount: i + 1,
            maxPlayers: 10,
          ),
      ];
      harness.finder.browses.single.show(many);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(BrutalRow), findsNWidgets(6));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
