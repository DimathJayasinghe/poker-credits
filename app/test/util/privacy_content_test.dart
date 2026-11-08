import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/util/privacy_content.dart';

void main() {
  // `PRIVACY.md` is what a store listing links to, so it must say exactly what the app says.
  final published = File('../PRIVACY.md').readAsStringSync();

  test('PRIVACY.md carries every section of the in-app policy word for word', () {
    for (final section in privacySections) {
      expect(published, contains('## ${section.title}\n\n${section.body}\n'), reason: '"${section.title}" differs between the app and PRIVACY.md');
    }
  });

  test('PRIVACY.md has no section the app does not show', () {
    final headings = RegExp(r'^## (.+)$', multiLine: true).allMatches(published).map((m) => m.group(1)).toList();
    expect(headings, privacySections.map((s) => s.title).toList());
  });

  test('both carry the same date', () {
    expect(published, contains('Last updated $privacyUpdated.'));
  });

  test('the policy covers what a store reviewer looks for', () {
    final text = privacySections.map((s) => '${s.title} ${s.body}').join(' ').toLowerCase();
    for (final topic in <String>['collect', 'device', 'camera', 'secure storage', 'tls 1.3', 'children', 'third parties', 'issues']) {
      expect(text, contains(topic), reason: 'the policy should speak about "$topic"');
    }
  });
}
