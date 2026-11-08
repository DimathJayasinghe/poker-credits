import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/privacy_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_credits/widget/guide/guide_widgets.dart';

/// The privacy policy, opened from Settings. A read-only document with a back arrow; the same text
/// is published as `PRIVACY.md` (the link a store listing asks for).
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return FitPage(
      title: Strings.privacyTitle,
      onBack: () => Navigator.of(context).maybePop(),
      maxWidth: 680,
      padding: EdgeInsets.zero,
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
              '${Strings.privacyIntro}\n${Strings.privacyUpdatedLine} $privacyUpdated.',
              style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: BrutalType.body, height: BrutalType.bodyHeight, color: c.muted),
            ),
          ),
          for (final section in privacySections) GuideBlock(title: section.title, body: section.body),
          const SizedBox(height: BrutalMetrics.gapXl),
        ],
      ),
    );
  }
}
