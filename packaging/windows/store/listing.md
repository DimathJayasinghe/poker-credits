# Microsoft Store listing text

Paste-ready text for Partner Center, in the order of the submission pages. Limits are Partner Center's
(checked in `docs/MICROSOFT_STORE.md`). The description is plain text: no HTML, no links. Keep every claim true
of the Windows app; the policy (10.1) says the listing "must accurately and clearly reflect" the product.

## Store listing, English (United States)

### Product name

Poker Credits

### Description (limit 10,000 characters)

```
Poker Credits keeps the chips so you can enjoy the cards. Deal with a real deck, or let the app deal, and have every stack, bet, side pot and winner counted for you.

PLAY YOUR WAY
- Real cards: use a physical deck at the table. The app never sees a card; it keeps the chips, the blinds and the pots.
- Cards in the app: the host shuffles and deals digitally, and each player sees only their own hand.
- Play alone: practise against computer players at Easy, Normal or Hard.

BUILT FOR THE TABLE
- Host a game on your own network. Friends join with a room code or an address. On phones they can also scan a QR code.
- Connections between devices are encrypted.
- Proper rules: blinds that rise as the game goes on, side pots, split pots, minimum raises and all-ins.
- A bold paper-and-ink look in light or dark, with calm, original sound effects you can turn off in one tap.

YOUR DATA STAYS WITH YOU
No accounts, no ads, no analytics. Your name and settings stay on your device and nothing is sent to the developer.

GOOD TO KNOW
- Games run over your local network, so everyone needs to be on the same Wi-Fi or network.
- When you host, Windows may ask to allow the app through the firewall. Allow it on private networks.
- The Windows app joins by room code or address; scanning a QR code needs a phone camera.

JUST FOR FUN
Chips have no cash value and the app never moves money. Because it simulates poker, the Store rates it 18+. Poker Credits is free, open-source software.
```

### Short description (limit 1,000 characters)

```
Chips, blinds and pots for Texas Hold'em night. Use a real deck and let the app keep every stack, or play alone against bots. Host a table on your own Wi-Fi: no accounts, no ads, no tracking.
```

### App features (up to 20, each up to 200 characters)

1. Real cards or cards in the app: use a physical deck, or let the host deal digitally.
2. Play alone against computer players at three skill levels.
3. Host on your own Wi-Fi and join by room code or address.
4. Encrypted connections between devices.
5. Blinds that rise, side pots, split pots and all-ins handled for you.
6. No accounts, no ads, no analytics.
7. Light and dark themes with calm, original sound effects.

### Search terms (up to 7)

`poker`, `texas holdem`, `chip counter`, `poker chips`, `home game`, `blinds`, `card game`

### Copyright and trademark info

Copyright 2026 Poker Credits. Open-source software under the MIT licence.

### Screenshots (1366 x 768 or larger, PNG, at least 1, four recommended)

Made from the real screens by `docs/MICROSOFT_STORE.md` section 6 (1920 x 1080) in `screenshots/`:

| File | Caption (up to 200 characters) |
| :--- | :--- |
| `windows-table.png` | Six players, chips, bets and the board on one screen. |
| `windows-play.png` | Host a game, join one, or play alone against bots. |
| `windows-guide.png` | A built-in guide teaches the hands and the flow of a round. |
| `windows-settings.png` | Light or dark, sound on or off, your name: a short, simple Settings page. |

### Store logos

- 1:1 app tile icon, 300 x 300: `store-logo-300x300.png`
- 1:1 box art, 1080 x 1080 (if the page asks for it): `box-art-1080x1080.png`
- 9:16 poster art, 1440 x 2160 (the page asks for it): `poster-art-1440x2160.png`

## Properties

- Category: **Games**, genre **Card + board** (not Casino). The product must be created as type **Game**; a game filed under an app category fails certification (policy 10.1.21).
- Privacy policy: the text of `PRIVACY.md`, or the URL `https://github.com/DimathJayasinghe/poker-credits/blob/main/PRIVACY.md` once it is on `main`.
- Website: `https://github.com/DimathJayasinghe/poker-credits`
- Support contact: `https://github.com/DimathJayasinghe/poker-credits/issues`
- System requirements: leave empty (no touch, camera or other hardware is needed).
- Display mode: leave every box unticked (no 4K, HDR, variable refresh rate or mixed reality).
- Privacy: personal information is transmitted (the player's name goes to the other players): answer **Yes** and give the privacy policy URL above.
- Game settings (Microsoft's definitions, <https://learn.microsoft.com/gaming/game-publishing/concepts/properties-basic-info>): **Single player** PC; **Local multiplayer** ("players connected through a local network"), minimum 2, maximum 10; **Cross-platform multiplayer** ("players on other devices or game platforms beside Xbox": a Windows PC and Android phones share a table), optional. Leave **Online multiplayer** (internet play, there is no service for it), split screen and every co-op option unticked.
- Product declarations: leave the defaults; do not tick purchases outside the Store, accessibility-tested or generative AI.

## Age ratings (IARC questionnaire)

Answer exactly what is true. Done on 2026-11-08: App Type **Game**; gambling **Yes**, ticking "Gambling themes" and
"Playable casino games, lotteries, or racetrack betting"; gambling themes a strong focus **Yes**; can win cash
payouts or rewards of monetary value **No**; every violence, sexuality, language, substance, humour, purchase,
location, voice/text/image exchange and other question **No**.

Result: **Microsoft 18+**; IARC 18+ (Simulated Gambling), PEGI 18, ACB R18+, Brazil 18, Saudi Arabia 18, Indonesia 18+
(Gambling), Russia 18+, USK 16 (Gambling Themes), ESRB Teen (Simulated Gambling), Taiwan 15+, Chile 14+. This is
what a poker simulation with virtual chips gets; it is not a sign of a mistake. Do not change honest answers to get a
lower rating: Microsoft compares the answers with the app and re-rates (policy 11.11.2). Policy 11.14 (real-money
gambling needs 18+, a payment API and is banned in some markets) does not apply: nothing here pays out.

## Submission options

### Restricted capability: runFullTrust

```
Poker Credits is a Flutter desktop application. poker_credits.exe is a native Win32 program (the Flutter engine and a Rust game engine, both native code) packaged as MSIX with the Desktop Bridge, so it cannot run inside the UWP app container and needs runFullTrust. It uses it only to run as a normal desktop process. It keeps its own settings and saved game in its package's private data and does not read or change files, registry keys or other apps outside it.
```

### Notes for certification (up to 2,000 characters)

```
No account or login is needed and there are no purchases.

To test quickly: start the app, accept the terms, skip the tour and the name step if shown. On the Play tab choose "Play alone", type any name and press Start game. You play Texas Hold'em against computer players.

To host a table: Play tab, Host a game, choose "Cards in the app" or "Real cards". Windows may ask to allow the app through the firewall: allow on private networks. A second device on the same network can join with the room code or the address shown. Joining another device is optional for testing.

The app uses the network only for games on the local network (and a server address you type yourself). It has no camera access on Windows. The privacy policy is in Settings > Privacy policy and in the Properties page. Chips have no cash value; there is no real-money gambling.
```
