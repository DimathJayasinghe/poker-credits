/// The privacy policy, as shown in Settings. `PRIVACY.md` in the repository root is the same text for
/// the web (the link a store listing needs): `test/util/privacy_content_test.dart` fails when the two differ,
/// so change them together. It describes what the code does today; when the app starts to handle data in a
/// new way (an account, an analytics or crash service, a server of the developer), change this first and
/// raise [privacyUpdated]. The statements mirror `docs/SECURITY_AND_EDGE_CASES.md`.
library;

import 'package:poker_credits/util/terms_content.dart';

/// The day the policy last changed, as shown to players.
const String privacyUpdated = '8 November 2026';

const List<TermsSection> privacySections = <TermsSection>[
  TermsSection(
    'The short version',
    'Poker Credits does not collect your data. There are no accounts, no ads, no analytics and no tracking, and the developer runs no server that the app talks to. What the app keeps stays on your device. What you share in a game goes only to the people at your table.',
  ),
  TermsSection(
    'What stays on your device',
    'The app saves your settings (theme, sound, vibration and card options, your default name and your results against bots), the game you can go back to (room code, your seat, a session token, and the address and certificate fingerprint of the host), the room itself while you host, so a crashed game can be restored, and a small log of technical messages such as errors and connections. The saved game, with its session token, is kept in the secure storage of your system: Keychain, Android Keystore, Windows data protection or the Linux keyring. None of this is sent to the developer or to anyone else.',
  ),
  TermsSection(
    'What other players see',
    'When you host or join a game, your display name, seat, chips and moves go to the device that hosts it and are shown to the other players at that table. With cards in the app, the host also holds every card, so play that mode only with people you trust to host. Use a nickname if you prefer: the app never asks for your real name.',
  ),
  TermsSection(
    'Network and permissions',
    'Games run over your local network and are encrypted with TLS 1.3. To find a game by room code, the app asks other devices on your local network whether they host that code; the code, and the name you join with, reach only a device that answers. The app reaches the internet only if you type an address outside your local network, or when you tap a link, which opens in your browser. It asks your system for network access and, on Android, for a notification while you host so the game stays alive. It asks for nothing else: not your location, contacts, files or microphone.',
  ),
  TermsSection(
    'Camera',
    'On Android, iPhone and Mac the app can use the camera to scan a join QR code. The picture is read on the device only to find the code. It is not saved, not sent and not shared. The Windows and Linux apps do not use the camera.',
  ),
  TermsSection(
    'Who else gets your data',
    'Nobody. The app has no advertising, analytics or crash-reporting service, and it shares nothing with third parties. When you tap a link to the project page, your browser takes over and that website\'s own policy applies.',
  ),
  TermsSection(
    'Security',
    'Connections between devices use TLS 1.3, and your device checks the certificate fingerprint of the host it joined. Scanning the host\'s QR code is the strongest check (see Terms and safety). The saved game sits in your system\'s secure storage. The developer holds no copy of your data, so it cannot be recovered for you if you delete it.',
  ),
  TermsSection(
    'Your choices',
    'You decide what the app keeps. Change or clear your default name, and switch sound, vibration and the other options off, in Settings. Use Forget saved game in Settings to remove the saved game from this device. Uninstall the app to remove what it stored; on a computer installed without the Microsoft Store, delete the app\'s data folder as well. Because the developer holds no copy of your data, there is nothing to ask for or delete on a server.',
  ),
  TermsSection(
    'Children',
    'Poker Credits plays poker and is for adults, 18 or older (see Terms and safety). It is not meant for children and it knowingly collects nothing from them: it asks for no personal details beyond the name you type, and it collects nothing from anyone. Chips have no cash value and the app never moves money.',
  ),
  TermsSection(
    'Changes and contact',
    'If the app ever handles data differently, this policy changes first and the date changes with it. Last updated $privacyUpdated. Questions or concerns: open an issue at https://github.com/DimathJayasinghe/poker-credits/issues.',
  ),
];
