import 'package:poker_credits/platform/settings_store.dart';

/// Web: preferences live in memory until a browser store is added with the web build.
SettingsStore createSettingsStore() => MemorySettingsStore();
