# Poker Credits (Poker Companion App)

> A real-time, cross-platform companion app for physical Texas Hold'em games that replaces poker chips with a digital credit and pot management system. **Flutter** app, **Rust** server and engine.

---

## Overview

In home poker games, stacking, counting, making change and working out side pots slows play. **Poker Credits** keeps the physical cards and replaces the chips:

* **Physical cards**: players shuffle and deal in real life.
* **Table Display**: a tablet, laptop or TV in the middle shows the pot, side pots, radial seating, dealer button, blind badges and a live action ticker.
* **Player Controllers**: each player uses their phone to fold, check, call or raise, with haptic feedback when it is their turn.
* **Two ways to connect**: cloud rooms with 4-letter codes, or **Host mode** where the table device runs the server inside the app, so it works with no internet (Wi-Fi router or phone hotspot, QR join).

Targets: iOS, Android, Windows (macOS and Linux come from the same code). A web Player build comes later; the code is kept web-ready (ADR-014). UI style: neo-brutalism ([`docs/UI_DESIGN.md`](docs/UI_DESIGN.md)).

> **Status:** design and documentation phase. The earlier TypeScript scaffold has been removed. See [`docs/STATUS.md`](docs/STATUS.md) for what is done and what comes next.

---

## Documentation

| Document | Purpose |
| :--- | :--- |
| [STATUS](docs/STATUS.md) | Where we are, next step, open questions. **Start here when resuming.** |
| [Decisions (ADRs)](docs/DECISIONS.md) | Why Flutter + Rust, workspace layout, protocol, crash strategy, LAN join. |
| [UI Design](docs/UI_DESIGN.md) | Neo-brutalist design system: tokens, components, screens, accessibility. |
| [Dev Setup](docs/DEV_SETUP.md) | Toolchains, Claude Code plugins, graphify, git hooks, check scripts. |
| [Architecture](docs/ARCHITECTURE.md) | Components, diagrams, Hold'em state machine, side-pot algorithm, network modes, platform setup. |
| [Resilience & Crash Handling](docs/RESILIENCE_AND_CRASH_HANDLING.md) | What we copy from LocalSend and what we add: error app, panic supervision, journal, reconnect/resume. |
| [API & Protocol](docs/API_AND_EVENTS.md) | WebSocket JSON messages, resume handshake, error codes, HTTP endpoints, versioning. |
| [Game Logic & Rules](docs/GAME_LOGIC_AND_RULES.md) | Betting rules, heads-up, side pots, odd chips, showdown. |
| [Security & Edge Cases](docs/SECURITY_AND_EDGE_CASES.md) | Threat model, tokens, rate limits, backgrounding, short all-in, undo. |
| [Coding Standards](docs/CODING_STANDARDS.md) | Rust and Dart standards, lints, patterns, testing. |
| [Agent Coding Guide](docs/AGENT_CODING_GUIDE.md) | Strict phase-by-phase instructions for implementation agents. |
| [Implementation Plan](pocker_credit_plan.md) | Stack, structure, race conditions, phases, verification. |

---

## Tech Stack

```
App:            Flutter (pinned via .fvmrc), Refena state, dart_mappable, neo-brutalist widget set
Web:            deferred; web-ready by construction (platform seam, web build in CI)
Server:         Rust, tokio + axum WebSocket, one actor task per room
Engine:         poker_engine (pure, deterministic, property-tested)
Bridge:         flutter_rust_bridge + cargokit (embeds the server in the app)
Protocol:       JSON over WebSocket, versioned, golden fixtures shared by Rust and Dart tests
Persistence:    atomic JSON snapshot + write-ahead action journal
Reference:      LocalSend (~/Documents/dev_projects/localsend) for layout and crash handling
```

---

## Repository Structure (target)

```
pocker-credits/
├── Cargo.toml  rust-toolchain.toml  .fvmrc  pubspec.yaml
├── docs/                       # specs, ADRs, status
├── protocol/fixtures/v1/       # golden JSON messages
├── crates/
│   ├── poker_engine/           # pure rules
│   └── poker_server_core/      # rooms, protocol, store, supervisor
├── server/                     # cloud binary + Dockerfile
├── packages/
│   ├── poker_protocol/         # Dart wire models
│   └── poker_bridge/           # flutter_rust_bridge glue
└── app/                        # Flutter app
```


---

## Commands (once Phase 0 is done)

```bash
# One-time machine setup check (see docs/DEV_SETUP.md)
bash tool/setup_dev.sh

# Rust
cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace

# Flutter (always through fvm)
fvm flutter pub get
fvm dart run build_runner build
fvm flutter analyze && fvm flutter test
fvm flutter run -d linux            # or windows / android / ios

# Bridge codegen (from packages/poker_bridge)
flutter_rust_bridge_codegen generate
```

---

## Key Gameplay Features

1. **Fast onboarding**: the table shows a QR code; players scan it in the app (or type address and room code).
2. **Automated blinds and button**: dealer, small blind, big blind, dead button and heads-up rules handled by the engine.
3. **Automated main and side pots**: unequal all-ins produce tiered pots.
4. **Showdown tap**: host taps the winner(s) for each pot; split pots and odd chips handled.
5. **Reliable reconnects**: lock your phone, come back, you are in the same hand. If the host app is killed, the room restores from its journal.
6. **Wake lock and haptics**: table stays awake; your phone buzzes on your turn.
