import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/platform/settings_store.dart';

final _log = Logger('Settings');

/// Preferences in `<application support>/settings.json`.
SettingsStore createSettingsStore() => FileSettingsStore(() async => (await getApplicationSupportDirectory()).path);

/// Writes go to a temporary file that then replaces the real one, so a crash mid-write leaves
/// the old settings intact. Every failure is logged and swallowed.
final class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this._folder);

  final Future<String> Function() _folder;

  Future<File> _file() async => File('${await _folder()}${Platform.pathSeparator}settings.json');

  @override
  Future<AppSettings> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return AppSettings.defaults;
      return AppSettings.fromJson(jsonDecode(await file.readAsString()));
    } on Object catch (error) {
      _log.warning('cannot read the settings, using defaults: ${error.runtimeType}');
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> write(AppSettings settings) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temp.rename(file.path);
    } on Object catch (error) {
      _log.warning('cannot save the settings: ${error.runtimeType}');
    }
  }
}
