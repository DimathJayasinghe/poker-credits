import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/main.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/token_store.dart';

import '../support/fakes.dart';

Widget _app(TestHarness harness) => harness.scope(const PokerCreditsApp());

void main() {
  testWidgets('shows the title and protocol version', (tester) async {
    await tester.pumpWidget(_app(TestHarness(host: FakeHostServer(supported: false))));
    await tester.pump();

    expect(find.text('POKER CREDITS'), findsOneWidget);
    expect(find.textContaining('PROTOCOL V1'), findsOneWidget);
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
    await tokens.write(const StoredSession(serverUri: 'ws://10.0.0.2:7878/v1/ws', roomCode: 'KQ7M', sessionToken: 's'));
    await tester.pumpWidget(_app(TestHarness(tokens: tokens)));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('RESUME HOSTED GAME'), findsNothing);
  });
}
