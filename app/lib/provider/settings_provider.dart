import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/platform/settings_store.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The settings read at start-up. `main()` overrides this with what the store held, so the
/// chosen theme is right on the first frame.
final initialSettingsProvider = Provider<AppSettings>((ref) => AppSettings.defaults);

final settingsStoreProvider = Provider<SettingsStore>((ref) => createSettingsStore());

/// The player's preferences. Every change is saved at once.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings init() => ref.read(initialSettingsProvider);

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(state);
    if (next == state) return;
    state = next;
    // Fire and forget: the store never throws and the UI must not wait for the disk.
    ref.read(settingsStoreProvider).write(next);
  }
}
