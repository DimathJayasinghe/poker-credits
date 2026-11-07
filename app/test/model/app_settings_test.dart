import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/platform/settings_store_io.dart';

void main() {
  group('AppSettings.fromJson', () {
    test('round trips', () {
      const settings = AppSettings(theme: ThemeChoice.dark, texture: false, sound: false, vibration: false, keepAwake: false, defaultName: 'Dimath');
      expect(AppSettings.fromJson(jsonDecode(jsonEncode(settings.toJson()))), settings);
    });

    test('the card options round trip and default to off', () {
      expect(AppSettings.defaults.fourColourDeck, isFalse);
      expect(AppSettings.defaults.cardsFaceUp, isFalse, reason: 'a glance from the next seat must show nothing');
      const settings = AppSettings(fourColourDeck: true, cardsFaceUp: true);
      expect(AppSettings.fromJson(jsonDecode(jsonEncode(settings.toJson()))), settings);
      expect(AppSettings.fromJson(<String, Object?>{'fourColourDeck': 'yes', 'cardsFaceUp': 1}), AppSettings.defaults);
    });

    test('first-run state: terms are not accepted and the intro not seen until the player says so', () {
      expect(AppSettings.defaults.acceptedTerms, 0);
      expect(AppSettings.defaults.termsAccepted, isFalse);
      expect(AppSettings.defaults.introDone, isFalse);
      const accepted = AppSettings(acceptedTerms: currentTermsVersion, introDone: true);
      expect(accepted.termsAccepted, isTrue);
      expect(AppSettings.fromJson(jsonDecode(jsonEncode(accepted.toJson()))), accepted);
    });

    test('terms accepted for an older version have to be accepted again', () {
      expect(const AppSettings(acceptedTerms: currentTermsVersion - 1).termsAccepted, isFalse);
      expect(const AppSettings(acceptedTerms: currentTermsVersion + 1).termsAccepted, isTrue);
    });

    test('a damaged terms or intro value never counts as accepted', () {
      for (final junk in <Object?>['1', -3, 1.5, null, true, <Object?>[]]) {
        final settings = AppSettings.fromJson(<String, Object?>{'acceptedTerms': junk});
        expect(settings.termsAccepted, isFalse, reason: '$junk');
      }
      for (final junk in <Object?>['yes', 1, null, <Object?>[]]) {
        final settings = AppSettings.fromJson(<String, Object?>{'introDone': junk});
        expect(settings.introDone, isFalse, reason: '$junk');
      }
    });

    test('anything that is not an object gives the defaults', () {
      for (final junk in <Object?>[null, 'text', 42, <Object?>[], true]) {
        expect(AppSettings.fromJson(junk), AppSettings.defaults, reason: '$junk');
      }
    });

    test('a field of the wrong type falls back for that field only', () {
      final settings = AppSettings.fromJson(<String, Object?>{
        'theme': 7,
        'texture': 'yes',
        'sound': false,
        'vibration': null,
        'keepAwake': 0,
        'defaultName': 12,
      });
      expect(settings, const AppSettings(sound: false));
    });

    test('an unknown theme name falls back to system', () {
      expect(AppSettings.fromJson(<String, Object?>{'theme': 'neon'}).theme, ThemeChoice.system);
    });

    test('a saved name that the join form would refuse is dropped', () {
      for (final bad in <String>['', '   ', 'a' * 21, 'Dimath!', 'ünï', '<script>']) {
        expect(AppSettings.fromJson(<String, Object?>{'defaultName': bad}).defaultName, '', reason: bad);
      }
      expect(AppSettings.fromJson(<String, Object?>{'defaultName': '  Ana_Maria-2 '}).defaultName, 'Ana_Maria-2');
    });
  });

  group('FileSettingsStore', () {
    late Directory dir;
    late FileSettingsStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('settings_test');
      store = FileSettingsStore(() async => dir.path);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    File file() => File('${dir.path}/settings.json');

    test('a missing file gives the defaults', () async {
      expect(await store.read(), AppSettings.defaults);
    });

    test('what was written is read back', () async {
      const settings = AppSettings(theme: ThemeChoice.light, defaultName: 'Bob');
      await store.write(settings);
      expect(await store.read(), settings);
      expect(File('${file().path}.tmp').existsSync(), isFalse, reason: 'the temporary file is renamed away');
    });

    test('a damaged file gives the defaults and never throws', () async {
      for (final junk in <String>['{not json', '', '\u0000\u0001', '[1,2,3]', '"just a string"', '{"theme": {"deep": [1]}}']) {
        file().writeAsStringSync(junk);
        expect(await store.read(), AppSettings.defaults, reason: junk);
      }
    });

    test('a folder that cannot be written does not throw', () async {
      final blocked = FileSettingsStore(() async => '${dir.path}/settings.json/nowhere');
      file().writeAsStringSync('x');
      await blocked.write(const AppSettings(sound: false));
      expect(await blocked.read(), AppSettings.defaults);
    });
  });
}
