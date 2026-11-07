import 'package:flutter/foundation.dart';
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
  /// [showDetails] puts the error text and the stack trace on screen. It defaults to debug and
  /// profile builds: in a release build the screen shows only a short error ID, and the full report
  /// is copied only when the person asks for it.
  const InitErrorApp({super.key, required this.error, required this.stackTrace, this.showDetails = !kReleaseMode});

  final Object error;
  final StackTrace stackTrace;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(BrutalColors.light, Brightness.light),
      home: _InitErrorPage(error: error, stackTrace: stackTrace, showDetails: showDetails),
    );
  }
}

class _InitErrorPage extends StatefulWidget {
  const _InitErrorPage({required this.error, required this.stackTrace, required this.showDetails});

  final Object error;
  final StackTrace stackTrace;
  final bool showDetails;

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

  /// A short code for this failure: the error's type and the first line of its trace, hashed (FNV-1a).
  /// It tells two reports apart without carrying a path, an address or any message text.
  String get _errorId {
    final firstFrame = widget.stackTrace.toString().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    var hash = 0x811c9dc5;
    for (final unit in '${widget.error.runtimeType}|$firstFrame'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  String get _report => '${Strings.appName} $_version\nError ID: $_errorId\n\nError: ${widget.error}\n\n${widget.stackTrace}';

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
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 32, color: c.ink),
              ),
              const SizedBox(height: BrutalMetrics.gapS),
              Text(widget.showDetails ? Strings.initErrorHint : Strings.initErrorHintRelease, style: TextStyle(color: c.muted)),
              const SizedBox(height: BrutalMetrics.gapM),
              Expanded(
                child: BrutalCard(
                  header: widget.showDetails ? 'Report' : Strings.initErrorIdHeader,
                  child: SingleChildScrollView(
                    child: widget.showDetails
                        ? SelectableText(_report, key: const Key('init-error-report'))
                        : SelectableText('${Strings.appName} $_version\n${Strings.initErrorIdLabel}: $_errorId', key: const Key('init-error-id')),
                  ),
                ),
              ),
              const SizedBox(height: BrutalMetrics.gapM),
              BrutalButton(
                label: _copied ? Strings.copied : (widget.showDetails ? Strings.copy : Strings.copyTechnical),
                onPressed: _copy,
                kind: BrutalButtonKind.primary,
                heavy: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
