<p align="center">
  <img src="branding/logo.png" alt="Poker Credits logo" width="160">
</p>

<h1 align="center">Poker Credits</h1>

<p align="center">
  Digital chips and pots for in-person Texas Hold'em, and a solo mode against computer players. Keep the cards, drop the chip stacks.
</p>

<p align="center">
  <a href="https://github.com/DimathJayasinghe/poker-credits/actions/workflows/ci.yml"><img src="https://github.com/DimathJayasinghe/poker-credits/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <a href="https://github.com/DimathJayasinghe/poker-credits/releases/latest"><img src="https://img.shields.io/github/v/release/DimathJayasinghe/poker-credits?include_prereleases" alt="Latest release"></a>
</p>

## What it is

Players deal and shuffle real cards. The app does the rest: blinds, the dealer button, bets, main and side pots, odd chips and payouts. One device sits on the table and shows the pot and every seat. Each player uses their own phone to fold, check, call or raise.

No internet is needed. The table device can run the game server inside the app, and players join over the same Wi-Fi or a phone hotspot with a 4-letter room code or a QR scan.

No cards and no friends at hand? **Play alone** seats you against 1 to 9 computer players on one device, with the cards dealt by the app.

- **Cards in the app (optional):** the host's device can shuffle and deal, so each player sees their own two cards privately and the showdown is handled for you. Real cards still work as before.
- **Play alone:** pick 1 to 9 opponents and Easy, Normal or Hard. It is a freeze-out tournament with rising blinds, a result screen with your place and stats, and a personal record. Nothing leaves your device.

## Download

Get the latest build from the [Releases page](https://github.com/DimathJayasinghe/poker-credits/releases/latest).

| Platform | File |
| :--- | :--- |
| Windows | `poker-credits-windows-x64-setup.exe` (installer) or the `.zip` |
| Android | `poker-credits-android-arm64.apk` for most phones, or `poker-credits-android.apk` for any device (allow installs from unknown sources) |
| Linux | `poker-credits-linux-x64.tar.gz`. Unpack, then run `./install.sh` inside the folder to add it to your application menu with its icon |

Each release lists `SHA256SUMS` so you can verify the files.

## How to play

1. One person taps **Host a game** on the table device (a tablet, laptop or TV), enters a name and the blinds, and taps **Start hosting**.
2. Everyone else opens **Join**, picks the game or types the room code, and enters a name. Scanning the QR code on the table also works.
3. Deal real cards. The app tracks whose turn it is and the money. At showdown the host taps the winner of each pot.

Lock your phone or lose Wi-Fi for a moment and you come back into the same hand.

To play alone, tap **Play alone** on the home screen, choose how many opponents, their level and how fast the blinds rise, and sit down. You can pause, save and exit, and pick the game up later.

### The computer players

They are players, not scripts: each has a style (tight, loose, aggressive, a calling station and more), its own pace, and a memory of how the table plays, and they adapt to you. Fairness is built into the types: a bot's strategy receives only its own seat's view (its cards, the board, the pots, the public betting), never the deck or anyone else's cards, and a property test checks that changing hidden cards cannot change a decision. Easy, Normal and Hard differ in how well a bot uses the same information, not in what it can see. The judgement numbers were tuned offline by self-play and ship as fixed constants, so there is no model and no extra battery cost. How it works: [Game rules, section 11](docs/GAME_LOGIC_AND_RULES.md).

## Under the hood

- **App:** Flutter for Android, iOS, Windows, macOS and Linux. It holds no poker rules.
- **Engine:** `crates/poker_engine`, a pure and deterministic Rust library. All rules live here.
- **Bots:** `crates/poker_bots`, pure Rust strategy for the computer players (a per-seat view in, an action and a thinking time out), with a self-play trainer in `examples/train.rs`.
- **Server:** `crates/poker_server_core`, a tokio and axum WebSocket server with one task per room, a crash journal and rate limits. It runs inside the app (host mode) or as a standalone binary in `server/` (cloud mode).
- **Protocol:** versioned JSON over WebSocket, specified in [`docs/API_AND_EVENTS.md`](docs/API_AND_EVENTS.md).

## Build from source

You need [FVM](https://fvm.app) (Flutter is pinned in `.fvmrc`) and Rust (pinned in `rust-toolchain.toml`).

```bash
# Rust: format, lint, test
cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace

# App
cd app
fvm flutter pub get
fvm flutter analyze && fvm flutter test
fvm flutter run -d linux        # or windows, android, ios
```

Machine setup and helper scripts: [`docs/DEV_SETUP.md`](docs/DEV_SETUP.md). To run the standalone server: [`docs/DEPLOY.md`](docs/DEPLOY.md).

## Documentation

| | |
| :--- | :--- |
| [STATUS](docs/STATUS.md) | Current state and what is next |
| [Architecture](docs/ARCHITECTURE.md) | Components, state machine, pot algorithm |
| [Game rules](docs/GAME_LOGIC_AND_RULES.md) | Betting, side pots, showdown as implemented |
| [Protocol](docs/API_AND_EVENTS.md) | Wire messages and HTTP endpoints |
| [Security](docs/SECURITY_AND_EDGE_CASES.md) | Threat model and limits |
| [Decisions](docs/DECISIONS.md) | Why things are the way they are |
| [UI design](docs/UI_DESIGN.md) | The visual system |

## Security note

Host mode serves TLS 1.3 on the local network with a per-phone certificate that guests pin (the QR code carries its fingerprint), so the game is encrypted and a guest can tell it reached the right phone. Still play on a network you trust (home Wi-Fi or your own hotspot), not on public Wi-Fi: a shared network can see that a game exists and try the room code. Cloud mode must sit behind TLS. Details are in the security document above and in ADR-019.

## License

[MIT](LICENSE), copyright Dimath Jayasinghe. The bundled fonts (Anton, Space Mono) are under the SIL Open Font License; their texts are next to the font files in `app/assets/fonts/`.

Third-party code keeps its own licences. The Rust crates are checked against a permissive-only policy (`cargo deny check`, see [`deny.toml`](deny.toml)), and the app lists every Dart, Flutter and font licence under **Settings, Open-source licences**. The computer players use no third-party poker code and no trained model; the hand evaluation and strategy are this project's own.
