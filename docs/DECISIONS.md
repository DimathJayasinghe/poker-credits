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

**Decision:** A player types the **room code and a name** and taps JOIN. The app finds the host by asking every other address of the device's own /24 networks (at most three, best-ranked first) `GET /v1/room/{code}` on port 7878, then 7879 (the host's fixed fallback). The first host that answers `exists: true` is joined. This is LocalSend's HTTP subnet-scan fallback, used as the only method: plain unicast TCP, so it needs no multicast permission, no Apple multicast entitlement and no Android multicast lock, and works the same on every platform. Fallbacks, in order: the QR code (`pokercredits://join?h=<ip>:<port>&c=<ROOM>`, skips the search), the typed `address[:port]` behind "Enter host address instead" (shown automatically when the search finds nothing, and the only mode on web, which cannot probe the LAN). A guest whose host stops answering after 3 reconnect attempts repeats the search for the stored room code and, if the host moved, resumes there with its session token.

**Why not multicast/mDNS:** iOS gates multicast behind an entitlement that needs Apple approval; many routers and hotspots drop or isolate multicast; it cannot be tested on the Android emulator. UDP broadcast/multicast announce (LocalSend's primary path) may still be added later as a speed-up and is never required.

**Limits:** the search covers /24 networks only and cannot cross subnets or "client isolation" guest Wi-Fi (the UI says so and offers the address field). Host port 7878/7879 is fixed so players can probe it; a host forced onto a random port needs the typed address or QR.

**Transport security:** LAN uses `ws://` on a trusted network (documented warning). Android's network security config and iOS App Transport Security only govern the platform HTTP stacks (`HttpURLConnection`, `NSURLSession`, WebViews). Dart's `dart:io` sockets and the Rust server use raw sockets and are not subject to them, so Phase 0 adds no cleartext exceptions. Verify with a real `ws://` connection on a physical Android and iOS device in Phase 5; add exceptions only if it fails. iOS still needs the Local Network permission description (added in Phase 0). Cloud uses `wss://`. A later hardening step (open) is a per-host self-signed certificate whose fingerprint travels in the QR code, like LocalSend's fingerprint-based identity.

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
