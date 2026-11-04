/// Platform seam: where the app keeps the player's preferences (ADR-014).
library;

import 'package:poker_credits/model/app_settings.dart';

export 'settings_store_stub.dart' if (dart.library.io) 'settings_store_io.dart';

/// Loads and saves [AppSettings]. Neither call may throw: preferences are a convenience and
/// must never stop the app from starting or a game from being played.
abstract interface class SettingsStore {
  Future<AppSettings> read();
  Future<void> write(AppSettings settings);
}

/// In-memory store (web for now, and tests).
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = AppSettings.defaults]);

  AppSettings value;

  @override
  Future<AppSettings> read() async => value;

  @override
  Future<void> write(AppSettings settings) async => value = settings;
}
