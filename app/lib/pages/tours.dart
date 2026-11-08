import 'package:flutter/material.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/pages/walkthrough_page.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/util/tour_content.dart';

/// The two walkthroughs, opened from the first-run intro, Settings and the Guide.
/// [thenOther] offers the other walkthrough on the last step. [skipToOther] also makes leaving the
/// tour early open the poker lesson (the first-run flow), which can then be skipped on its own.
Future<void> openAppTour(BuildContext context, {bool thenOther = false, bool skipToOther = false}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WalkthroughPage(
        title: Strings.tourTitle,
        steps: appTourSteps,
        followUp: thenOther
            ? WalkthroughFollowUp(label: Strings.followToLesson, title: Strings.learnTitle, steps: pokerLessonSteps, skipOpensIt: skipToOther)
            : null,
      ),
    ),
  );
}

Future<void> openLesson(BuildContext context, {bool thenOther = false}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WalkthroughPage(
        title: Strings.learnTitle,
        steps: pokerLessonSteps,
        followUp: thenOther ? const WalkthroughFollowUp(label: Strings.followToTour, title: Strings.tourTitle, steps: appTourSteps) : null,
      ),
    ),
  );
}
