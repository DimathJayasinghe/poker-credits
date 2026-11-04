import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/config/error_hooks.dart';
import 'package:poker_credits/config/init.dart';
import 'package:poker_credits/config/init_error.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/platform/settings_store.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:refena_flutter/refena_flutter.dart';

Future<void> main(List<String> args) async {
  // runZonedGuarded is the last net for async errors (docs/RESILIENCE_AND_CRASH_HANDLING.md 2.2).
  await runZonedGuarded<Future<void>>(() async {
    try {
      await preInit(args);
    } catch (e, st) {
      showInitErrorApp(error: e, stackTrace: st);
      return;
    }
    // Preferences load before the first frame so the chosen theme never flashes. A missing or
    // damaged file gives defaults (the store never throws).
    final settings = await createSettingsStore().read();
    runApp(RefenaScope(overrides: [initialSettingsProvider.overrideWithValue(settings)], child: const PokerCreditsApp()));
  }, onZoneError);
}

class PokerCreditsApp extends StatelessWidget {
  const PokerCreditsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
      darkTheme: buildBrutalTheme(BrutalColors.dark, Brightness.dark),
      themeMode: switch (settings.theme) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      builder: (context, child) => BrutalTexture(enabled: settings.texture, child: child ?? const SizedBox.shrink()),
      home: const HomePage(),
    );
  }
}
