import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/token_store.dart';

import 'package:poker_credits/widget/brutal/echo_title.dart';
import 'package:poker_credits/widget/brutal/felt_panel.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

Widget _app(TestHarness harness) => harness.scope(const PokerCreditsApp());

void main() {
  testWidgets('shows the title, the two ways in and the navigation', (tester) async {
    await tester.pumpWidget(_app(TestHarness()));
    await tester.pump();

    expect(find.byType(EchoTitle), findsOneWidget);
    expect(find.bySemanticsLabel('Poker Credits'), findsWidgets);
    expect(find.text('HOST A GAME'), findsOneWidget);
    expect(find.text('JOIN A GAME'), findsOneWidget);
    expect(find.text('PLAY'), findsWidgets);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('explains why hosting is unavailable', (tester) async {
    await tester.pumpWidget(_app(TestHarness(host: FakeHostServer(supported: false))));
    await tester.pump();

    expect(find.text('Hosting is not available on this platform'), findsOneWidget);
  });

  testWidgets('hides the unsupported hint when hosting is supported', (tester) async {
    await tester.pumpWidget(_app(TestHarness()));
    await tester.pump();

    expect(find.text('Hosting is not available on this platform'), findsNothing);
  });

  testWidgets('offers to resume a game this device was hosting', (tester) async {
    final tokens = MemoryTokenStore();
    await tokens.write(
      const StoredSession(serverUri: 'ws://127.0.0.1:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 's', hostToken: 'h'),
    );
    await tester.pumpWidget(_app(TestHarness(tokens: tokens)));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('RESUME HOSTED GAME KQ7M'), findsOneWidget);
  });

  testWidgets('a stored player session is not offered as hosting', (tester) async {
    final tokens = MemoryTokenStore();
    await tokens.write(const StoredSession(serverUri: 'wss://10.0.0.2:7878/v1/ws#pin=$testPin', roomCode: 'KQ7M', sessionToken: 's'));
    await tester.pumpWidget(_app(TestHarness(tokens: tokens)));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('RESUME HOSTED GAME'), findsNothing);
  });

  group('layout', () {
    Future<void> pumpAt(WidgetTester tester, Size size, {double textScale = 1, TestHarness? harness}) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: (harness ?? TestHarness()).scope(const PokerCreditsApp()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    setUpAll(loadBrutalFonts);

    testWidgets('phone: single column with a bottom bar and the felt band under the actions', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);
      expect(find.byType(FeltPanel), findsOneWidget);
      final bar = tester.getTopLeft(find.text('SETTINGS')).dy;
      expect(bar, greaterThan(700), reason: 'navigation sits at the bottom');
    });

    testWidgets('wide: navigation moves to a left rail and the felt panel takes the right side', (tester) async {
      await pumpAt(tester, const Size(1280, 800));
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.text('SETTINGS')).dx, lessThan(260), reason: 'rail on the left');
      expect(tester.getTopLeft(find.byType(FeltPanel)).dx, greaterThan(600));
    });

    for (final scale in <double>[1.0, 1.5, 2.0, 3.0]) {
      for (final size in <Size>[const Size(320, 640), const Size(390, 844), const Size(1280, 800)]) {
        testWidgets('no overflow at text scale $scale on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          final tokens = MemoryTokenStore();
          await tokens.write(const StoredSession(serverUri: 'ws://127.0.0.1:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 's', hostToken: 'h'));
          await pumpAt(
            tester,
            size,
            textScale: scale,
            harness: TestHarness(tokens: tokens),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('SETTINGS').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
