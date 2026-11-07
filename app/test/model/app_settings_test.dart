import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_protocol/poker_protocol.dart';
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

    test('the first-run name question: asked until answered, and never asked of someone who got past the intro before it existed', () {
      expect(AppSettings.defaults.nameAsked, isFalse);
      expect(AppSettings.fromJson(<String, Object?>{'acceptedTerms': 1}).nameAsked, isFalse, reason: 'a fresh install is asked');
      expect(AppSettings.fromJson(<String, Object?>{'acceptedTerms': 1, 'introDone': false}).nameAsked, isFalse, reason: 'intro still to come');
      expect(
        AppSettings.fromJson(<String, Object?>{'acceptedTerms': 1, 'introDone': true}).nameAsked,
        isTrue,
        reason: 'an update must not ask long-time players',
      );
      expect(AppSettings.fromJson(<String, Object?>{'defaultName': 'Ana'}).nameAsked, isTrue, reason: 'a name is already set');
      expect(AppSettings.fromJson(<String, Object?>{'introDone': true, 'nameAsked': false}).nameAsked, isFalse, reason: 'an explicit answer wins');
      const asked = AppSettings(acceptedTerms: currentTermsVersion, introDone: true, nameAsked: true);
      expect(AppSettings.fromJson(jsonDecode(jsonEncode(asked.toJson()))), asked);
      expect(asked == asked.copyWith(nameAsked: false), isFalse);
    });

    test('a saved name that the join form would refuse is dropped', () {
      for (final bad in <String>['', '   ', 'a' * 21, 'Dimath!', 'ünï', '<script>']) {
        expect(AppSettings.fromJson(<String, Object?>{'defaultName': bad}).defaultName, '', reason: bad);
      }
      expect(AppSettings.fromJson(<String, Object?>{'defaultName': '  Ana_Maria-2 '}).defaultName, 'Ana_Maria-2');
    });
  });

  group('single-player settings', () {
    test('defaults, and a round trip of choices and records', () {
      expect(AppSettings.defaults.soloBots, 4);
      expect(AppSettings.defaults.soloSkill, BotSkill.normal);
      expect(AppSettings.defaults.soloLength, SoloLength.standard);
      expect(AppSettings.defaults.soloRecords, isEmpty);
      final settings = AppSettings(
        soloBots: 7,
        soloSkill: BotSkill.hard,
        soloLength: SoloLength.long,
        soloRecords: <String, SoloRecord>{soloRecordKey(7, BotSkill.hard): const SoloRecord(played: 3, wins: 1, bestPlace: 1)},
      );
      expect(AppSettings.fromJson(jsonDecode(jsonEncode(settings.toJson()))), settings);
      expect(settings.recordFor(7, BotSkill.hard)?.wins, 1);
      expect(settings.recordFor(7, BotSkill.easy), isNull);
    });

    test('nonsense falls back field by field', () {
      final read = AppSettings.fromJson(<String, Object?>{
        'soloBots': 40,
        'soloSkill': 'godlike',
        'soloLength': 77,
        'soloRecords': <String, Object?>{
          'ok': <String, Object?>{'played': 2, 'wins': 1, 'bestPlace': 1},
          'wins-exceed-played': <String, Object?>{'played': 1, 'wins': 5, 'bestPlace': 1},
          'empty': <String, Object?>{'played': 0},
          'junk': 'x',
        },
      });
      expect(read.soloBots, 4);
      expect(read.soloSkill, BotSkill.normal);
      expect(read.soloLength, SoloLength.standard);
      expect(read.soloRecords.keys, <String>['ok']);
    });

    test('a record keeps the best place and counts only finished games', () {
      var record = const SoloRecord();
      record = record.after(4);
      record = record.after(2);
      record = record.after(3);
      expect((record.played, record.wins, record.bestPlace), (3, 0, 2));
      record = record.after(1);
      expect((record.played, record.wins, record.bestPlace), (4, 1, 1));
    });

    test('equal settings hash alike whatever the order of the records', () {
      const a = SoloRecord(played: 1, wins: 0, bestPlace: 3);
      const b = SoloRecord(played: 2, wins: 1, bestPlace: 1);
      const one = AppSettings(soloRecords: <String, SoloRecord>{'x': a, 'y': b});
      const two = AppSettings(soloRecords: <String, SoloRecord>{'y': b, 'x': a});
      expect(one, two);
      expect(one.hashCode, two.hashCode);
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
