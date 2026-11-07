import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';

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
    return FitPage(
      title: Strings.introTitle,
      maxWidth: 640,
      compactBelow: 760,
      tightBelow: 520,
      padding: EdgeInsets.zero,
      builder: (context, info) {
        // On its side the page has no height for the second line of each row.
        final captions = !info.sideBySide;
        final header = FitHeader(info: info, headline: Strings.introTitle, body: Strings.introBody, bodyShort: Strings.introBodyShort);
        final rows = <Widget>[
          Container(height: BrutalMetrics.border, color: c.line),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.introTour,
            caption: captions ? Strings.introTourCaption : null,
            emphasis: true,
            onTap: () => onChoose(IntroChoice.tour),
          ),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.introLearn,
            caption: captions ? Strings.introLearnCaption : null,
            onTap: () => onChoose(IntroChoice.learn),
          ),
          BrutalRow(
            dense: true,
            snug: !info.roomy,
            label: Strings.introSkip,
            caption: captions ? Strings.introSkipCaption : null,
            onTap: () => onChoose(IntroChoice.skip),
          ),
        ];
        if (info.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: header),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
              ),
            ],
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[header, ...rows]);
      },
    );
  }
}
