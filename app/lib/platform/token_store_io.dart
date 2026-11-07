import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/token_store.dart';

final _log = Logger('TokenStore');

/// The session tokens are bearer secrets, so they go into the operating system's secure store:
/// Android Keystore, iOS and macOS Keychain, Windows Credential Locker (DPAPI) and the Secret
/// Service keyring on Linux. There is deliberately no plain-file fallback: if the store is
/// unavailable the session is simply not remembered and the host starts a new game.
TokenStore createTokenStore() => const SecureTokenStore(
  FlutterSecureStorage(
    // The legacy macOS keychain needs no `keychain-access-groups` entitlement or provisioning
    // profile, and the app shares nothing with other apps.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    // Never copy the secrets into iCloud Keychain or a device backup.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  ),
);

final class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  static const String _mainKey = 'poker_credits.session.v1';
  static const String _soloKey = 'poker_credits.solo.v1';

  static String _key(TokenSlot slot) => switch (slot) {
    TokenSlot.main => _mainKey,
    TokenSlot.solo => _soloKey,
  };

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read({TokenSlot slot = TokenSlot.main}) async {
    try {
      final raw = await _storage.read(key: _key(slot));
      if (raw == null) return null;
      return StoredSession.fromJson(jsonDecode(raw));
    } on Object catch (error) {
      // Never log the value itself.
      _log.warning('cannot read the stored session: ${error.runtimeType}');
      await clear(slot: slot);
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session, {TokenSlot slot = TokenSlot.main}) async {
    try {
      await _storage.write(key: _key(slot), value: jsonEncode(session.toJson()));
    } on Object catch (error) {
      _log.warning('cannot store the session: ${error.runtimeType}');
    }
  }

  @override
  Future<void> clear({TokenSlot slot = TokenSlot.main}) async {
    try {
      await _storage.delete(key: _key(slot));
    } on Object catch (error) {
      _log.warning('cannot clear the stored session: ${error.runtimeType}');
    }
  }
}
