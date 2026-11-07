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

  testWidgets('a release build shows a short error ID and none of the error text or the trace', (tester) async {
    await tester.pumpWidget(
      InitErrorApp(error: StateError('secret path /home/x'), stackTrace: StackTrace.fromString('#0 fake frame /home/x/app.dart'), showDetails: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('init-error-report')), findsNothing);
    final shown = tester.widget<SelectableText>(find.byKey(const Key('init-error-id'))).data!;
    expect(shown, contains('9.9.9 (42)'));
    expect(shown, matches(RegExp(r'Error ID: [0-9A-F]{8}')));
    expect(shown, isNot(contains('secret')));
    expect(shown, isNot(contains('/home/x')));
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('COPY TECHNICAL DETAILS'), findsOneWidget);
  });

  testWidgets('the error ID is the same for the same failure and differs for another', (tester) async {
    Future<String> idOf(Object error, String trace) async {
      await tester.pumpWidget(InitErrorApp(error: error, stackTrace: StackTrace.fromString(trace), showDetails: false));
      await tester.pumpAndSettle();
      final text = tester.widget<SelectableText>(find.byKey(const Key('init-error-id'))).data!;
      return RegExp(r'Error ID: ([0-9A-F]{8})').firstMatch(text)!.group(1)!;
    }

    final a = await idOf(StateError('one'), '#0 frame a');
    expect(await idOf(StateError('two'), '#0 frame a'), a, reason: 'the message is not part of the ID');
    expect(await idOf(StateError('one'), '#0 frame b'), isNot(a));
    expect(await idOf(ArgumentError('x'), '#0 frame a'), isNot(a));
  });

  testWidgets('in a release build the full report is copied only on request', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(InitErrorApp(error: StateError('boom'), stackTrace: StackTrace.fromString('#0 fake frame'), showDetails: false));
    await tester.pumpAndSettle();
    expect(copied, isNull);
    await tester.tap(find.text('COPY TECHNICAL DETAILS'));
    await tester.pumpAndSettle();
    expect(copied, allOf(contains('Bad state: boom'), contains('#0 fake frame'), contains('Error ID:')));
  });
}
