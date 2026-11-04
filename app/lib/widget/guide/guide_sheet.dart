import 'package:flutter/material.dart';
import 'package:poker_credits/pages/guide_page.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/guide/guide_widgets.dart';

/// The quick guide: opens over a game screen from the "?" in its top bar, with the hand
/// ranking first because it is what people look up most, then one hand's flow, the words on the
/// buttons and the rules the app keeps. The full guide is one tap away.
Future<void> showGuideSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  return showBrutalSheet<void>(
    context: context,
    title: Strings.guideQuickTitle,
    builder: (sheetContext) => _QuickGuide(
      onOpenFull: () {
        Navigator.of(sheetContext).pop();
        navigator.push(MaterialPageRoute<void>(builder: (_) => const GuidePage()));
      },
    ),
  );
}

enum _Tab { hands, hand, words, rules }

class _QuickGuide extends StatefulWidget {
  const _QuickGuide({required this.onOpenFull});

  final VoidCallback onOpenFull;

  @override
  State<_QuickGuide> createState() => _QuickGuideState();
}

class _QuickGuideState extends State<_QuickGuide> {
  _Tab _tab = _Tab.hands;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BrutalSegmented<_Tab>(
          semanticLabel: Strings.guideQuickTitle,
          value: _tab,
          options: const <(_Tab, String)>[
            (_Tab.hands, Strings.guideTabHands),
            (_Tab.hand, Strings.guideTabHand),
            (_Tab.words, Strings.guideTabWords),
            (_Tab.rules, Strings.guideTabRules),
          ],
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        switch (_tab) {
          _Tab.hands => const GuideHands(),
          _Tab.hand => const GuideSteps(guideHandFlow),
          _Tab.words => const GuideTerms(),
          _Tab.rules => const GuideBullets(guideRules),
        },
        const SizedBox(height: BrutalMetrics.gapM),
        BrutalButton(label: Strings.guideOpenFull, kind: BrutalButtonKind.info, onPressed: widget.onOpenFull),
      ],
    );
  }
}

/// The "?" cell at the right of a game screen's top bar. One tap opens the quick guide.
class GuideCell extends StatelessWidget {
  const GuideCell({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TopBarCell(
        semanticLabel: Strings.guideOpen,
        onTap: () => showGuideSheet(context),
        child: const Text('?', style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 28, height: 1)),
      ),
    );
  }
}
