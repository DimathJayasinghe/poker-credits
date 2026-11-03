import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

const int _maxBytes = 1024 * 1024;

/// Appends every log record to `<support>/logs/poker_credits.log`; at 1 MB the file is moved to
/// `.1` (one old file is kept). Never throws: logging must not break startup.
Future<void> installFileLog({Future<String> Function()? folder}) async {
  try {
    final base = folder != null ? await folder() : (await getApplicationSupportDirectory()).path;
    final dir = Directory('$base${Platform.pathSeparator}logs');
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}poker_credits.log');
    if (await file.exists() && await file.length() > _maxBytes) {
      await file.rename('${file.path}.1');
    }
    final sink = file.openWrite(mode: FileMode.append);
    Logger.root.onRecord.listen((record) {
      final buffer = StringBuffer('${record.time.toIso8601String()} [${record.level.name}] [${record.loggerName}] ${record.message}');
      if (record.error != null) buffer.write(' | ${record.error}');
      if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
      sink.writeln(buffer);
    });
  } on Object catch (error) {
    stderr.writeln('file log unavailable: $error');
  }
}
