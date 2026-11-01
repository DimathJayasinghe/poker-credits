import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:poker_credits/config/init_error.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'poker_credits',
      packageName: 'dev.pokercredits.poker_credits',
      version: '9.9.9',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  testWidgets('shows the error, stack trace and app version in a copyable report', (tester) async {
    await tester.pumpWidget(InitErrorApp(error: StateError('boom'), stackTrace: StackTrace.fromString('#0 fake frame')));
    await tester.pumpAndSettle();

    final report = tester.widget<SelectableText>(find.byKey(const Key('init-error-report'))).data!;
    expect(report, contains('Bad state: boom'));
    expect(report, contains('#0 fake frame'));
    expect(report, contains('9.9.9 (42)'));
    expect(find.text('STARTUP FAILED'), findsOneWidget);
  });

  testWidgets('copy button puts the report on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(InitErrorApp(error: StateError('boom'), stackTrace: StackTrace.fromString('#0 fake frame')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COPY REPORT'));
    await tester.pumpAndSettle();

    expect(copied, contains('Bad state: boom'));
    expect(find.text('COPIED'), findsOneWidget);
  });
}
