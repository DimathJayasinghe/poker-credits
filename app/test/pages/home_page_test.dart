import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

class _FakeHost implements HostServer {
  const _FakeHost({required this.isSupported});

  @override
  final bool isSupported;
}

Widget _app(HostServer host) => MaterialApp(
  theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
  home: HomePage(hostServer: host),
);

void main() {
  testWidgets('shows the title and protocol version', (tester) async {
    await tester.pumpWidget(_app(const _FakeHost(isSupported: false)));

    expect(find.text('POKER CREDITS'), findsOneWidget);
    expect(find.textContaining('PROTOCOL V1'), findsOneWidget);
  });

  testWidgets('explains why hosting is unavailable and disables the button', (tester) async {
    await tester.pumpWidget(_app(const _FakeHost(isSupported: false)));

    expect(find.text('Hosting is not available on this platform'), findsOneWidget);
  });

  testWidgets('hides the unsupported hint when hosting is supported', (tester) async {
    await tester.pumpWidget(_app(const _FakeHost(isSupported: true)));

    expect(find.text('Hosting is not available on this platform'), findsNothing);
  });
}
