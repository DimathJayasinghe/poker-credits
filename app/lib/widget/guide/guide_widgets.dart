import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/guide_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';

/// Building blocks for the Guide tab and the quick guide sheet. Plain reading material: every
/// block is built from the static lists in `util/guide_content.dart`.

TextStyle _body(BuildContext context, {bool bold = false, Color? color}) {
  final c = BrutalTheme.of(context).colors;
  return TextStyle(
    fontFamily: BrutalFonts.mono,
    fontSize: 13.5,
    height: 1.5,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    color: color ?? c.ink,
  );
}

TextStyle _title(BuildContext context, double size) {
  final c = BrutalTheme.of(context).colors;
  return TextStyle(fontFamily: BrutalFonts.display, fontSize: size, height: 1.05, letterSpacing: 0.6, color: c.ink);
}

BoxDecoration _rowLine(BuildContext context) {
  final c = BrutalTheme.of(context).colors;
  return BoxDecoration(
    border: Border(
      bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
    ),
  );
}

/// A section's big title, with the heavy rule above it.
class GuideHeading extends StatelessWidget {
  const GuideHeading(this.title, {super.key, this.intro});

  final String title;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      header: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapM),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.line, width: BrutalMetrics.borderHeavy),
            bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title.toUpperCase(), style: _title(context, BrutalType.section)),
            if (intro != null) ...<Widget>[
              const SizedBox(height: BrutalMetrics.gapS),
              Text(intro!, style: _body(context, color: c.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One section of reading text as a single cell: the heading, then the paragraph, under a heavy rule.
class GuideBlock extends StatelessWidget {
  const GuideBlock({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.line, width: BrutalMetrics.borderHeavy),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title.toUpperCase(), style: _title(context, BrutalType.section)),
            ),
            const SizedBox(height: BrutalMetrics.gapS + 2),
            Text(
              body,
              style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: BrutalType.body, height: BrutalType.bodyHeight, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// A numbered list of steps. Numbered because the order matters.
class GuideSteps extends StatelessWidget {
  const GuideSteps(this.steps, {super.key});

  final List<GuideStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < steps.length; i++)
          MergeSemantics(
            child: Container(
              decoration: _rowLine(context),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: 64,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: BrutalMetrics.gapM),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: c.line, width: BrutalMetrics.border),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: BrutalNumber(i + 1, size: 30, color: c.ink),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(BrutalMetrics.gapM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(steps[i].title.toUpperCase(), style: _title(context, 22)),
                            const SizedBox(height: BrutalMetrics.gapXs),
                            Text(steps[i].body, style: _body(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The ten hands, strongest first, followed by the tie-break notes.
class GuideHands extends StatelessWidget {
  const GuideHands({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final hand in guideHands)
          MergeSemantics(
            child: Semantics(
              label: '${Strings.guideRankLabel} ${hand.rank}: ${hand.name}. ${hand.line} ${hand.example}',
              excludeSemantics: true,
              child: Container(
                decoration: _rowLine(context),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        width: 72,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapXs),
                        decoration: BoxDecoration(
                          // The strongest hand is the only filled cell.
                          color: hand.rank == 1 ? c.ink : null,
                          border: Border(
                            right: BorderSide(color: c.line, width: BrutalMetrics.border),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BrutalNumber(hand.rank, size: 34, color: hand.rank == 1 ? c.paper : c.ink),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(BrutalMetrics.gapM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(hand.name.toUpperCase(), style: _title(context, 24)),
                              const SizedBox(height: BrutalMetrics.gapXs),
                              Text(hand.line, style: _body(context)),
                              const SizedBox(height: BrutalMetrics.gapS),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapXs),
                                decoration: BoxDecoration(
                                  border: Border.all(color: c.line, width: BrutalMetrics.border),
                                ),
                                child: Text(hand.example, style: _body(context, bold: true).copyWith(fontSize: 12.5, height: 1.3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const GuideBullets(guideHandNotes, muted: true),
      ],
    );
  }
}

/// Words and what they mean.
class GuideTerms extends StatelessWidget {
  const GuideTerms({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final term in guideTerms)
          MergeSemantics(
            child: Container(
              decoration: _rowLine(context),
              padding: const EdgeInsets.all(BrutalMetrics.gapM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(term.term.toUpperCase(), style: _title(context, 22)),
                  const SizedBox(height: BrutalMetrics.gapXs),
                  Text(term.meaning, style: _body(context)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Statements that are not a sequence, so no numbers: a small square marks each.
class GuideBullets extends StatelessWidget {
  const GuideBullets(this.items, {super.key, this.muted = false});

  final List<String> items;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final item in items)
          Container(
            decoration: _rowLine(context),
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapM - 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: BrutalMetrics.gapM),
                  child: SizedBox.square(
                    dimension: 8,
                    child: ColoredBox(color: muted ? c.muted : c.ink),
                  ),
                ),
                Expanded(
                  child: Text(item, style: _body(context, color: muted ? c.muted : c.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
