import 'package:flutter/material.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/platform/qr_scanner.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';

/// Camera view that reads the host's join QR code and pops with the [JoinLink] it carries.
/// The camera comes from the platform seam, so tests and unsupported platforms never load it.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.scanner});

  /// Replaces the platform scanner (tests).
  final QrScannerBuilder? scanner;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _done = false;
  String? _problem;

  void _onCode(String text) {
    if (_done) return;
    final link = JoinLink.tryParse(text);
    if (link == null) {
      if (_problem != Strings.scanNotOurs) setState(() => _problem = Strings.scanNotOurs);
      return;
    }
    _done = true;
    Navigator.of(context).pop(link);
  }

  void _onError(String reason) {
    if (_problem == Strings.scanCameraFailed) return;
    // Called while the scanner builds; show the message after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _problem = Strings.scanCameraFailed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final builder = widget.scanner ?? qrScannerBuilder;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(BrutalMetrics.gapM),
              child: Text(
                Strings.scanTitle.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 28, height: 1.1, color: c.ink),
              ),
            ),
            if (_problem != null) BrutalBanner(message: _problem!, kind: BrutalBannerKind.error),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
                decoration: BoxDecoration(
                  border: Border.all(color: c.ink, width: BrutalMetrics.borderHeavy),
                ),
                child: builder(onCode: _onCode, onError: _onError),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BrutalMetrics.gapM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    Strings.scanHint.toUpperCase(),
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: BrutalMetrics.gapM),
                  BrutalButton(label: Strings.cancel, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
