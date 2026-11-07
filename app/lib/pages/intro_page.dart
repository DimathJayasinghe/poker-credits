import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';

/// What the player picked on the first-run intro.
enum IntroChoice { tour, learn, skip }

/// Shown once after the terms are accepted: offers the app tour and the poker lesson, and lets
/// the player skip both. Skipping is always one tap and never blocks anything.
class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.onChoose});

  final ValueChanged<IntroChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppTopBar(title: Strings.introTitle),
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
                                Strings.introTitle.toUpperCase(),
                                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: BrutalType.headline, height: 1.05, color: c.ink),
                              ),
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            Text(
                              Strings.introBody,
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
                      Container(height: BrutalMetrics.border, color: c.line),
                      BrutalRow(
                        dense: true,
                        label: Strings.introTour,
                        caption: Strings.introTourCaption,
                        emphasis: true,
                        onTap: () => onChoose(IntroChoice.tour),
                      ),
                      BrutalRow(dense: true, label: Strings.introLearn, caption: Strings.introLearnCaption, onTap: () => onChoose(IntroChoice.learn)),
                      BrutalRow(dense: true, label: Strings.introSkip, caption: Strings.introSkipCaption, onTap: () => onChoose(IntroChoice.skip)),
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
