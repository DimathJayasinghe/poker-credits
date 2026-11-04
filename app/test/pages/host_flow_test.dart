import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

Future<void> _startHosting(WidgetTester tester, TestHarness harness, {String name = 'Dimath'}) async {
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('HOST A GAME'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, name);
  await tester.ensureVisible(find.text('START HOSTING'));
  await tester.tap(find.text('START HOSTING'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('hosting starts the server, connects over loopback with both tokens and shows the lobby', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    await _startHosting(tester, harness);

    expect(harness.host.started, 1);
    expect(find.byType(TablePage), findsOneWidget);
    expect(harness.wakeLock.enabled, 1, reason: 'the screen stays on while the table is shown');
    expect(harness.keepAlive.started, <String>['KQ7M'], reason: 'Android keeps the process alive for the players');

    // The host UI talks to its own server like any client: RESUME with both tokens.
    final resume = harness.network.last.sent.single as Resume;
    expect(resume.roomCode, 'KQ7M');
    expect(resume.sessionToken, 'sess');
    expect(resume.hostToken, 'host-secret');

    harness.network.last.serverSends(
      snapshot(
        version: 1,
        view: roomView().copyWith(phase: WirePhase.lobby, seats: <SeatView>[seatView(0, 'Dimath'), seatView(1, 'Alice')]),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Room KQ7M'), findsOneWidget);
    expect(find.text('KQ7M'), findsWidgets);
    expect(find.text('192.168.1.5:7878'), findsOneWidget, reason: 'typed address next to the QR code');
    expect(find.text('DIMATH'), findsOneWidget);
    expect(find.text('ALICE'), findsOneWidget);

    // The session is stored so the app can resume after being killed.
    final stored = await harness.tokens.read();
    expect(stored!.hostToken, 'host-secret');
    expect(stored.serverUri, 'ws://127.0.0.1:7878/v1/ws');

    await tester.tap(find.text('START HAND'));
    await tester.pump();
    expect(harness.network.last.sent.last, isA<StartHand>());

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an invalid name or a non-number keeps the form open and starts nothing', (tester) async {
    final harness = TestHarness();
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.tap(find.text('HOST A GAME'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bad<name>');
    await tester.ensureVisible(find.text('START HOSTING'));
    await tester.tap(find.text('START HOSTING'));
    await tester.pump();

    expect(find.text('USE 1 TO 20 LETTERS, DIGITS, SPACES, - OR _'), findsOneWidget);
    expect(harness.host.started, 0);
  });

  testWidgets('a busy port is explained on the form', (tester) async {
    final harness = TestHarness(host: FakeHostServer(failure: const HostException(HostFailure.portBusy, 'in use')));
    await _startHosting(tester, harness);

    expect(find.textContaining('PORT IS BUSY'), findsOneWidget);
    expect(find.byType(TablePage), findsNothing);
  });
}
