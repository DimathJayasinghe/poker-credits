import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:poker_credits/config/error_hooks.dart';
import 'package:poker_credits/platform/file_log.dart';
import 'package:poker_credits/platform/single_instance.dart';
import 'package:poker_credits/util/logger.dart';

/// Startup work that must finish before the first frame. Anything thrown here is caught in main()
/// and shown by the init error app (pattern from LocalSend `preInit`).
///
/// Returns the single-instance claim so the app can release it on shutdown. A second desktop
/// launch has already told the first one to show itself and exits here.
Future<InstanceClaim> preInit(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogger(level: args.contains('-v') || args.contains('--verbose') ? Level.ALL : Level.INFO);
  installErrorHooks();
  await installFileLog();
  final claim = await claimSingleInstance();
  if (!claim.isPrimary) claim.exitProcess();
  return claim;
}
