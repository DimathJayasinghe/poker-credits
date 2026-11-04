<p align="center">
  <img src="branding/logo.png" alt="Poker Credits logo" width="160">
</p>

<h1 align="center">Poker Credits</h1>

<p align="center">
  Digital chips and pots for in-person Texas Hold'em. Keep the cards, drop the chip stacks.
</p>

<p align="center">
  <a href="https://github.com/DimathJayasinghe/poker-credits/actions/workflows/ci.yml"><img src="https://github.com/DimathJayasinghe/poker-credits/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/DimathJayasinghe/poker-credits/releases/latest"><img src="https://img.shields.io/github/v/release/DimathJayasinghe/poker-credits?include_prereleases" alt="Latest release"></a>
</p>

## What it is

Players deal and shuffle real cards. The app does the rest: blinds, the dealer button, bets, main and side pots, odd chips and payouts. One device sits on the table and shows the pot and every seat. Each player uses their own phone to fold, check, call or raise.

No internet is needed. The table device can run the game server inside the app, and players join over the same Wi-Fi or a phone hotspot with a 4-letter room code or a QR scan.

## Download

Get the latest build from the [Releases page](https://github.com/DimathJayasinghe/poker-credits/releases/latest).

| Platform | File |
| :--- | :--- |
| Windows | `poker-credits-windows-x64-setup.exe` (installer) or the `.zip` |
| Android | `poker-credits-android-arm64.apk` for most phones, or `poker-credits-android.apk` for any device (allow installs from unknown sources) |
| Linux | `poker-credits-linux-x64.tar.gz` |

Each release lists `SHA256SUMS` so you can verify the files.

## How to play

1. One person taps **Host a game** on the table device (a tablet, laptop or TV), enters a name and the blinds, and taps **Start hosting**.
2. Everyone else opens **Join**, picks the game or types the room code, and enters a name. Scanning the QR code on the table also works.
3. Deal real cards. The app tracks whose turn it is and the money. At showdown the host taps the winner of each pot.

Lock your phone or lose Wi-Fi for a moment and you come back into the same hand.

## Under the hood

- **App:** Flutter for Android, iOS, Windows, macOS and Linux. It holds no poker rules.
- **Engine:** `crates/poker_engine`, a pure and deterministic Rust library. All rules live here.
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

Host mode uses plain `ws://` on the local network, so play on a network you trust (home Wi-Fi or your own hotspot), not on public Wi-Fi. Cloud mode must sit behind TLS. Details are in the security document above.
