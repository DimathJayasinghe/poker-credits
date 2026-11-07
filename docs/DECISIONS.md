# Architecture Decision Records (ADRs): Poker Credits

This document captures the key architectural decisions, their context, trade-offs and consequences.

**2026-11-01 pivot:** the stack changed from Next.js + Node/Socket.io to **Flutter + Rust**. ADR-001, ADR-002 and ADR-003 are superseded by ADR-008 to ADR-012. ADR-004, ADR-005, ADR-006 and ADR-007 stay in force with amendments noted in their text. The original wording of the superseded ADRs lives in git history (commit `a725aef` and earlier).

| ADR | Title | Status |
| :--- | :--- | :--- |
| 001 | Next.js + shadcn/ui frontend | **Superseded by ADR-008** |
| 002 | Authoritative server via Socket.io | **Superseded by ADR-009 and ADR-010** (the authoritative-server idea itself is kept) |
| 003 | Pure TypeScript shared engine | **Superseded by ADR-009** (pure reducer idea kept, now Rust) |
| 004 | Dual-mode connectivity (cloud + LAN) | Accepted, amended by ADR-009 |
| 005 | Physical cards showdown tap model | Accepted |
| 006 | In-memory state + crash snapshot | Accepted, **amended by ADR-011** (journal added) |
| 007 | Spectator role | Accepted, amended (routes became screens) |
| 008 | Flutter client for iOS, Android, Windows, macOS, Linux | Accepted |
| 009 | Rust workspace: engine, server core, cloud binary, FRB bridge | Accepted |
| 010 | Plain WebSocket + JSON protocol with explicit versioning | Accepted |
| 011 | Crash and resilience strategy (adopted from LocalSend) | Accepted |
| 012 | LAN join: room code finds the host (unicast subnet scan); QR and typed address as fallbacks | Accepted, **amended 2026-11-03** |
| 013 | Neo-brutalist UI | Accepted |
| 014 | Web-ready codebase (web build itself deferred) | Accepted |
| 015 | Editorial brutalism, light and dark themes, settings | Accepted |
| 016 | Virtual cards mode (server shuffles, deals, ranks) | **Accepted 2026-11-07** (built on `feature/engine-cards`), amends ADR-005 |

---

## ADR-001 (Superseded): Next.js 15 + shadcn/ui + Framer Motion

**Status:** Superseded by ADR-008 on 2026-11-01.

The original argument was zero-install onboarding: friends scan a QR code and play in a mobile browser. A native Flutter app gives up that default. The gain is one codebase for iOS, Android, Windows, macOS and Linux, real haptics, real wake-lock, a background service for the embedded server (ADR-009) and no browser-suspension problems. Zero-install joining is kept as an optional later phase (see ADR-008, "Browser guests").

## ADR-002 (Superseded): Authoritative server via Socket.io

**Status:** Superseded. The authoritative-server decision stays. The transport changes to plain WebSocket (ADR-010) and the runtime to Rust/tokio (ADR-009). Peer-to-peer WebRTC remains rejected: poker needs one source of truth for chip accounting.

## ADR-003 (Superseded): Pure TypeScript shared engine

**Status:** Superseded by ADR-009.

The "one language on client and server, zero drift" argument is gone: the Dart client no longer links the engine for remote play. Drift is now controlled by a versioned wire protocol plus golden JSON fixtures tested from both Rust and Dart (ADR-010). The client still never computes game outcomes; it renders what the server sends.

---

## ADR-004: Dual-Mode Connectivity: Hosted Cloud + Offline LAN

**Status:** Accepted. Amended 2026-11-01.

**Context:** Games happen in basements and cabins with no internet.

**Decision:** Two deployment targets, **one server implementation** (`poker_server_core`):
1. **Cloud mode.** The standalone `server/` binary runs on a host such as Fly.io. Clients connect with a server URL and a 4-letter room code.
2. **Host mode (offline LAN).** The table device runs `poker_server_core` **inside the app** through the Flutter-Rust bridge (ADR-009). It binds `0.0.0.0:<port>`, shows a QR code, and players join over Wi-Fi or a phone hotspot with no internet.

**Amendment:** the old design needed a Node process on a laptop. With Rust embedded in the app, any phone, tablet or desktop can be the host. The host's own UI connects to its embedded server over loopback using the same protocol as every other client, so there is a single code path.

**Consequences:** the host device must stay awake and keep the app alive (foreground service on Android, wake-lock everywhere, see `RESILIENCE_AND_CRASH_HANDLING.md`). If the host app dies, the game pauses until it restarts and restores from its journal (ADR-011).

## ADR-005: Physical Cards Showdown Resolution Model

**Status:** Accepted for **physical-card rooms** (unchanged). **Amended by ADR-016:** a room may instead be created in virtual-card mode, where the engine ranks the hands.

At showdown the table shows eligible contenders per pot; the host taps the winner(s). No card entry, no hand evaluator. Optional card input may come later as a toggle.

## ADR-006: State Storage: In-Memory + Snapshot

**Status:** Accepted. Amended by ADR-011.

State lives in memory inside each room actor. The original plan snapshotted only at the end of a hand and accepted losing a hand in progress. With the host running on a phone that the OS can kill at any time, that is too weak. ADR-011 adds a per-hand **action journal** so a restart replays to the exact state. Snapshot targets: a JSON file in the app support directory (host mode) or a configurable directory/volume (cloud mode). Redis is not required.

## ADR-007: Spectator Role

**Status:** Accepted. Amended: `/watch/[roomId]` becomes a Spectator screen in the Flutter app. Spectators never get a seat, never receive turn prompts, are capped at 20 per room.

---

## ADR-008: Flutter client for all platforms

**Status:** Accepted. **Date:** 2026-11-01.

**Context:** Target is iOS, Android and Windows at least, with macOS and Linux for free. Two screen styles exist: a landscape Table Display and a one-handed Player Controller.

**Decision:**
- One Flutter app (`app/`) with role-based screens: Table (host/display), Player, Spectator.
- State management: **Refena** (`refena_flutter`), the same as LocalSend, for consistency with the strategy being copied. Models via `dart_mappable`. This is the architect's call and can be revisited before Phase 3.
- Flutter pinned with FVM (`.fvmrc`), always run `fvm flutter` / `fvm dart`.
- Platform integrations use plugins: wake-lock (`wakelock_plus`), haptics (`HapticFeedback`, richer patterns via a plugin if needed), audio, QR render and scan, desktop window management. The exact package list and versions are fixed at scaffold time (Phase 0) and recorded in `AGENT_CODING_GUIDE.md` before use.
- i18n (Slang in LocalSend) is deferred; strings go through one `strings.dart` file from day one so adding it later is mechanical.

**Web (owner decision 2026-11-01):** the web build comes later, but the codebase must be ready for it from day one. Rules in ADR-014. The web build is a Player and Spectator client served by the server as static assets, the same trick LocalSend uses for its web page (`packages/core/assets/web/`).

**Consequences:** onboarding requires an install; in exchange we get reliable background behaviour, real haptics and one UI codebase. Every platform needs its own permissions and build setup (see `ARCHITECTURE.md` section 8).

## ADR-009: Rust workspace layout (modelled on LocalSend)

**Status:** Accepted. **Date:** 2026-11-01.

LocalSend is a Flutter app on top of a Rust protocol core, bridged with `flutter_rust_bridge` (FRB) and built with cargokit. We copy that shape.

```
pocker-credits/
├── Cargo.toml              # Cargo workspace root: one Cargo.lock, all [profile.*]
├── rust-toolchain.toml     # pinned toolchain (same approach as LocalSend)
├── .fvmrc                  # pinned Flutter (same approach as LocalSend)
├── pubspec.yaml            # Dart pub workspace root: one pubspec.lock
├── crates/
│   ├── poker_engine/       # pure rules: no I/O, no async, no clock, no RNG
│   └── poker_server_core/  # tokio + axum: rooms, WS protocol, snapshots, discovery
├── server/                 # standalone cloud binary + Dockerfile (thin main.rs)
├── packages/
│   ├── poker_bridge/       # FRB glue: rust/ (plugin crate), rust_builder/ (cargokit), lib/ (Dart)
│   └── poker_protocol/     # pure Dart wire models + golden-fixture tests
├── protocol/fixtures/      # golden JSON messages shared by Rust and Dart tests
└── app/                    # Flutter app
```

Dependency direction: `app` → `poker_bridge` → `poker_server_core` → `poker_engine`. `server/` → `poker_server_core`. The app depends on the bridge, never on FRB or core crates directly (same rule as LocalSend).

Rules:
- `poker_engine` is deterministic. Physical cards mean there is no shuffle, so no RNG. Same inputs always give the same output. This makes journal replay exact (ADR-011).
- `poker_engine` builds and tests with **default features**. LocalSend's `packages/core` needs `--features full` and a bare `cargo check` fails; we do not repeat that.
- Chips are `u64` newtypes. No floating point anywhere in money paths.
- Profile settings live only in the root `Cargo.toml`. Do **not** set `panic = "abort"`; crash recovery relies on unwinding (ADR-011).

**Consequences:** the same server code runs in the cloud and in the phone. FRB codegen and cargokit add toolchain weight; CI must build all five platforms eventually.

## ADR-010: Plain WebSocket + JSON, explicit versioning

**Status:** Accepted. **Date:** 2026-11-01.

**Decision:**
- axum WebSocket endpoint `GET /v1/ws`, the same route shape as LocalSend's signaling server.
- Messages are JSON objects tagged with `type` (serde `#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]`, as in LocalSend's `WsServerMessage`).
- Every message carries `v` (protocol version). Unknown `v` yields `VERSION_MISMATCH`.
- No Socket.io features are assumed. Reconnection, heartbeat and resume are specified by us (`API_AND_EVENTS.md`, `RESILIENCE_AND_CRASH_HANDLING.md`).
- Validation is serde deserialisation plus engine rules. There is no separate schema library; Rust enums are the schema.
- Drift control: `protocol/fixtures/*.json` hold one example per message. Rust tests deserialise and re-serialise them; Dart tests do the same through `poker_protocol`. A protocol change that breaks a fixture fails both suites.

JSON is chosen over a binary format because payloads are small, human-debuggable and traffic is low.

## ADR-011: Crash and resilience strategy (adopted from LocalSend)

**Status:** Accepted. **Date:** 2026-11-01.

Full detail in `docs/RESILIENCE_AND_CRASH_HANDLING.md`. Summary of what is copied from LocalSend and what is our own addition.

**Copied from LocalSend (verified in `~/Documents/dev_projects/localsend`):**
1. `main()` wraps `preInit` in try/catch and falls back to an error app showing the error, stack trace and app version in a copyable box (`config/init_error.dart`).
2. Networking is off the UI thread; typed events flow Rust → Dart over a channel, one event enum, no side channels (`ServerEventV2` pattern).
3. App lifecycle recovery: on `resumed` on mobile, probe the local server with a 1 second loopback connect and restart it if dead (`ensureRunning`); a listener-failure event triggers the same restart; on `detached` dispose isolates/server.
4. Cancellation safety in Rust through drop guards (`PendingSessionGuard`, `UploadGuard`).
5. Signalling server hygiene: client ping when idle, server idle timeout, per-IP connection limit, request counters cleared on a schedule.
6. Desktop single-instance handover (`notifyRunningInstance`, then exit).
7. Rust logs go to logcat on Android through `tracing_android`.
8. Pinned toolchains (`.fvmrc`, `rust-toolchain.toml`).

**Not found in LocalSend (verified by search for `catch_unwind`, `set_hook`, `runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher`; only `runZonedGuarded` exists, in the child isolate bootstrap). Our own additions:**
1. Global Dart error hooks in `main` (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`) writing to a rotating log file.
2. Rust panic hook that logs a backtrace through `tracing`.
3. **Room actor supervision**: one tokio task per room; a supervisor watches each `JoinHandle`. A panic in one room restores that room from its journal and never takes down other rooms or the process.
4. **Write-ahead action journal** per hand (amends ADR-006), replayed by the deterministic engine on restore.
5. Resume handshake with `stateVersion` and full snapshot, client-side exponential backoff with jitter.
6. Slow-consumer policy: bounded per-connection outbound queue; overflow disconnects that client (it resumes with a snapshot) rather than blocking the room.

## ADR-012: LAN joining: the room code finds the host

**Status:** Accepted, amended 2026-11-03 (owner feedback: typing the host IP is confusing). **Date:** 2026-11-01.

**Decision:** A player types the **room code and a name** and taps JOIN. The app finds the host by asking every other address of the device's own /24 networks (at most three, best-ranked first) `GET /v1/room/{code}` on port 7878, then 7879 (the host's fixed fallback). The first host that answers `exists: true` is joined. This is LocalSend's HTTP subnet-scan fallback, used as the only method: plain unicast TCP, so it needs no multicast permission, no Apple multicast entitlement and no Android multicast lock, and works the same on every platform. Fallbacks, in order: the QR code (`pokercredits://join?h=<ip>:<port>&c=<ROOM>&f=<fingerprint>`, skips the search), the typed `address[:port]` behind "Enter host address instead" (shown automatically when the search finds nothing, and the only mode on web, which cannot probe the LAN). A guest whose host stops answering after 3 reconnect attempts repeats the search for the stored room code and, if the host moved, resumes there with its session token.

**Why not multicast/mDNS:** iOS gates multicast behind an entitlement that needs Apple approval; many routers and hotspots drop or isolate multicast; it cannot be tested on the Android emulator. UDP broadcast/multicast announce (LocalSend's primary path) may still be added later as a speed-up and is never required.

**Limits:** the search covers /24 networks only and cannot cross subnets or "client isolation" guest Wi-Fi (the UI says so and offers the address field). Host port 7878/7879 is fixed so players can probe it; a host forced onto a random port needs the typed address or QR.

**Transport security:** superseded by ADR-019. LAN joining now runs over TLS 1.3 with a per-host self-signed certificate whose fingerprint travels in the QR code (`&f=`), which is the step this paragraph had left open. The QR format, the probe path (now HTTPS) and the fallbacks above are otherwise unchanged. Platform note that still holds: Android's network security config and iOS App Transport Security govern only the platform HTTP stacks, not `dart:io` sockets or the Rust server. Cloud uses `wss://` behind a proxy.

## ADR-013: Neo-brutalist UI

**Status:** Accepted (owner request). **Date:** 2026-11-01. **Look superseded by ADR-015** (structure, own components and bundled fonts stand).

**Decision:** The whole app uses a neo-brutalist visual language: flat saturated colours, 3-4 px black outlines, hard offset shadows with no blur, zero corner radius, heavy display type plus a monospace for labels and numbers, big blocky controls, snappy motion. Full spec: `docs/UI_DESIGN.md`.

**Why it fits:** high contrast and big hit targets suit dim rooms, TVs and one-handed play; flat shapes are cheap to render on low-end phones; a custom widget set (not Material look-alikes) looks identical on iOS, Android, desktop and web.

**Consequences:**
- We build our own widget set (`app/lib/widget/brutal/`) and a `BrutalTheme` extension. More up-front work than stock Material, less styling drift later.
- Fonts are bundled as assets (no runtime download), since LAN games are offline.
- Accessibility must be checked deliberately (contrast, focus rings, colour is never the only signal); rules are in the UI doc.

## ADR-014: Web-ready codebase (web build deferred)

**Status:** Accepted (owner request). **Date:** 2026-11-01.

**Decision:** We do not ship a web build in v1, but nothing we write may block one. Concretely:
1. **Web platform is enabled in the Flutter project from Phase 0** (`flutter create --platforms=...,web`), and CI runs `fvm flutter build web` on every change from Phase 0. A web compile failure fails CI, so web-unsafe code cannot creep in.
2. **Layer rules.** `packages/poker_protocol` and `app/lib/{model,net,provider,widget,theme,pages}` are web-safe: no `dart:io`, no `dart:ffi`, no `Platform.isX`, no direct import of `packages/poker_bridge`. A grep check (`tool/check_web_safe.sh`) enforces it in CI.
3. **Platform seam.** Everything platform-specific lives behind an interface in `app/lib/platform/` with conditional exports (`foo.dart` exports `foo_io.dart` or `foo_web.dart` or `foo_stub.dart`): secure token storage, file logging, wake lock, haptics, sound unlock, QR scanning, window management, single-instance handover, network address listing, and **host server (the FRB bridge)**. The web implementations are either real (wake lock, haptics where supported) or explicit "unsupported" stubs.
4. **Host mode is native only.** The embedded server (FRB) does not run in a browser. The web build is a Player and Spectator client that talks to a cloud server or to a LAN host. Hosting stays on native apps. (Owner can reopen.)
5. **Same-origin by default.** A web client served by the server derives the socket URL from `Uri.base` (`ws(s)://<same host>/v1/ws`), so no configuration is needed on a LAN. The server serves the built web player from `POKER_WEB_DIR` (cloud) or from assets embedded into the host app (LAN), and treats same-origin `Origin` headers as allowed.
6. **Numeric limits.** JavaScript numbers are exact only to 2^53-1. Chips and timestamps on the wire must stay below that: the engine enforces `MAX_CHIPS = 1_000_000_000_000`, and Dart models use `int` safely. No 64-bit ids or hashes as JSON numbers (send as strings).
7. **No runtime network assets.** Bundled fonts, bundled CanvasKit (`flutter build web --no-web-resources-cdn`, verified in Phase 0: without it the bootstrap points at gstatic.com. Flutter web still fetches fallback fonts for glyphs missing from the bundled fonts, such as emoji, from fonts.gstatic.com; offline those glyphs just fall back to boxes, so avoid emoji in UI text) so the web player works on an offline LAN.
8. **Browser quirks recorded now:** audio needs a user gesture to unlock (the Join tap does it); iOS Safari has no vibration API; camera QR scanning needs HTTPS or localhost (typed address and room code remain the fallback); tokens go to `localStorage` on web (weaker than the OS keystore, acceptable for a player token; the `hostToken` is never stored on web).
9. **Transport.** The protocol is already browser-compatible (WebSocket, JSON, text frames). No binary frames, no custom headers, no subprotocol requirements.

**Consequences:** slightly more discipline (the platform seam) and one extra CI job from day one; adding the web build later is then packaging and UI polish, not a rewrite.

## ADR-015: Editorial brutalism, light and dark themes, settings

**Status:** Accepted (owner request, with two reference designs). **Date:** 2026-11-04.

**Decision:** Replace the look of ADR-013 (3 px outlines, hard shadows, yellow/red/blue fills) with an editorial-brutalist one: a hairline cell grid, one condensed display face (Anton) with Space Mono for labels and data, paper grain, warm cream with a single vermilion accent, and a designed Night theme. Add a Settings screen (theme System/Light/Dark, texture, sound, vibration, screen-on, default name, forget saved game, about) and a Guide screen, behind a PLAY / GUIDE / SETTINGS bar. Settings persist in a small JSON file through `path_provider` behind the platform seam. Spec: `docs/UI_DESIGN.md`.

**Why:** the first look was tiring to watch for a whole evening, and the app had one screen and nothing to come back to. The owner wants the references' look, both themes, and a settings area.

**Consequences:**
- Fold, call and raise no longer differ by hue (outlined, ink, accent) so meaning rides on position and label. Better for colour-blind players; the old `signal`/`danger`/`info` token names remain as aliases while components migrate.
- **Anton is a new bundled font** (SIL OFL, `app/assets/fonts/`), outside the original approved list; Archivo Black is dropped. Anton has no tabular figures (digit `1` is narrower), so live numbers use `BrutalNumber`, which sets each digit in a fixed box.
- Small text in the accent colour is not allowed in the Paper theme (4.4:1 on bare paper, lower under grain). Accent is for fills and large type; error text uses ink with an accent marker.
- Every golden changes and is regenerated and inspected.

## ADR-016: Virtual cards mode

**Status:** Accepted 2026-11-07 (owner request; open calls decided by the assistant under the owner's delegation; implemented, awaiting merge). Full design: `docs/superpowers/specs/2026-11-07-virtual-cards-design.md`. Amends ADR-005.

**Context:** the app only handled the table, chips and pots; players needed a physical deck. Friends without a deck, or who do not want one, cannot play. The owner wants a second mode where the app deals, on the same LAN host model, and later through a cloud server for players anywhere.

**Decision:**
1. A room is created in `PHYSICAL` (default, unchanged) or `VIRTUAL` card mode; the mode is fixed for the life of the room.
2. Cards, the hand evaluator and showdown allocation live in `poker_engine` (all game rules live there). The engine stays free of RNG: the shuffled deck is an **input** (`Command::StartHand.deck`), generated by the server from OS entropy behind an injectable `Entropy` trait and **recorded in the journal**, so replay never re-shuffles and old journals still load.
3. Hole cards are private. They travel only in a per-recipient `HOLE_CARDS` message (like `TURN_PROMPT`), are re-sent after every `SNAPSHOT`, and never appear in `STATE_UPDATE`, to spectators or in logs. The public view carries the revealed board and, at showdown, the revealed hands.
4. In virtual rooms the server resolves showdown itself (`Op::AutoShowdown` with engine-computed allocations, journaled) and refuses the host's manual `BEGIN_SHOWDOWN` / `RESOLVE_SHOWDOWN`. Undo is limited to the current street.
5. Old clients are refused with `UPDATE_REQUIRED` via a `features` list on `JOIN_ROOM` / `RESUME`. All protocol changes are additive; `v` stays 1.
6. No Dart poker logic: the app renders cards and strings for categories the server names.
7. The deck is drawn in the room actor and carried in the journaled `HostCommand::StartHand { deck }`; a wire `START_HAND` has no deck field, so no client chooses the deal. Snapshot and journal files are created `0600` (directory `0700`) from this feature on.
8. The app learns a hand is virtual from what the view carries (seats with `hasCards`, a board, a result, reveals, its own `HOLE_CARDS`); the lobby and `GET /v1/room/{code}` carry `cardMode` for the Join page. A room-wide flag in every view was rejected: it would be one more protocol change for something a lobby never needs.
9. The all-in run-out is revealed by the server in one step and dealt onto the screen by the client, a street at a time; the result waits for the last card.

**Why:** keeps the single source of truth in Rust, keeps replay exact (randomness is data), makes the cloud move a deployment change, and leaves physical rooms untouched.

**Consequences:** new engine modules and a larger test surface (exhaustive hand-rank counts, no-leak oracle, replay with forced showdowns); card widgets and a stand-alone Player screen in the app; in host (LAN) mode the host's device is trusted with the deck (documented limit, gone in cloud mode). Open calls for the owner are listed in section 14 of the spec.

## ADR-017: First-run flow, tours, support screen

**Status:** Accepted 2026-11-07 (owner request; implemented on `feature/engine-cards`, awaiting merge).

**Context:** the app opened straight onto Home. The owner wanted a loading screen, a first-use notice (for example, play on a Wi-Fi you trust), a skippable demo of the app, a lesson for people new to poker, and a screen asking for a GitHub star and follow.

**Decision:**
1. `LaunchGate` is the app's home. It shows the splash (a flush of five cards turning over, a filling bar, tap to skip; half as long for a returning player), then the terms until `AppSettings.acceptedTerms >= currentTermsVersion`, then the intro until `introDone`, then Home. Raising `currentTermsVersion` asks everybody again. Nothing before Home blocks on the network or on a slow disk: settings are loaded before the first frame.
2. Terms are plain-language, five short sections (a Wi-Fi you trust, the host holds the cards in virtual mode, just for fun, data stays with you, no warranty), in `util/terms_content.dart`. ACCEPT stays disabled until the agree switch is on; declining closes the app. They stay readable in Settings. The text is **not legal advice** and should be reviewed before a store release.
3. Tours reuse one engine, `WalkthroughPage` (PageView, progress cells, Back/Next/Done, Skip on every step, arrow keys and Escape; the system back counts as skip). Steps are data (`model/walkthrough.dart`), illustrated by the app's own widgets (`widget/walkthrough/step_art.dart`), so an illustration cannot drift from the real UI. Two tours: the app tour (7 steps) and Learn poker (10 steps, taught with the real card widgets and the Guide's hand list; the Dart app still holds no rules). The intro offers both or skip; both are replayable from the Guide.
4. The Support screen shows the repository and profile links, an issues link and a QR of the repository. Links open through an `ExternalLinks` seam (`platform/external_links.dart`). `BrowserExternalLinks` opens the link in the system browser with `url_launcher` (`LaunchMode.externalApplication`) and falls back to copying the address, saying so, when nothing can open it. Only `https` URLs are accepted.
5. All of the above lives in `app/lib/pages`, `util` and `widget/walkthrough`; strings in `strings.dart` or `util/*_content.dart`; colours from tokens.

**Why:** a first-run gate is the one place to say what the app cannot protect against (an untrusted network); tours as data keep copy editable and tests simple; the seam keeps the web build and tests free of platform code.

**Consequences:** `url_launcher` was added with the owner's approval (2026-11-07); Android declares a `VIEW https` query so it works on Android 11 and newer. The first run adds one screen of friction by design; a returning player sees only a half-length splash.

## ADR-018: Single player mode with bots

**Status:** Accepted and built 2026-11-07 on `feature/solo-bots` (owner request; owner answered the open questions and approved the design the same day); design in `docs/superpowers/specs/2026-11-07-single-player-bots-design.md`, plan in `docs/superpowers/plans/2026-11-07-single-player-bots-plan.md`. Ships in 1.3.0 (not released yet).

**Context:** the owner wants to play alone against 1 to 9 computer players with a skill level chosen at the start. Requirements: feels like real players, fair, bots read each other and the human and adapt, bots are not clones, light on battery and CPU.

**Decision:**
1. Bots are seated players inside the room actor, not socket clients. Their think time is one more wake candidate in `next_wake_ms`; their action is an ordinary journaled `Op::Action`. No polling, no threads, no network.
2. Strategy lives in a new pure-Rust crate `crates/poker_bots` (no async, no I/O, no dependency on the server crate). Dart holds no poker rules and no bot logic.
3. Fairness by types (as built): the strategy gets a per-seat `BotView` (own cards, board, pots, stacks, public history, showdown reveals) and never `RoomState`, the deck or other hole cards. Property tests prove the decision does not change when hidden cards change. Bots use the same shuffle as human games and are never rigged either way.
4. Skill (Easy, Normal, Hard) changes only how well a bot uses the same information (equity samples, how fast it trusts reads, error rate). Personality (six archetypes plus jitter, mood, think speed) makes bots differ. Each bot keeps its own opponent notes; nothing is shared.
5. Randomness: a hand-written PRNG seeded from `getrandom`; `rand` is not added.
6. Solo is a hosted game on the device with the server bound to `127.0.0.1` only, cards in the app forced, the human's timer off by default, the game paused while the app is in the background.
7. Bots are exempt from absence, presence and vote-kick rules.
8. As built, where the build settled what the design left open: a bot is stored in the room state only as a `BotProfile` (archetype, skill, seed), so its personality is rebuilt from the seed and there is **no** `Op::AddBot`; `RoomState::seat_bots(seed)` seats them when the room is created, from one seed drawn in the actor, and they are part of the saved state. A single optional `RoomConfig.solo { bots, skill, ladder_hands }` field marks a solo room (no separate `bots` / `bot_skill` fields). Cleaning up a finished or idle solo room is the journaled `Op::SoloSweep`. A solo room can only be created on a server built with `ServerConfig::loopback_only`, which refuses network `CREATE_ROOM` with `solo`. The solo server has its own data directory (`solo_rooms`) and the app keeps the game in its own token slot (`TokenSlot.solo`), so it never touches a hosted or joined game. `RoomView.blinds` (solo only) carries the current and next blinds and the hands left, so Dart shows the ladder without knowing it. The table is the normal `PlayerPage` in a solo mode, not a new screen.
9. Owner decisions 2026-11-07: solo is a freeze-out tournament (no rebuy; losing shows an end screen; a hand-driven blind ladder in the engine keeps pressure on); bots look exactly like real players (no tag, `is_bot` is never sent to clients); 1 to 9 bots.

**Why:** reuses the whole tested table, journal and virtual-cards stack; the types make cheating impossible rather than forbidden; the actor already sleeps until its next timer, which is the cheapest possible scheduling.

**Consequences:** new crate `poker_bots`; `RoomConfig` gains the optional `solo` field and `RoomView` gains `finishOrder` and `blinds` (all additive, protocol stays v1); a second session slot for a solo game; opponent notes reset after a restore; the app records the owner's best place per table kind (bots and skill) locally; release 1.3.0.

## ADR-019: Encrypted LAN transport, certificate pinning, release hardening

**Status:** Built 2026-11-08 on `security/lan-tls` (owner request: examine the security of the app before a signed store release, and encrypt connections between devices). Audit and findings: `docs/SECURITY_AUDIT_2026-11-08.md`. Amends ADR-012 (transport security) and ADR-010 (plain WebSocket).

**Context:** until now a hosted game ran on `ws://` on the local network. Anyone on the same Wi-Fi could read the session and host tokens, take over a seat, or pose as the host, and the app gave a guest no way to know it had reached the right phone. A signed store build makes that a release blocker. There is no certificate authority on a LAN, and a phone cannot hold a name that a CA would sign, so the host proves itself by a certificate the guest is told to expect.

**Decision:**
1. **TLS 1.3 only, in the Rust server.** `rustls` 0.23 with the `ring` backend, through `tokio-rustls`; no TLS 1.2, ALPN `http/1.1` only (WebSocket upgrade over HTTP/1.1). The crates were added with the owner's approval (2026-11-08); `cargo deny` is clean. `crates/poker_server_core/src/tls.rs` holds the identity, the fingerprint and the listener.
2. **One self-signed identity per phone.** ECDSA P-256 certificate and key from `rcgen`, valid 2024-01-01 to 2124-01-01 (a LAN host has no clock it can trust, and the pin makes expiry meaningless). Persisted in the app data directory as `tls-identity.bin` (mode 0600, written atomically: temp file, fsync, rename) in a small format: `PCTLS1\n`, then the certificate DER and the key DER, each with a 4-byte big-endian length. A missing file is created; a corrupt one is replaced and logged. The pin therefore survives restarts and app updates, so a guest's stored session still resumes. If the file is lost the pin changes and guests must scan the QR again (they get a clear refusal, not a silent downgrade).
3. **The pin is the SHA-256 of the certificate DER**, written as 43 characters of base64url without padding. The QR link carries it as `f=`. A guest trusts exactly that certificate and no other: the system trust store is not used (`SecurityContext(withTrustedRoots: false)`, TLS 1.3 minimum) and the pin is compared in `badCertificateCallback`. Hashing is done once, in Rust (`cert_fingerprint` in the bridge), so host and guest cannot disagree about the algorithm.
4. **How a guest gets the pin:** (a) QR scan: pinned from the first byte, the strongest path. (b) Room code, lobby list, or a typed address: trust on first use. The app asks the device that answers for its certificate (`HostFinder.fingerprintOf`) and pins the connection to that one, and the stored session keeps the pin so a later reconnect cannot be redirected to a different device. This protects against passive listening and against a later switch of devices, not against an active attacker who is already on the Wi-Fi at the moment of the first join; the guide and the terms say so and recommend the QR code. (c) Cloud mode uses `wss://` behind a proxy with a real certificate, unchanged.
5. **No silent downgrade.** Host mode refuses to listen on a non-loopback address without TLS (`StartError::PlaintextOnNetwork`). The Dart client refuses plain `ws://` to any non-loopback host (`InsecureAddress`), refuses a stored `ws://` LAN session, and reports a pin mismatch (`PinMismatch`, shown as "not the host you meant", no retries and the stored tokens are kept) and a plain-HTTP host (`NoSecureChannel`, shown as "host runs an older version" after two tries). Solo games keep a plain `ws://127.0.0.1` socket on the device itself (a `loopback_only` server), which never leaves the phone. The host's own screen talks to its own server over `wss://127.0.0.1` pinned to its own certificate, so there is one code path.
6. **Hostile network hardening in the listener.** Handshakes run in their own tasks, never in the accept loop: 5 s handshake timeout, at most 64 handshakes at once, at most 8 per IP, a ready queue of 32. Dropping the listener aborts the accept task and frees the port. The per-IP connection limiter still sees the peer address (`ConnectInfo<SocketAddr>` through `tap_io`).
7. **Host-header check** (DNS-rebinding defence): in Host mode only an IP literal, `localhost` or a `*.local` name is accepted, otherwise 400. A web page in a browser on the same Wi-Fi cannot talk to a host through a name it controls. Cloud mode serves its own name and is not affected.
8. **Android:** `usesCleartextTraffic="false"` (it governs Android's own HTTP stack and WebViews, not our sockets). Release signing reads `android/key.properties` (git-ignored); `REQUIRE_RELEASE_SIGNING=1` makes a build without a key fail instead of falling back to the debug key. The upload key is created and kept by the owner; the repository never holds a key.
9. **CI:** every GitHub Action is pinned to a commit SHA (with the tag in a comment); Dependabot proposes updates weekly.

**Why a pin and not a CA or a password:** a LAN host has no name a CA can sign. A pin carried in a QR code the guest scans from the host's own screen binds the connection to the physical phone in front of them, with no accounts and no server. It is the model LocalSend uses (fingerprint-based identity), as ADR-012 anticipated.

**Residual risks (accepted, listed in the audit):** trust on first use for code, lobby and typed-address joins; the private key sits in the app data directory as a 0600 file rather than in the platform keystore (the app sandbox protects it; a rooted device does not); no global cap on established connections after the handshake; four-character room codes (rate limited, ADR-012); a 1.3.1 host and a TLS guest cannot play together (release notes say so).

**Consequences:** protocol stays v1 (the transport changed, the messages did not). `JoinLink` gains an optional `fingerprint`; the QR is longer, so its error correction is set to L to keep it scannable. `HostedRoom.fingerprint`, `DiscoveredHost.fingerprint` and `DiscoveredLobby.fingerprint` carry the pin. New dependencies: `rustls`, `tokio-rustls`, `rcgen` (all `ring`). New tests: 12 TLS integration tests, 11 unit tests, a native Dart-to-rustls interop test (`packages/poker_bridge/test/native_tls_test.dart`, run with `POKER_BRIDGE_LIB`), and a real TLS server test in the app (`test/platform/secure_channel_test.dart`, fixture in `test/fixtures/tls`).
