import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/token_store.dart';

final _log = Logger('TokenStore');

/// Session file in the app-private support folder. On Android and iOS that folder is sandboxed
/// per app; on desktop the file is restricted to the owner where the OS allows it.
///
/// `flutter_secure_storage` would be stronger on desktop but needs `libsecret` on Linux; it can
/// replace this class behind the same interface.
TokenStore createTokenStore() => FileTokenStore(() async => (await getApplicationSupportDirectory()).path);

final class FileTokenStore implements TokenStore {
  FileTokenStore(this._folder);

  final Future<String> Function() _folder;

  Future<File> _file() async => File('${await _folder()}${Platform.pathSeparator}session.json');

  @override
  Future<StoredSession?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return StoredSession.fromJson(jsonDecode(await file.readAsString()));
    } on Object catch (error) {
      _log.warning('cannot read the stored session', error);
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      // Write to a temp file and rename so a crash never leaves half a file.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(session.toJson()), flush: true);
      await _restrict(temp);
      await temp.rename(file.path);
    } on Object catch (error) {
      _log.warning('cannot store the session', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      _log.warning('cannot clear the stored session', error);
    }
  }

  Future<void> _restrict(File file) async {
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', <String>['600', file.path]);
    }
  }
}
