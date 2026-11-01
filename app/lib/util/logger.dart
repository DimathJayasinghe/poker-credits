import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Last log lines kept in memory for the "Copy diagnostics" action. Web-safe (no files).
/// A rotating log file is added behind the platform seam in Phase 4.
final class DiagnosticsBuffer {
  DiagnosticsBuffer._();

  static final DiagnosticsBuffer instance = DiagnosticsBuffer._();

  static const int capacity = 200;
  final Queue<String> _lines = Queue<String>();

  List<String> get lines => List<String>.unmodifiable(_lines);

  void add(String line) {
    _lines.addLast(line);
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
  }

  void clear() => _lines.clear();
}

bool _loggerInitialised = false;

/// Configures root logging once: console output plus the in-memory diagnostics buffer.
void initLogger({Level level = Level.INFO}) {
  Logger.root.level = level;
  if (_loggerInitialised) return;
  _loggerInitialised = true;
  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer('${record.time.toIso8601String()} [${record.level.name}] [${record.loggerName}] ${record.message}');
    if (record.error != null) buffer.write('\n${record.error}');
    if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
    final line = buffer.toString();
    DiagnosticsBuffer.instance.add(line);
    debugPrint(line);
  });
}
