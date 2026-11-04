import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/pages/scan_page.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';

import '../support/test_app.dart';

Widget _fakeCamera({required void Function(String text) onCode, required void Function(String reason) onError}) =>
    TextButton(onPressed: () => onCode('not a poker code'), child: const Text('fake camera'));

void main() {
  setUpAll(loadBrutalFonts);

  testWidgets('the scan page has a back arrow that returns without a code', (tester) async {
    JoinLink? result = const JoinLink(hostAndPort: 'x:1', roomCode: 'ABCD');
    await tester.pumpWidget(
      brutalHost(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await Navigator.of(
                  context,
                ).push<JoinLink>(MaterialPageRoute<JoinLink>(builder: (_) => const ScanPage(scanner: _fakeCamera)));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.byType(BackCell), findsOneWidget);
    await tester.tap(find.byType(BackCell));
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsNothing);
    expect(result, isNull);
  });

  testWidgets('a code that is not ours is explained and the page stays', (tester) async {
    await tester.pumpWidget(brutalHost(const ScanPage(scanner: _fakeCamera)));
    await tester.tap(find.text('fake camera'));
    await tester.pump();
    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.textContaining('NOT'), findsWidgets);
  });
}
