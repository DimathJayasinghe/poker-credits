import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/terms_content.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
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
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: Strings.termsTitle, onBack: widget.readOnly ? () => Navigator.of(context).maybePop() : null),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapXl, BrutalMetrics.gapL, BrutalMetrics.gapL),
                        child: Text(
                          Strings.termsIntro,
                          style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: BrutalType.body, height: BrutalType.bodyHeight, color: c.muted),
                        ),
                      ),
                      for (final section in termsSections) GuideBlock(title: section.title, body: section.body),
                      if (!widget.readOnly) ...<Widget>[
                        Container(height: BrutalMetrics.borderHeavy, color: c.line),
                        BrutalSwitchRow(
                          label: Strings.termsAgree,
                          caption: Strings.termsAgreeCaption,
                          value: _agreed,
                          onChanged: (v) => setState(() => _agreed = v),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(BrutalMetrics.gapL),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              BrutalButton(
                                label: Strings.termsAccept,
                                kind: BrutalButtonKind.primary,
                                heavy: true,
                                minHeight: BrutalMetrics.tapPlayer,
                                onPressed: _agreed ? widget.onAccept : null,
                              ),
                              const SizedBox(height: BrutalMetrics.gapM),
                              BrutalButton(label: Strings.termsDecline, onPressed: _decline),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: BrutalMetrics.gapXxl),
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
