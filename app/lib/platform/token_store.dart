/// Platform seam: where the app keeps the session of the room it is in (ADR-014).
library;

import 'package:poker_credits/model/hosting.dart';

export 'token_store_stub.dart' if (dart.library.io) 'token_store_io.dart';

/// Keeps one [StoredSession] so the app can re-attach after it was killed. Tokens are secrets:
/// implementations keep them app-private and never log them.
abstract interface class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

/// In-memory store (web for now, and tests).
class MemoryTokenStore implements TokenStore {
  StoredSession? _session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> write(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
