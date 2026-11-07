/// The notice a player accepts on first launch (and again when [currentTermsVersion] goes up).
///
/// Plain language on purpose. It is a safety notice and an honest statement of what the app does,
/// not legal advice: whoever publishes the app in a store should have it reviewed first.
/// The security statements mirror `docs/SECURITY_AND_EDGE_CASES.md`; change them together.
library;

/// One headed paragraph of the notice.
class TermsSection {
  const TermsSection(this.title, this.body);

  final String title;
  final String body;
}

const List<TermsSection> termsSections = <TermsSection>[
  TermsSection(
    'Use a Wi-Fi you trust',
    'Games run over your local network and the connection is not encrypted. On a shared or public Wi-Fi (a cafe, hotel, school or office) other people on that network could watch the traffic or try to join with the room code. Host on your own home Wi-Fi, or on your phone hotspot with a password. Give the room code only to the people at your table.',
  ),
  TermsSection(
    'The host holds the cards',
    'With cards in the app, the phone that hosts the game shuffles and deals, so it knows every card. Play with cards in the app only with people you would trust to host. With real cards, the app never sees a card.',
  ),
  TermsSection(
    'Just for fun',
    'Chips here are counters for a game between friends. They have no cash value, and the app never moves money or takes bets. Play only where and with whom it is allowed, and keep it friendly. If you are under the legal age for gambling where you live, do not play for real stakes.',
  ),
  TermsSection(
    'Your data stays with you',
    'There are no accounts, no ads and no analytics. Your name, settings and saved game stay on your device. What you type in a game goes only to the phone that hosts it, on your network.',
  ),
  TermsSection(
    'No warranty',
    'Poker Credits is free, open-source software provided as it is, without any warranty. The developer is not responsible for lost chips, dropped connections or arguments at the table.',
  ),
];
