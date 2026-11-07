import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/config/project_links.dart';
import 'package:poker_credits/pages/support_page.dart';
import 'package:poker_credits/platform/external_links.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

Future<FakeExternalLinks> _open(WidgetTester tester, {LinkResult result = LinkResult.opened}) async {
  final links = FakeExternalLinks(result);
  await tester.pumpWidget(
    RefenaScope(
      overrides: [externalLinksProvider.overrideWithValue(links)],
      child: brutalHost(const SupportPage()),
    ),
  );
  await tester.pump();
  return links;
}

void main() {
  setUpAll(loadBrutalFonts);

  test('every project link is a plain https link to GitHub', () {
    for (final url in <Uri>[ProjectLinks.repository, ProjectLinks.profile, ProjectLinks.issues]) {
      expect(url.scheme, 'https');
      expect(url.host, 'github.com');
      expect(url.hasQuery, isFalse);
      expect(url.userInfo, isEmpty);
    }
    expect(ProjectLinks.issues.toString(), startsWith('${ProjectLinks.repository}/'));
  });

  testWidgets('shows the developer, the three actions and a QR code of the repository', (tester) async {
    await _open(tester);
    expect(find.text(Strings.supportTitle.toUpperCase()), findsWidgets);
    expect(find.textContaining('Dimath Jayasinghe'), findsWidgets);
    expect(find.text(Strings.supportStar.toUpperCase()), findsOneWidget);
    expect(find.text(Strings.supportFollow.toUpperCase()), findsOneWidget);
    expect(find.text(Strings.supportIssues.toUpperCase()), findsOneWidget);
    final qr = tester.widget<PrettyQrView>(find.byType(PrettyQrView));
    expect(qr, isNotNull);
    expect(find.text(ProjectLinks.repository.toString()), findsWidgets, reason: 'the address is also shown as text');
  });

  testWidgets('each action opens its own link', (tester) async {
    final links = await _open(tester);
    await tester.tap(find.text(Strings.supportStar.toUpperCase()));
    await tester.pump();
    await tester.tap(find.text(Strings.supportFollow.toUpperCase()));
    await tester.pump();
    await tester.tap(find.text(Strings.supportIssues.toUpperCase()));
    await tester.pump();
    expect(links.requested, <Uri>[ProjectLinks.repository, ProjectLinks.profile, ProjectLinks.issues]);
  });

  testWidgets('when the link could only be copied the page says so', (tester) async {
    await _open(tester, result: LinkResult.copied);
    await tester.tap(find.text(Strings.supportStar.toUpperCase()));
    await tester.pump();
    expect(find.text(Strings.linkCopied.toUpperCase()), findsOneWidget);
  });

  testWidgets('when the link could not be opened or copied the page says so', (tester) async {
    await _open(tester, result: LinkResult.failed);
    await tester.tap(find.text(Strings.supportStar.toUpperCase()));
    await tester.pump();
    expect(find.text(Strings.linkFailed.toUpperCase()), findsOneWidget);
  });
}
