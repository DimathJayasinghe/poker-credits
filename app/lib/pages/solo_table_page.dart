import 'package:flutter/material.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/provider/solo_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The table of a single-player game. It pauses the game when the app leaves the foreground, so
/// the computer players never play while the screen is off, and wakes the connection on return.
class SoloTablePage extends StatefulWidget {
  const SoloTablePage({super.key});

  @override
  State<SoloTablePage> createState() => _SoloTablePageState();
}

class _SoloTablePageState extends State<SoloTablePage> with Refena, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        ref.notifier(soloProvider).onBackground();
      case AppLifecycleState.resumed:
        ref.notifier(soloProvider).onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => const PlayerPage();
}
