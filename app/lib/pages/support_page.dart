import 'package:flutter/material.dart';
import 'package:poker_credits/config/project_links.dart';
import 'package:poker_credits/platform/external_links.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: Strings.supportTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapXl, BrutalMetrics.gapL, BrutalMetrics.gapL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Semantics(
                              header: true,
                              child: Text(
                                Strings.supportHeadline.toUpperCase(),
                                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: BrutalType.headline, height: 1.05, color: c.ink),
                              ),
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            Text(
                              Strings.supportBody,
                              style: TextStyle(
                                fontFamily: BrutalFonts.mono,
                                fontSize: BrutalType.body,
                                height: BrutalType.bodyHeight,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_last == LinkResult.copied) const BrutalBanner(message: Strings.linkCopied),
                      if (_last == LinkResult.failed) const BrutalBanner(message: Strings.linkFailed, kind: BrutalBannerKind.error),
                      _Hairline(c.line),
                      BrutalRow(
                        dense: true,
                        label: Strings.supportStar,
                        caption: Strings.supportStarCaption,
                        emphasis: true,
                        onTap: () => _open(ProjectLinks.repository),
                      ),
                      BrutalRow(
                        dense: true,
                        label: Strings.supportFollow,
                        caption: Strings.supportFollowCaption,
                        onTap: () => _open(ProjectLinks.profile),
                      ),
                      BrutalRow(
                        dense: true,
                        label: Strings.supportIssues,
                        caption: Strings.supportIssuesCaption,
                        onTap: () => _open(ProjectLinks.issues),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(BrutalMetrics.gapL),
                        child: _RepoCode(url: ProjectLinks.repository),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: BrutalMetrics.gapXxl),
                        child: Center(
                          child: Text(
                            Strings.supportThanks.toUpperCase(),
                            style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 22, letterSpacing: 1, color: c.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
  const _RepoCode({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          Strings.supportScan.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.muted),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        Semantics(
          label: Strings.supportScan,
          image: true,
          child: Container(
            color: BrutalColors.light.paper,
            padding: const EdgeInsets.all(BrutalMetrics.gapM),
            child: SizedBox(
              width: 168,
              height: 168,
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
