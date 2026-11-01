import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';

final Logger _log = Logger('Init');

/// Replaces the app with a minimal error screen when startup fails, showing a copyable report
/// with the app version (pattern from LocalSend `showInitErrorApp`).
void showInitErrorApp({required Object error, required StackTrace stackTrace}) {
  _log.severe('Error during init', error, stackTrace);
  runApp(InitErrorApp(error: error, stackTrace: stackTrace));
}

class InitErrorApp extends StatelessWidget {
  const InitErrorApp({super.key, required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
      home: _InitErrorPage(error: error, stackTrace: stackTrace),
    );
  }
}

class _InitErrorPage extends StatefulWidget {
  const _InitErrorPage({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  State<_InitErrorPage> createState() => _InitErrorPageState();
}

class _InitErrorPageState extends State<_InitErrorPage> {
  String _version = 'unknown version';
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (e, st) {
      // The report is still useful without a version; log and keep the fallback.
      _log.warning('Reading package info failed', e, st);
    }
  }

  String get _report => '${Strings.appName} $_version\n\nError: ${widget.error}\n\n${widget.stackTrace}';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrutalMetrics.gapM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                Strings.initErrorTitle.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 32, color: c.danger),
              ),
              const SizedBox(height: BrutalMetrics.gapS),
              Text(Strings.initErrorHint, style: TextStyle(color: c.muted)),
              const SizedBox(height: BrutalMetrics.gapM),
              Expanded(
                child: BrutalCard(
                  header: 'Report',
                  child: SingleChildScrollView(child: SelectableText(_report, key: const Key('init-error-report'))),
                ),
              ),
              const SizedBox(height: BrutalMetrics.gapM),
              BrutalButton(label: _copied ? Strings.copied : Strings.copy, onPressed: _copy, kind: BrutalButtonKind.primary, heavy: true),
            ],
          ),
        ),
      ),
    );
  }
}
