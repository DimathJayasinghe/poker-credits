import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/solo_setup_page.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/solo_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../support/fakes.dart';

void _phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const StoredSession _hosted = StoredSession(serverUri: 'ws://127.0.0.1:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 'h-s', hostToken: 'h-h');
const StoredSession _savedSolo = StoredSession(
  serverUri: 'ws://127.0.0.1:50000/v1/ws',
  roomCode: 'SOLO',
  sessionToken: 'solo-sess',
  hostToken: 'solo-host',
  playerId: 'p_1',
);

Future<void> _openSetup(WidgetTester tester, TestHarness harness) async {
  await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
  await tester.pump();
  await tester.tap(find.text('PLAY ALONE'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadFonts);

  testWidgets('Home offers Play alone, and hides it where hosting is not possible', (tester) async {
    _phone(tester);
    await tester.pumpWidget(TestHarness().scope(const PokerCreditsApp()));
    await tester.pump();
    expect(find.text('PLAY ALONE'), findsOneWidget);
    expect(find.textContaining('Against computer players'), findsOneWidget);
    await _close(tester);

    await tester.pumpWidget(TestHarness(host: FakeHostServer(supported: false)).scope(const PokerCreditsApp()));
    await tester.pump();
    expect(find.text('PLAY ALONE'), findsNothing);
    await _close(tester);
  });

  testWidgets('the setup starts with four Normal opponents and a standard game, then starts the game', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(_hosted);
    final harness = TestHarness(tokens: tokens);
    await _openSetup(tester, harness);

    expect(find.byType(SoloSetupPage), findsOneWidget);
    expect(find.text('Reads the table.'), findsOneWidget);
    expect(find.text('Blinds rise every 8 hands.'), findsOneWidget);
    expect(find.text('No finished game at this table yet.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Dimath');
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final solo = harness.host.lastSolo!;
    expect((solo.bots, solo.skill, solo.ladderHands), (4, BotSkill.normal, 8));
    expect(harness.host.soloStarted, 1);
    expect(harness.host.started, 0, reason: 'the open server never started');

    // Connected over loopback with the host token, like any other client.
    expect(harness.network.uris.last.toString(), 'ws://127.0.0.1:7878/v1/ws');
    final resume = harness.network.last.sent.single as Resume;
    expect((resume.roomCode, resume.sessionToken, resume.hostToken), ('SOLO', 'solo-sess', 'solo-host'));

    // Saved in its own slot; the hosted game saved in the main slot is untouched.
    expect((await tokens.read(slot: TokenSlot.solo))?.roomCode, 'SOLO');
    expect((await tokens.read())?.roomCode, 'KQ7M');
    expect(find.byType(SoloTablePage), findsOneWidget);
    expect(find.byType(PlayerPage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the choices are what the server gets and are remembered for next time', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await _openSetup(tester, harness);

    await tester.tap(find.text('HARD'));
    await tester.tap(find.text('QUICK'));
    await tester.pump();
    expect(find.text('Reads you and adapts.'), findsOneWidget);
    expect(find.text('Blinds rise every 6 hands.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Increase'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Dimath');
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    await tester.pump();

    final solo = harness.host.lastSolo!;
    expect((solo.bots, solo.skill, solo.ladderHands), (5, BotSkill.hard, 6));
    final saved = harness.settings.value;
    expect((saved.soloBots, saved.soloSkill, saved.soloLength), (5, BotSkill.hard, SoloLength.quick));
    await _close(tester);
  });

  testWidgets('a bad name is refused before anything starts', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    await _openSetup(tester, harness);
    await tester.enterText(find.byType(TextField), 'No!');
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    expect(find.textContaining('USE 1 TO 20 LETTERS'), findsOneWidget);
    expect(harness.host.soloStarted, 0);
    await _close(tester);
  });

  testWidgets('a server that cannot start shows why and stays on the setup', (tester) async {
    _phone(tester);
    final harness = TestHarness(host: FakeHostServer(failure: const HostException(HostFailure.storage, 'disk full')));
    await _openSetup(tester, harness);
    await tester.enterText(find.byType(TextField), 'Dimath');
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    await tester.pump();
    expect(find.text('THE GAME FILES CANNOT BE SAVED ON THIS DEVICE.'), findsWidgets);
    expect(find.byType(SoloSetupPage), findsOneWidget);
    expect(await harness.tokens.read(slot: TokenSlot.solo), isNull);
    await _close(tester);
  });

  testWidgets('the setup shows the record for the table kind that is chosen', (tester) async {
    _phone(tester);
    final harness = TestHarness();
    harness.settings.value = AppSettings(
      acceptedTerms: currentTermsVersion,
      introDone: true,
      nameAsked: true,
      soloRecords: <String, SoloRecord>{soloRecordKey(4, BotSkill.normal): const SoloRecord(played: 3, wins: 1, bestPlace: 1)},
    );
    await _openSetup(tester, harness);
    expect(find.text('Best finish 1st. Won 1 of 3.'), findsOneWidget);
    await tester.tap(find.text('HARD'));
    await tester.pump();
    expect(find.text('No finished game at this table yet.'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('Home offers the saved solo game apart from a hosted one, and resumes it', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(_savedSolo, slot: TokenSlot.solo);
    final harness = TestHarness(tokens: tokens);
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.pump();
    expect(find.text('RESUME SOLO GAME'), findsOneWidget);
    expect(find.textContaining('RESUME HOSTED GAME'), findsNothing);

    await tester.tap(find.text('RESUME SOLO GAME'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(harness.host.soloStarted, 1);
    expect(harness.network.uris.last.toString(), 'ws://127.0.0.1:7878/v1/ws');
    final resume = harness.network.last.sent.single as Resume;
    expect((resume.roomCode, resume.sessionToken, resume.hostToken), ('SOLO', 'solo-sess', 'solo-host'));
    expect(find.byType(SoloTablePage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a saved game the server cannot open is dropped with a message', (tester) async {
    _phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.write(_savedSolo, slot: TokenSlot.solo);
    final harness = TestHarness(
      tokens: tokens,
      host: FakeHostServer(failure: const HostException(HostFailure.storage, 'gone')),
    );
    await tester.pumpWidget(harness.scope(const PokerCreditsApp()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('RESUME SOLO GAME'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('RESUME SOLO GAME'), findsNothing);
    expect(find.textContaining('CANNOT BE OPENED ANY MORE'), findsWidgets);
    expect(await tokens.read(slot: TokenSlot.solo), isNull);
    await _close(tester);
  });

  group('SoloNotifier', () {
    Future<(TestHarness, Ref)> started(WidgetTester tester) async {
      _phone(tester);
      final harness = TestHarness();
      late BuildContext context;
      await tester.pumpWidget(
        harness.scope(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final container = context.ref;
      final ok = await container
          .notifier(soloProvider)
          .start(
            name: 'Dimath',
            solo: const SoloConfig(bots: 3, skill: BotSkill.easy, ladderHands: 8),
          );
      expect(ok, isTrue);
      await tester.pump();
      harness.network.last.serverSends(
        snapshot(
          version: 1,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(seats: <SeatView>[seatView(0, 'Dimath')]),
        ),
      );
      await tester.pump();
      await tester.pump();
      return (harness, container);
    }

    testWidgets('the app going to the background pauses the game, and coming back does not resume it by itself', (tester) async {
      final (harness, container) = await started(tester);
      expect(container.read(sessionProvider).link.isLive, isTrue);
      container.notifier(soloProvider).onBackground();
      expect(harness.network.last.sent.whereType<Pause>(), hasLength(1));

      await container.notifier(soloProvider).onForeground();
      expect(harness.host.ensured, 1);
      await tester.pump();
      // The socket was replaced; the server answers the new `RESUME` with the paused room.
      expect(harness.network.opened, hasLength(2));
      harness.network.last.serverSends(
        snapshot(
          version: 2,
          serverTime: harness.clock.millisecondsSinceEpoch,
          view: roomView(seats: <SeatView>[seatView(0, 'Dimath')]).copyWith(paused: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      List<ClientMessage> sent() => <ClientMessage>[for (final t in harness.network.opened) ...t.sent];
      expect(sent().whereType<ResumeGame>(), isEmpty, reason: 'the player presses Resume');

      container.notifier(soloProvider).resume();
      expect(sent().whereType<ResumeGame>(), hasLength(1));
      await _close(tester);
    });

    testWidgets('leaving forgets only the solo slot and stops the server', (tester) async {
      final (harness, container) = await started(tester);
      await harness.tokens.write(_hosted);
      expect(await harness.tokens.read(slot: TokenSlot.solo), isNotNull);
      await container.notifier(soloProvider).leave();
      expect(await harness.tokens.read(slot: TokenSlot.solo), isNull);
      expect((await harness.tokens.read())?.roomCode, 'KQ7M');
      expect(harness.host.stopped, 1);
      expect(container.read(soloProvider).phase, SoloPhase.idle);
      await _close(tester);
    });

    testWidgets('a room the server no longer knows clears the solo slot and not the hosted one', (tester) async {
      final (harness, _) = await started(tester);
      await harness.tokens.write(_hosted);
      harness.network.last.serverSends(const ErrorMessage(code: ErrorCode.roomNotFound, message: 'gone'));
      await tester.pump();
      await tester.pump();
      expect(await harness.tokens.read(slot: TokenSlot.solo), isNull);
      expect((await harness.tokens.read())?.roomCode, 'KQ7M');
      await _close(tester);
    });

    testWidgets('suspending keeps the game saved for the Resume row', (tester) async {
      final (harness, container) = await started(tester);
      await container.notifier(soloProvider).suspend();
      expect((await harness.tokens.read(slot: TokenSlot.solo))?.roomCode, 'SOLO');
      expect(harness.host.stopped, 1);
      await _close(tester);
    });

    testWidgets('nothing is sent when no game is open', (tester) async {
      _phone(tester);
      final harness = TestHarness();
      late BuildContext context;
      await tester.pumpWidget(
        harness.scope(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final notifier = context.ref.notifier(soloProvider);
      notifier.onBackground();
      await notifier.onForeground();
      notifier.resume();
      expect(harness.network.opened, isEmpty);
      expect(harness.host.ensured, 0);
      await _close(tester);
    });
  });
}
