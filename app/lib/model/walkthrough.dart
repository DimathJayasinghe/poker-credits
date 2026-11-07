import 'package:flutter/foundation.dart';

/// The picture shown above a step. Each is drawn from the app's own widgets, so the tour always
/// looks like the app it teaches.
enum StepArt {
  // App tour.
  welcome,
  host,
  join,
  cardMode,
  yourTurn,
  showdown,
  playAlone,
  staySafe,
  // Learn poker.
  goal,
  holeCards,
  board,
  rounds,
  choices,
  blinds,
  handsTop,
  handsBottom,
  workedExample,
  words,
}

/// One page of a walkthrough: a picture, a title and a few plain sentences.
@immutable
class WalkthroughStep {
  const WalkthroughStep({required this.title, required this.body, required this.art, required this.artLabel});

  final String title;
  final String body;
  final StepArt art;

  /// What the picture shows, for screen readers.
  final String artLabel;
}

/// How a walkthrough ended.
enum WalkthroughEnd { finished, skipped }

/// What a walkthrough offers once its last step is reached: another walkthrough, opened in its
/// place. The first-run intro uses it so someone who chose one tour is still told about the other.
@immutable
class WalkthroughFollowUp {
  const WalkthroughFollowUp({required this.label, required this.title, required this.steps});

  /// The button text.
  final String label;
  final String title;
  final List<WalkthroughStep> steps;
}
