import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/config/error_hooks.dart';
import 'package:poker_credits/config/init.dart';
import 'package:poker_credits/config/init_error.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
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
    runApp(RefenaScope(child: const PokerCreditsApp()));
  }, onZoneError);
}

class PokerCreditsApp extends StatelessWidget {
  const PokerCreditsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
      darkTheme: buildBrutalTheme(BrutalColors.dark, Brightness.dark),
      home: const HomePage(),
    );
  }
}
