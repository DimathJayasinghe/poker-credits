# Implementation Plan: Poker Credits Companion App

> **Revised 2026-11-01:** stack changed from Next.js + Node/Socket.io to **Flutter + Rust**, with project structure and crash handling modelled on LocalSend (`~/Documents/dev_projects/localsend`). Current progress and next step live in `docs/STATUS.md`.

## Goal Description

Build **Poker Credits**, a real-time cross-platform companion app for physical Texas Hold'em games that replaces physical chips with a digital credit, pot and betting system.

- Physical cards are dealt by hand.
- A central device (tablet, laptop, TV, or a phone) is the **Table Display**; it can also host the game.
- Each player uses their own phone as a **Player Controller**.
- An optional **Spectator** watches without a seat.
- The app handles betting rounds, blinds rotation, turn order, chip deductions, min-raise validation, side pots and showdown payouts in real time.
- Networking supports **Cloud rooms** (4-letter codes, `wss://`) and **Host mode on LAN** (the host app embeds the server; QR join; no internet needed).
- Targets: iOS, Android, Windows first; macOS and Linux come from the same Flutter code.

---

## Tech Stack (Finalised)

| Layer | Technology | Why |
| :--- | :--- | :--- |
| **App framework** | **Flutter** (version pinned in `.fvmrc`, run via `fvm`) | One codebase for iOS, Android, Windows, macOS, Linux |
| **UI language** | **Neo-brutalism**, own widget set (`widget/brutal/`), bundled fonts | Owner request, ADR-013, `docs/UI_DESIGN.md` |
| **App state** | **Refena** (`refena_flutter`) | Same as LocalSend; Redux-style actions for socket/bridge work |
| **Models** | `dart_mappable` | Same as LocalSend |
| **Server language** | **Rust** (toolchain pinned in `rust-toolchain.toml`) | Memory safety, no GC pauses, embeddable in the app, same binary logic in the cloud |
| **Async runtime / HTTP / WS** | `tokio` + `axum` (`ws`) | Same as LocalSend's signaling server |
| **Poker engine** | `poker_engine` crate (pure, deterministic) | Testable, replayable, no I/O |
| **Server core** | `poker_server_core` crate (rooms as actors) | Shared by cloud binary and embedded host |
| **Bridge** | `flutter_rust_bridge` + cargokit | Same as LocalSend; embeds the server in the app |
| **Wire protocol** | JSON over WebSocket, `v` versioning, golden fixtures | Simple, debuggable, testable from both languages |
| **Persistence** | Atomic JSON snapshot + write-ahead action journal | Survives OS kills of the host app |
| **Testing** | `cargo test` + `proptest`; `flutter test`; fixture tests on both sides | |
| **Workspaces** | Cargo workspace + Dart pub workspace | One lock file each, as in LocalSend |
| **Web** | Deferred; codebase kept web-ready (platform seam, web build in CI from Phase 0) | Owner request, ADR-014 |
| **Dev tooling** | graphify knowledge graph, rust-analyzer LSP plugin, git hooks, `tool/*.sh` | `docs/DEV_SETUP.md` |
| **Cloud deploy** | Docker image of `server/` | Fly.io, Render or any host |

---

## Project Structure

```
pocker-credits/
├── Cargo.toml                      # Cargo workspace root (profiles, lints)
├── rust-toolchain.toml
├── .fvmrc
├── pubspec.yaml                    # Dart pub workspace root
├── CLAUDE.md                       # repo rules for agents (fvm, commands, doc map)
├── docs/                           # specs, ADRs, status
├── protocol/fixtures/v1/*.json     # golden wire messages (Rust + Dart tests)
├── crates/
│   ├── poker_engine/               # pure rules
│   └── poker_server_core/          # tokio/axum rooms, protocol, store, supervisor
├── server/                         # cloud binary + Dockerfile
├── packages/
│   ├── poker_protocol/             # Dart wire models
│   └── poker_bridge/               # FRB: rust/, rust_builder/ (cargokit), lib/
└── app/                            # Flutter app (config, model, net, provider, pages, widget, util)
```

Full per-phase file lists: `docs/AGENT_CODING_GUIDE.md` section 3. Crate and module responsibilities: `docs/ARCHITECTURE.md` section 3.

The old TypeScript scaffold was deleted on 2026-11-01 with the owner's approval.

---

## What We Take From LocalSend

Detail with file references: `docs/RESILIENCE_AND_CRASH_HANDLING.md`, `docs/DECISIONS.md` ADR-009 and ADR-011.

| Area | LocalSend practice | Our use |
| :--- | :--- | :--- |
| Repo shape | Flutter app + Rust core, two workspaces, FRB, cargokit | Same layout (ADR-009) |
| Pins | `.fvmrc`, `rust-toolchain.toml`, `fvm flutter` only | Same |
| Startup failure | try/catch around `preInit`, error app with copyable trace | Same |
| Server to app events | one typed event enum over a channel | `ServerEvent` |
| Lifecycle | probe local server on `resumed`, restart if dead; restart on listener failure | Same (host mode) |
| Cancellation safety | drop guards on in-flight sessions | Seat and connection guards |
| Signaling server | idle timeout, client ping, per-IP limits, scheduled counter reset | Same, tighter timings |
| Desktop | single-instance handover | Same |
| Android logging | `tracing_android` to logcat | Same |
| Discovery | UDP multicast announce, QR/IP fallback | Phase 6, optional |
| Not in LocalSend, designed by us | panic strategy, global Dart error hooks, room supervision, journal, resume handshake | ADR-011 |

---

## Race Conditions: Analysis & Mitigations

> [!IMPORTANT]
> The old Promise-chain queue is gone. Each room is a **Rust actor**: one tokio task owns the room state, handles a bounded inbox and the turn deadline in one `select!` loop. Everything below follows from "one thing at a time per room, in arrival order".

### RC-001: Concurrent Player Actions
**Scenario:** Player A taps Check while Player B taps Raise at the same instant.
**Mitigation:** Both arrive in the room inbox; the actor handles them one by one through the pure engine. If Raise is first, Check fails with `INVALID_CHECK` and the error includes the new call amount. State is replaced only on `Ok`. No locks around game state.

### RC-002: Reconnect vs. Action Mid-Disconnect
**Scenario:** A tap is in flight when the phone loses Wi-Fi; after reconnecting the user taps again.
**Mitigation:** Per-session monotonic `actionSeq` (`API_AND_EVENTS.md` 5.3): apply iff it equals the server's `nextActionSeq`. Duplicates are acknowledged without effect, gaps trigger `OUT_OF_SYNC` and a `RESUME`. `ACK`, `TURN_PROMPT` and `SNAPSHOT` carry `nextActionSeq`, so the client always takes the counter from the server.

### RC-003: Turn Timer Expiry vs. Late-Arriving Action
**Scenario:** Action arrives at 29.9 s on a 30 s timer, but the timer fires first in wall-clock terms.
**Mitigation:** The deadline is an `Instant` in the same `select!` as the inbox. Whichever event the actor dequeues first wins; the loser is then evaluated against the new state (an action after an auto-fold gets `NOT_YOUR_TURN`). An action that reaches the server before the deadline is dequeued wins; one that arrives after the auto-action is rejected. No extra grace window (open question in `docs/STATUS.md`: add a small latency grace if playtests show unfair auto-folds). Tests use `tokio::time::pause`.

### RC-004: Double "Start Hand"
**Mitigation:** The engine rejects `StartHand` unless phase is `LOBBY` or `NEXT_HAND_PREP`; the second command gets `HAND_IN_PROGRESS`. No `isTransitioning` flag is needed because transitions are atomic inside the actor.

### RC-005: Rebuy During an Active Hand
**Mitigation:** Rebuys apply only in `NEXT_HAND_PREP`; otherwise stored as `pending_rebuy` and applied at the next `NEXT_HAND_PREP`. Journal records both the request and the application.

### RC-006: Slow Consumer Blocks Broadcast (new)
**Mitigation:** Bounded per-connection outbound queue; on overflow that connection is closed and must `RESUME`. The room never awaits a client.

### RC-007: Host App Killed Mid-Hand (new)
**Mitigation:** Journal replay (`RESILIENCE_AND_CRASH_HANDLING.md` 3.4). Property test proves replay equals live state.

### RC-008: Room Panic (new)
**Mitigation:** Supervisor restores the room from snapshot + journal, notifies clients, freezes after 3 panics in 60 s. Other rooms unaffected.

---

## State Storage

In memory per room actor (`RoomState`: config, players, `GameState`, undo stack, last activity, pending rebuys, `nextActionSeq` per session). Persistence is a snapshot (atomic write at room creation, end of hand, config change, applied rebuy) plus an append-only journal of accepted commands, replayed through the deterministic engine on restore. No Redis, no SQL. Cloud mode uses a mounted volume (`POKER_DATA_DIR`); losing the volume loses rooms, which is acceptable for casual games.

---

## Design Patterns Applied

See `docs/CODING_STANDARDS.md` section 2: pure reducer/state machine with data-driven transition table, command objects shared by undo and journal, blinds strategy, actor per room, events returned by the engine, factories for room code and token, drop guards.

---

## Phased Implementation Plan

Each phase is one branch and one review. Details and file lists: `docs/AGENT_CODING_GUIDE.md` section 3.

### Phase 0: Bootstrap
- (Done) TypeScript scaffold deleted; dev tooling files added (`docs/DEV_SETUP.md`).
- Cargo workspace, pub workspace, empty crates, Flutter app skeleton on all five native platforms **plus web**, brutalist theme skeleton, CI (rust, dart, fixtures, `flutter build web`, `check_web_safe.sh`).
- Android cleartext/network config, iOS local-network keys, camera permissions.
- Init error app and global error hooks in `main.dart`.
- Fix approved dependency versions in `AGENT_CODING_GUIDE.md` section 6.
- Spike (throwaway, labelled): confirm FRB + cargokit builds on the dev machine for Linux and Android, and how a Rust panic surfaces in Dart.

### Phase 1: Engine (`poker_engine`)
- Types, state, commands, events, errors.
- `button` (dead button, missing blinds, heads-up), `validator` (check/call/raise limits, short all-in), `pots` (tiers, uncalled refund, odd chip), `blinds` (cash and tournament), `machine` (transition table, `apply`), `undo`.
- Tests: all scenarios in `CODING_STANDARDS.md` 6.1; property tests for conservation, no-panic fuzzing, replay equality.

### Phase 2: Server core and cloud binary
- Protocol types and fixtures, room actor, supervisor, sessions, snapshot + journal, WS and HTTP endpoints, rate limiting, guards, panic hook.
- Integration tests: full 4-client hand, resume, undo, all-in, RC-001 to RC-008, listener restart.
- `server/` binary and Dockerfile.

### Phase 3: Dart protocol package and bridge
- `poker_protocol` models and fixture tests.
- `poker_bridge`: start/stop, `ServerEvent` stream, create room, local addresses, logging; codegen and cargokit wired for Linux, Windows, Android first.

### Phase 4: App shell and Table screen
- Host a game with the embedded server, QR panel, live felt/seat ring/pots/ticker, host controls, wake lock, lifecycle recovery, desktop single-instance, settings with diagnostics copy.

### Phase 5: Player and Spectator screens
- Join by QR scan or typed address, cloud join by code, reconnect and resume UX, action buttons with `TURN_PROMPT.legal`, raise slider with quick fractions, rebuy sheet, haptics and sound, spectator view.

### Phase 6: Hardening and distribution
- Android foreground service, iOS foreground-hosting UX, Windows firewall guidance.
- Optional multicast discovery, optional TLS fingerprint pinning.
- Packaging: Android APK/AAB, iOS TestFlight, Windows installer, cloud deploy.
- Real-device matrix and 10-room load test.

### Phase 7 (later): Web Player
Server static serving + same-origin acceptance, `*_web.dart` platform implementations, bundled CanvasKit and fonts, browser quirks (audio unlock, no iOS vibration, camera needs HTTPS). No refactor expected.

### Phase 8 (proposed): Virtual cards
Owner request 2026-11-07: a second room mode where the server shuffles, deals private hole cards, reveals the board and ranks hands at showdown, for friends without a deck; LAN host mode first, cloud-ready by design. Physical mode unchanged and default. Design `docs/superpowers/specs/2026-11-07-virtual-cards-design.md`, ADR-016, plan `docs/superpowers/plans/2026-11-07-virtual-cards-plan.md`. Awaiting owner approval.

### Later / Optional
- Phase 7, Web Player: Flutter-web Player/Spectator served by the server (LocalSend embeds web assets from `packages/core/assets/web/`). Owner decision 2026-11-01: later, but the codebase must stay ready (ADR-014).
- Phase 7: Web Player (see below).
- Optional card-entry mode and hand evaluator (ADR-005 note).
- Localisation (Slang).

---

## Verification Plan

### Automated
```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace                    # engine, properties, server integration, fixtures
fvm dart format --set-exit-if-changed app/lib app/test packages
fvm flutter analyze
fvm flutter test                          # includes fixture round-trips
```

### Race Condition Checklist
- [ ] **RC-001**: two actions in the same tick; one succeeds, the other returns a clear error.
- [ ] **RC-002**: repeat `actionSeq`; second is acknowledged as duplicate, state unchanged.
- [ ] **RC-003**: action queued with timer expiry, paused clock; deterministic winner.
- [ ] **RC-004**: `START_HAND` twice within 10 ms; one hand starts.
- [ ] **RC-005**: rebuy at hand start applies to the following hand.
- [ ] **RC-006**: client that never reads is dropped; others unaffected.
- [ ] **RC-007**: kill the process mid-hand; restart restores the exact state.
- [ ] **RC-008**: injected panic in one room; room recovers, other room keeps playing.

### Manual (per release candidate)
1. Host on a laptop (host mode), four phones join by QR on a router with no internet.
2. SB and BB auto-posted, UTG highlighted; raise, call, fold across devices within 100 ms.
3. Three unequal all-ins; side pots on the table; showdown tap pays correctly.
4. Lock a phone during its turn; 30 s grace then auto-action; unlock and see the same hand.
5. Host taps Undo; all devices revert.
6. Force-kill the host app mid-hand and relaunch; room restores; players reconnect.
7. Airplane-mode toggle on a player phone; reconnect banner and resume.
8. Repeat step 1 with the cloud binary and `wss://`.
9. On iOS, background the host for 60 s and return; probe restarts the listener.
