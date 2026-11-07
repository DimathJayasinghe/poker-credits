/// Platform seam: opening the WebSocket to a server (ADR-014, ADR-019).
///
/// Native builds pin the host's certificate; web has no way to (the browser decides) and
/// connects plainly.
library;

export 'secure_channel_stub.dart' if (dart.library.io) 'secure_channel_io.dart';
