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
  /// One entry per section: its id, a key for scrolling to it, and its content.
  static const List<_Id> _ids = _Id.values;
  final Map<_Id, GlobalKey> _keys = <_Id, GlobalKey>{for (final id in _Id.values) id: GlobalKey()};

  /// Only the first section is open at the start; the rest are one tap away.
  final Set<_Id> _open = <_Id>{_Id.night};

  bool get _allOpen => _open.length == _ids.length;

  void _toggle(_Id id) => setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  void _toggleAll() => setState(() => _allOpen ? _open.clear() : _open.addAll(_ids));

  /// Opens a section and scrolls its heading into view once it has been laid out.
  void _jump(_Id id) {
    setState(() => _open.add(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[id]!.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, duration: BrutalTheme.duration(context, BrutalMetrics.max), curve: Curves.easeOut);
    });
  }

  Widget _section(_Id id, String title, String summary, Widget child) =>
      GuideSection(key: _keys[id], title: title, summary: summary, open: _open.contains(id), onToggle: () => _toggle(id), child: child);

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
                              style: TextStyle(fontFamily: BrutalFonts.display, fontSize: BrutalType.headline, height: 1.05, color: c.ink),
                            ),
                          ),
                          const SizedBox(height: BrutalMetrics.gapM),
                          Text(
                            Strings.guideIntroBody,
                            style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: BrutalType.body, height: BrutalType.bodyHeight, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    // The two walkthroughs come straight after the headline that promises them.
                    BrutalRow(
                      dense: true,
                      label: Strings.guideLearnRow,
                      caption: Strings.guideLearnRowCaption,
                      emphasis: true,
                      onTap: () => openLesson(context),
                    ),
                    BrutalRow(dense: true, label: Strings.guideTourRow, caption: Strings.guideTourRowCaption, onTap: () => openAppTour(context)),
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
                              _Jump(Strings.guideTabHands, () => _jump(_Id.hands)),
                              _Jump(Strings.guideTabHand, () => _jump(_Id.flow)),
                              _Jump(Strings.guideTabCards, () => _jump(_Id.cards)),
                              _Jump(Strings.guideTabWords, () => _jump(_Id.words)),
                              _Jump(Strings.guideTabRules, () => _jump(_Id.rules)),
                              _Jump(Strings.guideTabDrops, () => _jump(_Id.drops)),
                              _Jump(Strings.guideTabSafety, () => _jump(_Id.safety)),
                              _Jump(_allOpen ? Strings.guideCloseAll : Strings.guideOpenAll, _toggleAll),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _section(_Id.night, Strings.guideSectionNight, Strings.guideSumNight, const GuideSteps(guideNight)),
                    _section(_Id.hands, Strings.guideSectionHands, Strings.guideSumHands, const GuideHands()),
                    _section(_Id.flow, Strings.guideSectionFlow, Strings.guideSumFlow, const GuideSteps(guideHandFlow)),
                    _section(_Id.cards, Strings.guideSectionCards, Strings.guideSumCards, const GuideSteps(guideCards)),
                    _section(_Id.words, Strings.guideSectionWords, Strings.guideSumWords, const GuideTerms()),
                    _section(_Id.rules, Strings.guideSectionRules, Strings.guideSumRules, const GuideBullets(guideRules)),
                    _section(_Id.drops, Strings.guideSectionDrops, Strings.guideSumDrops, const GuideSteps(guideDrops)),
                    _section(_Id.safety, Strings.guideSectionSafety, Strings.guideSumSafety, const GuideBullets(guideSafety)),
                    _section(_Id.manners, Strings.guideSectionManners, Strings.guideSumManners, const GuideBullets(guideManners)),
                    BrutalRow(
                      dense: true,
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

/// The sections of the Guide, in page order.
enum _Id { night, hands, flow, cards, words, rules, drops, safety, manners }

/// A small cell that opens and scrolls to a section.
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
          decoration: BoxDecoration(
            color: pressed ? c.ink : c.surface,
            border: Border.all(color: c.line, width: BrutalMetrics.border),
          ),
          // Centred but only as wide as the label: an `alignment` would stretch the cell to the
          // full width of its row and stack the cells one under another.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
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
      ),
    );
  }
}
