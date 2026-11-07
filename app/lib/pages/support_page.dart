import 'package:flutter/material.dart';
import 'package:poker_credits/config/project_links.dart';
import 'package:poker_credits/platform/external_links.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Who made the app and three ways to help: star the project, follow the developer, report a
/// bug. A QR code of the repository lets a second phone open it when this one cannot.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> with Refena {
  LinkResult? _last;

  Future<void> _open(Uri url) async {
    final result = await ref.read(externalLinksProvider).open(url);
    if (!mounted) return;
    setState(() => _last = result);
  }

  /// The address as a QR code in a sheet, for a page too short to carry it.
  void _showCode() {
    showBrutalSheet<void>(
      context: context,
      title: Strings.supportScan,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height;
        return Padding(
          padding: const EdgeInsets.all(BrutalMetrics.gapM),
          child: _RepoCode(url: ProjectLinks.repository, size: (height - 220).clamp(110.0, 168.0), showTitle: false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return FitPage(
      title: Strings.supportTitle,
      onBack: () => Navigator.of(context).maybePop(),
      maxWidth: 640,
      compactBelow: 900,
      tightBelow: 560,
      padding: EdgeInsets.zero,
      builder: (context, info) {
        final header = FitHeader(
          info: info,
          headline: Strings.supportHeadline,
          body: Strings.supportBody,
          bodyShort: Strings.supportBodyShort,
          bodyTiny: Strings.supportBodyTiny,
        );
        // Without room for captions each row is its label alone; the label says what it does.
        final captions = !info.tight;
        final rows = <Widget>[
          if (_last == LinkResult.copied) const BrutalBanner(message: Strings.linkCopied),
          if (_last == LinkResult.failed) const BrutalBanner(message: Strings.linkFailed, kind: BrutalBannerKind.error),
          _Hairline(c.line),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.supportStar,
            caption: captions ? Strings.supportStarCaption : null,
            emphasis: true,
            onTap: () => _open(ProjectLinks.repository),
          ),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.supportFollow,
            caption: captions ? Strings.supportFollowCaption : null,
            onTap: () => _open(ProjectLinks.profile),
          ),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.supportIssues,
            caption: captions ? Strings.supportIssuesCaption : null,
            onTap: () => _open(ProjectLinks.issues),
          ),
          if (!info.roomy)
            BrutalRow(
              dense: true,
              snug: true,
              label: Strings.supportShowCode,
              caption: captions ? Strings.supportShowCodeCaption : null,
              onTap: _showCode,
            ),
        ];
        final thanks = Padding(
          padding: EdgeInsets.symmetric(vertical: info.roomy ? BrutalMetrics.gapL : BrutalMetrics.gapM),
          child: Center(
            child: Text(
              Strings.supportThanks.toUpperCase(),
              style: TextStyle(fontFamily: BrutalFonts.display, fontSize: info.roomy ? 22 : 18, letterSpacing: 1, color: c.ink),
            ),
          ),
        );
        if (info.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[header, thanks]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            ...rows,
            if (info.roomy)
              Padding(
                padding: const EdgeInsets.all(BrutalMetrics.gapL),
                child: _RepoCode(url: ProjectLinks.repository),
              ),
            thanks,
          ],
        );
      },
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: BrutalMetrics.border, color: color);
}

/// The repository address as a QR code and as text. The code is always dark on light paper,
/// in both themes, so every scanner can read it.
class _RepoCode extends StatelessWidget {
  const _RepoCode({required this.url, this.size = 168, this.showTitle = true});

  final Uri url;
  final double size;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showTitle) ...<Widget>[
          Text(
            Strings.supportScan.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.muted),
          ),
          const SizedBox(height: BrutalMetrics.gapM),
        ],
        Semantics(
          label: Strings.supportScan,
          image: true,
          child: Container(
            color: BrutalColors.light.paper,
            padding: const EdgeInsets.all(BrutalMetrics.gapM),
            child: SizedBox(
              width: size,
              height: size,
              child: PrettyQrView.data(
                data: url.toString(),
                decoration: PrettyQrDecoration(shape: PrettyQrSquaresSymbol(color: BrutalColors.light.ink)),
              ),
            ),
          ),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        // The address is selectable text of its own, so it can be typed from another screen.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SelectableText(
            url.toString(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 13, color: c.ink),
          ),
        ),
      ],
    );
  }
}
