/// Platform seam: a rotating log file for bug reports (ADR-014).
library;

export 'file_log_stub.dart' if (dart.library.io) 'file_log_io.dart';
