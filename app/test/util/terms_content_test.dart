import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/terms_content.dart';

void main() {
  // The Microsoft Store rates the app 18+ (simulated gambling), so the notice, the agree switch and
  // the stored version have to say so (docs/MICROSOFT_STORE.md).
  test('the notice starts with the adults-only statement', () {
    final first = termsSections.first;
    expect(first.title, contains('18'));
    expect(first.body, contains('18 or older'));
    expect(first.body, contains('legal age for gambling'));
  });

  test('the agree switch is an age statement', () {
    expect(Strings.termsAgree, contains('18'));
  });

  test('everybody who accepted the older notice is asked again', () {
    expect(currentTermsVersion, greaterThanOrEqualTo(2));
    expect(const AppSettings(acceptedTerms: 1).termsAccepted, isFalse);
  });

  test('no section tells under-age players that real stakes are the only problem', () {
    final text = termsSections.map((s) => s.body).join(' ');
    expect(text, isNot(contains('do not play for real stakes')));
  });
}
