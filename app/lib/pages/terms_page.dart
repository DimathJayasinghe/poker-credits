import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/terms_content.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_credits/widget/guide/guide_widgets.dart';

/// The safety notice. On first launch it has to be accepted ([onAccept] is set). Opened from
/// Settings it is read only, with a back arrow.
class TermsPage extends StatefulWidget {
  /// First-run: the player must agree before going on.
  const TermsPage.accept({super.key, required VoidCallback this.onAccept}) : readOnly = false;

  /// Read from Settings.
  const TermsPage.readOnly({super.key}) : readOnly = true, onAccept = null;

  final bool readOnly;
  final VoidCallback? onAccept;

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _agreed = false;

  /// Closes the app. Where the platform cannot close itself (iOS, the web) nothing happens and the
  /// player simply stays on this page: the app cannot be used without accepting.
  Future<void> _decline() => SystemNavigator.pop();

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    // The notice is a document and scrolls. What the player has to do with it does not: the
    // agree switch and the two buttons stay at the bottom edge, in view the whole time.
    return FitPage(
      title: Strings.termsTitle,
      onBack: widget.readOnly ? () => Navigator.of(context).maybePop() : null,
      maxWidth: 680,
      footerShare: 0.42,
      padding: EdgeInsets.zero,
      footer: widget.readOnly
          ? null
          : (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BrutalSwitchRow(
                  label: Strings.termsAgree,
                  caption: Strings.termsAgreeCaption,
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v),
                ),
                SizedBox(height: info.gap),
                BrutalButton(
                  label: Strings.termsAccept,
                  kind: BrutalButtonKind.primary,
                  heavy: true,
                  minHeight: info.roomy ? BrutalMetrics.tapPlayer : 52,
                  onPressed: _agreed ? widget.onAccept : null,
                ),
                SizedBox(height: info.gap),
                BrutalButton(label: Strings.termsDecline, onPressed: _decline),
              ],
            ),
      builder: (context, info) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              BrutalMetrics.gapL,
              info.roomy ? BrutalMetrics.gapXl : BrutalMetrics.gapM,
              BrutalMetrics.gapL,
              BrutalMetrics.gapM,
            ),
            child: Text(
              Strings.termsIntro,
              style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: BrutalType.body, height: BrutalType.bodyHeight, color: c.muted),
            ),
          ),
          for (final section in termsSections) GuideBlock(title: section.title, body: section.body),
          const SizedBox(height: BrutalMetrics.gapXl),
        ],
      ),
    );
  }
}
