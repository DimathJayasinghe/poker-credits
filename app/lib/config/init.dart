import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:poker_credits/config/error_hooks.dart';
import 'package:poker_credits/util/logger.dart';

/// Startup work that must finish before the first frame. Anything thrown here is caught in main()
/// and shown by the init error app (pattern from LocalSend `preInit`).
/// Later phases add persistence, platform seam wiring and the Refena container here.
Future<void> preInit(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogger(level: args.contains('-v') || args.contains('--verbose') ? Level.ALL : Level.INFO);
  installErrorHooks();
}
