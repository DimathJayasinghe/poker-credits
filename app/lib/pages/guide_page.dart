import 'package:flutter/material.dart';
import 'package:poker_credits/pages/support_page.dart';
import 'package:poker_credits/pages/tours.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/guide/guide_widgets.dart';

/// The Guide as its own route (opened from a game screen's quick guide): the same content as the
/// Guide tab, with a back arrow.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) => PaperScaffold(body: GuideView(onBack: () => Navigator.of(context).maybePop()));
}

/// Everything a beginner needs to sit down at a table: how the night works with this app, the
/// ranked hands, how a hand plays, the words on the buttons, the rules the app keeps and what to
/// do when the connection drops. Static text; works offline.
class GuideView extends StatefulWidget {
  const GuideView({super.key, this.onBack});

  /// When set the top bar shows a back arrow (the route version).
  final VoidCallback? onBack;

  @override
  State<GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends State<GuideView> {
  final GlobalKey _hands = GlobalKey();
  final GlobalKey _flow = GlobalKey();
  final GlobalKey _cards = GlobalKey();
  final GlobalKey _words = GlobalKey();
  final GlobalKey _rules = GlobalKey();
  final GlobalKey _drops = GlobalKey();
  final GlobalKey _safety = GlobalKey();

  void _jump(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: BrutalTheme.duration(context, BrutalMetrics.max), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTopBar(title: Strings.guideTitle, onBack: widget.onBack),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              Strings.guideIntro.toUpperCase(),
                              style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 44, height: 1, color: c.ink),
                            ),
                          ),
                          const SizedBox(height: BrutalMetrics.gapM),
                          Text(
                            Strings.guideIntroBody,
                            style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 14, height: 1.5, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    // The two walkthroughs come straight after the headline that promises them.
                    BrutalRow(
                      label: Strings.guideLearnRow,
                      caption: Strings.guideLearnRowCaption,
                      emphasis: true,
                      onTap: () => openLesson(context),
                    ),
                    BrutalRow(label: Strings.guideTourRow, caption: Strings.guideTourRowCaption, onTap: () => openAppTour(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            Strings.guideJump.toUpperCase(),
                            style: TextStyle(
                              fontFamily: BrutalFonts.mono,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 2,
                              color: c.muted,
                            ),
                          ),
                          const SizedBox(height: BrutalMetrics.gapS),
                          Wrap(
                            spacing: BrutalMetrics.gapS,
                            runSpacing: BrutalMetrics.gapS,
                            children: <Widget>[
                              _Jump(Strings.guideTabHands, () => _jump(_hands)),
                              _Jump(Strings.guideTabHand, () => _jump(_flow)),
                              _Jump(Strings.guideTabCards, () => _jump(_cards)),
                              _Jump(Strings.guideTabWords, () => _jump(_words)),
                              _Jump(Strings.guideTabRules, () => _jump(_rules)),
                              _Jump(Strings.guideTabDrops, () => _jump(_drops)),
                              _Jump(Strings.guideTabSafety, () => _jump(_safety)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const GuideHeading(Strings.guideSectionNight),
                    const GuideSteps(guideNight),
                    GuideHeading(Strings.guideSectionHands, key: _hands, intro: Strings.guideHandsIntro),
                    const GuideHands(),
                    GuideHeading(Strings.guideSectionFlow, key: _flow),
                    const GuideSteps(guideHandFlow),
                    GuideHeading(Strings.guideSectionCards, key: _cards),
                    const GuideSteps(guideCards),
                    GuideHeading(Strings.guideSectionWords, key: _words),
                    const GuideTerms(),
                    GuideHeading(Strings.guideSectionRules, key: _rules),
                    const GuideBullets(guideRules),
                    GuideHeading(Strings.guideSectionDrops, key: _drops),
                    const GuideSteps(guideDrops),
                    GuideHeading(Strings.guideSectionSafety, key: _safety),
                    const GuideBullets(guideSafety),
                    const GuideHeading(Strings.guideSectionManners),
                    const GuideBullets(guideManners),
                    BrutalRow(
                      label: Strings.guideSupportRow,
                      caption: Strings.guideSupportCaption,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportPage())),
                    ),
                    const SizedBox(height: BrutalMetrics.gapXxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small cell that scrolls to a section.
class _Jump extends StatelessWidget {
  const _Jump(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final duration = BrutalTheme.duration(context, BrutalMetrics.fast);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalPressable(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: duration,
          constraints: const BoxConstraints(minHeight: BrutalMetrics.tap),
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? c.ink : c.surface,
            border: Border.all(color: c.line, width: BrutalMetrics.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(
              fontFamily: BrutalFonts.mono,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
              color: pressed ? c.paper : c.ink,
            ),
            child: Text(label.toUpperCase()),
          ),
        ),
      ),
    );
  }
}
