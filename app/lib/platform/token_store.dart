/// Platform seam: where the app keeps the session of the room it is in (ADR-014).
library;

import 'package:poker_credits/model/hosting.dart';

export 'token_store_stub.dart' if (dart.library.io) 'token_store_io.dart';

/// Which saved session a call is about. A single-player game has its own slot so starting or
/// leaving one never touches the hosted or joined game saved in [main], and the other way round.
enum TokenSlot { main, solo }

/// Keeps one [StoredSession] per [TokenSlot] so the app can re-attach after it was killed. Tokens
/// are secrets: implementations keep them app-private and never log them.
abstract interface class TokenStore {
  Future<StoredSession?> read({TokenSlot slot = TokenSlot.main});
  Future<void> write(StoredSession session, {TokenSlot slot = TokenSlot.main});
  Future<void> clear({TokenSlot slot = TokenSlot.main});
}

/// In-memory store (web for now, and tests).
class MemoryTokenStore implements TokenStore {
  final Map<TokenSlot, StoredSession> _sessions = <TokenSlot, StoredSession>{};

  @override
  Future<StoredSession?> read({TokenSlot slot = TokenSlot.main}) async => _sessions[slot];

  @override
  Future<void> write(StoredSession session, {TokenSlot slot = TokenSlot.main}) async => _sessions[slot] = session;

  @override
  Future<void> clear({TokenSlot slot = TokenSlot.main}) async => _sessions.remove(slot);
}
