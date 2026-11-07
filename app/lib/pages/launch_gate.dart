import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/pages/home_page.dart';
import 'package:poker_credits/pages/splash_page.dart';
import 'package:poker_credits/pages/terms_page.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// What the app shows before Home: the loading screen, then the safety notice until the current
/// version of it has been accepted. Which screen is up is worked out from the saved settings each
/// time, so a notice that was accepted can never be skipped by being on the wrong step.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> with Refena {
  bool _splashDone = false;
  bool _started = false;
  Timer? _timer;
  Duration _splash = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final settings = ref.read(settingsProvider);
    final full = ref.read(splashDurationProvider);
    // Someone who has been here before gets a shorter wait.
    _splash = settings.termsAccepted ? full ~/ 2 : full;
    if (_splash == Duration.zero) {
      _splashDone = true;
    } else {
      _timer = Timer(_splash, _finishSplash);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishSplash() {
    _timer?.cancel();
    if (mounted && !_splashDone) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
    if (!_splashDone) return SplashView(duration: _splash, onSkip: _finishSplash);
    if (!settings.termsAccepted) {
      return TermsPage.accept(onAccept: () => ref.notifier(settingsProvider).update((s) => s.copyWith(acceptedTerms: currentTermsVersion)));
    }
    return const HomePage();
  }
}
