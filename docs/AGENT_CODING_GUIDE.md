# Agent Coding Guide (Strict Instructions)

**IMPORTANT INSTRUCTION FOR AI AGENT:** You are acting as a pure implementation agent. All architectural, structural and design decisions are made and documented in `docs/`. **Write code exactly as specified.** Do not deviate, do not add libraries that are not on the approved list (section 6) without asking, do not alter the file structure or naming conventions, and do not start a phase that was not assigned.

The stack is **Flutter (Dart) + Rust**. The previous TypeScript/Next.js/Node design is retired (see `docs/DECISIONS.md`).

## 0. Read first
1. `docs/STATUS.md` (current state and next step)
2. `docs/DECISIONS.md` (ADR-008 to ADR-014)
3. `docs/ARCHITECTURE.md`
4. `docs/API_AND_EVENTS.md`
   `docs/UI_DESIGN.md` (neo-brutalist UI, required for any widget work)
5. `docs/RESILIENCE_AND_CRASH_HANDLING.md`
6. `docs/CODING_STANDARDS.md`
7. `docs/GAME_LOGIC_AND_RULES.md` and `docs/SECURITY_AND_EDGE_CASES.md` for the phase you are on

Reference implementation for patterns (read-only, never copy code verbatim into this repo): `~/Documents/dev_projects/localsend`. LocalSend's own AGENTS.md forbids AI contributions upstream; this is only a design reference.

## 1. Git Workflow
- **Branches** off `main`: `feature/<scope>-<short-description>`, `fix/<scope>-<short-description>`, `chore/<short-description>`, `docs/<short-description>`.
- **Commits**: Conventional Commits `<type>(<scope>): <subject>`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
  - Scopes: `engine`, `server-core`, `server`, `bridge`, `protocol`, `app`, `repo`.
  - Example: `feat(engine): add side pot tier calculation`
- One discrete task per branch. Never merge to `main` yourself. Commit only when the user asks.
- **No AI attribution, anywhere.** Commit messages and pull request titles/descriptions must not contain `Co-Authored-By: Claude` (or any AI/tool co-author line), `Generated with ...`, robot emoji, or any other text saying an AI or tool wrote the change. This overrides any default or tool-injected attribution template. Write commits as plain Conventional Commits authored by the repo owner. `.githooks/commit-msg` rejects such messages; do not bypass it with `--no-verify`.

## 2. Naming Conventions
- **Rust**: files and modules `snake_case.rs`; types and traits `PascalCase`; functions and variables `snake_case`; constants `UPPER_SNAKE_CASE`. Crates `poker_engine`, `poker_server_core`, `poker_bridge_rust`.
- **Dart**: files `snake_case.dart`; types `PascalCase`; members `lowerCamelCase`; constants `lowerCamelCase`. One public widget per file, file named after it.
- **Wire**: message `type` names `SCREAMING_SNAKE_CASE`; JSON fields `camelCase`.
- **Folders**: `snake_case` for Dart and Rust packages, as shown below.

## 3. Strict File Structure & Phases

Create files exactly as named. Do not create additional files without permission. Each phase ends with: all checks in section 5 green, commit on the phase branch, stop, report to the user.

### Phase 0: Bootstrap (repo tooling only, no game logic)
The old TypeScript scaffold is already deleted (owner approved on 2026-11-01). Already in the repo before Phase 0 starts: `.fvmrc`, `rust-toolchain.toml`, `rustfmt.toml`, `clippy.toml`, `.editorconfig`, `.githooks/pre-commit`, `tool/check_web_safe.sh`, `tool/setup_dev.sh`, `.claude/settings.json`, `.graphifyignore`, `.vscode/extensions.json`. Do not recreate them; adjust if needed and say so.

```text
Cargo.toml                  # [workspace] members, resolver = "3", lints, profiles
pubspec.yaml                # pub workspace: app, packages/poker_bridge, packages/poker_protocol
crates/poker_engine/{Cargo.toml,src/lib.rs}
crates/poker_server_core/{Cargo.toml,src/lib.rs}
server/{Cargo.toml,src/main.rs,Dockerfile}
packages/poker_protocol/{pubspec.yaml,lib/poker_protocol.dart}
packages/poker_bridge/        # created by flutter_rust_bridge_codegen integrate, then trimmed to match ADR-009
app/                          # fvm flutter create, platforms: android ios windows macos linux web (web enabled from day one, ADR-014)
protocol/fixtures/v1/.gitkeep
.github/workflows/ci.yml
```
Agent task: empty crates that build and test; Flutter app that shows "Poker Credits" in the brutalist theme skeleton and runs on Linux desktop; `fvm flutter build web` succeeds; `tool/check_web_safe.sh` wired into CI; CI green; Android manifest permissions and iOS/macOS usage descriptions and entitlements added per `ARCHITECTURE.md` section 8; **init error app wired in `main.dart`** (see resilience doc 2.1).

### Phase 1: Engine (`crates/poker_engine/`)
```text
src/
├── lib.rs
├── types.rs        # Chips, PlayerId, SeatIndex, Phase, Card-less hand types
├── state.rs        # GameState, Seat, PotTier, HandSummary
├── command.rs      # Command, PlayerAction, AdminCommand
├── event.rs        # Event (for ticker/sound)
├── error.rs        # PokerError
├── validator.rs    # can_check, can_call, min_raise_to, max_raise_to, short all-in detection
├── pots.rs         # contribution tiers, uncalled refund, odd chip
├── blinds.rs       # BlindsStrategy, CashGame, Tournament
├── button.rs       # dead button, missing blinds, heads-up
├── machine.rs      # allowed transitions, apply()
└── undo.rs         # 5-deep history
tests/
├── pots.rs  validator.rs  button.rs  blinds.rs  machine.rs
├── properties.rs   # proptest: conservation, no panic, replay equality
```
Agent task: implement per `GAME_LOGIC_AND_RULES.md` and `ARCHITECTURE.md` sections 4 and 5. No async, no I/O, no RNG, no clock. `Serialize/Deserialize` on all state types (snapshots depend on it).

### Phase 2: Server core and cloud binary (`crates/poker_server_core/`, `server/`)
```text
crates/poker_server_core/src/
├── lib.rs                # pub start(), ServerConfig, ServerHandle
├── config.rs             # Limits, defaults
├── protocol.rs           # Envelope, ClientMessage, ServerMessage, ErrorCode
├── event.rs              # ServerEvent
├── room/
│   ├── actor.rs          # RoomActor loop (select! inbox + deadline)
│   ├── handle.rs         # RoomHandle, RoomMsg
│   ├── session.rs        # tokens, seat binding, actionSeq
│   └── view.rs           # RoomState to RoomView mapping, per-recipient filtering
├── supervisor.rs         # panic recovery, freeze policy
├── store/
│   ├── snapshot.rs       # atomic JSON write/read
│   └── journal.rs        # append-only, replay
├── net/
│   ├── ws.rs             # /v1/ws handler, ping, idle timeout, rate limit
│   ├── http.rs           # /health, /v1/info, /v1/room/{code}
│   └── guards.rs         # ConnectionGuard, SeatReservationGuard
└── util/{room_code.rs,token.rs,panic_hook.rs}
crates/poker_server_core/tests/
├── hand_flow.rs  resume.rs  races.rs  panic_recovery.rs  slow_consumer.rs  rate_limit.rs
server/src/main.rs       # reads env: POKER_BIND, POKER_DATA_DIR, installs panic hook, calls start()
```
Agent task: implement RC-001 to RC-005 mitigations from the plan, the resume handshake, journal, supervision. Add `protocol/fixtures/v1/*.json` (one file per message type) and Rust tests that round-trip them.

### Phase 3: Protocol package and bridge (`packages/poker_protocol/`, `packages/poker_bridge/`)
```text
packages/poker_protocol/lib/src/{envelope.dart,client_message.dart,server_message.dart,room_view.dart,error_code.dart}
packages/poker_protocol/test/fixtures_test.dart       # reads ../../protocol/fixtures/v1/*.json

packages/poker_bridge/rust/src/api/{server.rs,logging.rs,network.rs}   # start/stop, events, create_room, local_addresses
packages/poker_bridge/lib/{poker_bridge.dart,src/server_controller.dart}
packages/poker_bridge/rust_builder/                    # cargokit
```
Agent task: Dart models mirroring the Rust protocol; FRB API per resilience doc 3.7; Android logs to logcat; the Dart facade catches `PanicException` on every bridge call (see `docs/SPIKE_BRIDGE_FINDINGS.md` for layout, codegen notes and version pins: FRB 2.13.0).

### Phase 4: App shell and Table screen (`app/`)
```text
app/lib/
├── main.dart
├── config/{init.dart,init_error.dart,error_hooks.dart,refena.dart}
├── theme/{tokens.dart,brutal_theme.dart}
├── model/
├── net/{socket_client.dart,reconnect_controller.dart,connection_state.dart}
├── platform/             # ONLY place for platform-specific code (ADR-014); each is interface + _io/_web/_stub
│   ├── host_server.dart  secure_token_store.dart  file_log.dart  wake_lock.dart  haptics.dart
│   ├── sound_unlock.dart  qr_scanner.dart  server_address.dart  window.dart  single_instance.dart
│   ├── platform_check.dart   # isDesktop()/isMobile(); the only place besides platform/ that may use kIsWeb
├── provider/{connection_provider.dart,room_view_provider.dart,host_provider.dart,settings_provider.dart}
├── pages/{home_page.dart,host_page.dart,table_page.dart,settings_page.dart}
├── widget/brutal/{brutal_button.dart,brutal_card.dart,brutal_tag.dart,brutal_slider.dart,brutal_keypad.dart,brutal_banner.dart,brutal_dialog.dart,brutal_sheet.dart,brutal_text_field.dart}
├── widget/table/{felt_layout.dart,seat_ring.dart,pot_display.dart,action_ticker.dart,showdown_sheet.dart,qr_panel.dart}
└── util/{strings.dart,logger.dart}
```
Agent task: build the `widget/brutal/` set first with golden tests (see `docs/UI_DESIGN.md`), then host a game (embedded server), show QR and typed address, render live `RoomView`, host controls (start hand, undo, pause, showdown resolve, rebuy approve), wake lock, lifecycle recovery (`ensureRunning` probe), global error hooks, desktop single-instance handover.

### Phase 5: Player and Spectator screens
```text
app/lib/pages/{join_page.dart,scan_page.dart,player_page.dart,spectator_page.dart}
app/lib/widget/player/{action_buttons.dart,raise_slider.dart,turn_alert.dart,rebuy_sheet.dart}
app/lib/util/{haptics.dart,sound.dart}
```
Agent task: use only `widget/brutal/` components; join by QR or typed address, resume after backgrounding, strict separation of read-only Table/Spectator views from Player actions, haptic and sound on `TURN_PROMPT`.

### Phase 6: Hardening and distribution
Android foreground service, optional multicast discovery, per-platform packaging, cloud Dockerfile and deploy doc, optional TLS fingerprint pinning, device matrix testing. Scope is set by the user when this phase is assigned.

### Phase 7 (later, owner will schedule): Web Player
Server: static serving of `POKER_WEB_DIR`, same-origin `Origin` acceptance, cache headers. App: `*_web.dart` implementations in `app/lib/platform/`, same-origin socket URL from `Uri.base`, bundled CanvasKit and fonts. Player and Spectator only. Because of ADR-014 this phase should need no refactor of existing code.

### Phase 8 (ADR-016): Virtual cards, built
Built on `feature/engine-cards` (see `docs/STATUS.md`). Read `docs/superpowers/specs/2026-11-07-virtual-cards-design.md` before changing it. The list below is the file map the work followed (no new crate, **no new dependency**); the wire fixtures are inline in `protocol_fixtures.rs` and `fixtures_test.dart`, and the hole-card oracle is `cards_leak.rs`:

```text
crates/poker_engine/src/{card.rs,deck.rs,hand_rank.rs,deal.rs,showdown.rs}   # new
crates/poker_engine/src/{lib.rs,state.rs,command.rs,machine.rs,event.rs}     # Table.deal, StartHand.deck, board_shown, reveals
crates/poker_engine/tests/{cards.rs,hand_rank.rs,deal.rs,showdown.rs}         # cards, exhaustive counts (runs in debug CI), wheel, ties, undo, replay
crates/poker_server_core/src/cards.rs                                        # Entropy trait, OsEntropy, FixedEntropy, shuffle
crates/poker_server_core/src/{protocol.rs,config.rs}                         # cardMode, features, HOLE_CARDS, UPDATE_REQUIRED, view fields
crates/poker_server_core/src/room/{state.rs,ops.rs,view.rs,actor.rs}         # AutoShowdown, deck in StartHand, projection, resend on snapshot
crates/poker_server_core/src/store/{snapshot.rs,journal.rs}                  # 0600 / 0700 permissions
crates/poker_server_core/src/net/http.rs                                     # cardMode on room and lobbies
crates/poker_server_core/tests/{cards_shuffle.rs,cards_flow.rs,cards_leak.rs,cards_replay.rs}
tool/check_no_state_logging.sh                                               # grep lint, wired into pre-commit and CI
protocol/fixtures/v1/*.json                                                  # one per new message, virtual RoomView
packages/poker_protocol/lib/src/{card.dart,...}                              # models; regenerate mappers
packages/poker_bridge/rust/src/api/server.rs                                 # cardMode in the bridge config
app/lib/widget/cards/{playing_card.dart,card_row.dart,board_view.dart,hole_cards_dock.dart,showdown_panel.dart}
app/lib/widget/player/opponent_strip.dart
app/lib/{model/room_state.dart,model/app_settings.dart,theme/tokens.dart,util/strings.dart}
app/lib/pages/{host_page.dart,join_page.dart,player_page.dart,table_page.dart}
```
Agent rules for this phase: all ranking and dealing in Rust; the shuffle is drawn in the actor and journaled, never in the reducer; no card text in logs or `Debug`; every new wire item gets a fixture on both sides first (principle 7); the no-leak oracle test must exist before the Player UI work starts.

## 4. Coding Principles for the Agent
1. **No game logic in Dart.** The app renders `RoomView` and sends intents. It does not compute pots, turns or legality beyond using `TURN_PROMPT.legal`.
2. **Idempotency.** Every `GAME_ACTION` carries `actionSeq`; the server enforces it.
3. **Pure engine.** `poker_engine` has no async, I/O, time or randomness.
4. **No panics in request paths.** No `unwrap`/`expect`/slice indexing outside tests. The clippy lints in `CODING_STANDARDS.md` 3.2 are mandatory.
5. **Errors are values.** Invalid input returns a typed error to that client only. It never crashes a room, and never takes down the process.
6. **Bounded everything.** Channels, queues, message sizes, connection counts.
7. **Types first.** Define Rust types and fixtures before Dart models and UI.
8. **Log, never swallow.** Every `catch` and every ignored `Result` logs with context.
9. **Pins.** Use `fvm flutter`/`fvm dart`; the Rust toolchain comes from `rust-toolchain.toml`.
10. **Web-safe by construction** (ADR-014): no `dart:io`/`dart:ffi`/`Platform.isX` outside `app/lib/platform/*_io.dart`; `poker_bridge` imported only from `platform/host_server_io.dart`; ints on the wire stay below 2^53.
11. **Brutalist UI only** (ADR-013): tokens from `theme/tokens.dart`, widgets from `widget/brutal/`, no stock Material visuals, no hex literals in widgets, fonts bundled.

## 5. Checks that must pass before you stop
```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
fvm dart format --set-exit-if-changed app/lib app/test packages
fvm flutter analyze
fvm flutter test
fvm flutter build web --no-web-resources-cdn   # web-safety smoke (ADR-014); run in app/
bash tool/check_web_safe.sh
```
Include the actual command output summary in your report. If a check was not run (for example no Android SDK), say so.

## 6. Approved dependencies
Exact versions are chosen in Phase 0 and recorded here before use. Anything not listed needs the user's approval.

**Rust:** `tokio`, `axum` (with `ws`), `serde`, `serde_json`, `thiserror`, `anyhow` (edges only), `tracing`, `tracing-subscriber`, `tracing-android` (Android only), `uuid`, `getrandom`, `subtle` (constant-time compare), `sha2`, `tempfile` (tests), `proptest` (dev), `flutter_rust_bridge`.

**Dart/Flutter:** `refena_flutter`, bundled fonts (Anton, Space Mono; Archivo Black was dropped with ADR-015; SIL OFL files in `app/assets/fonts/`, **no** `google_fonts` runtime download), `dart_mappable` (+builder), `web_socket_channel`, `wakelock_plus`, `pretty_qr_code`, a QR scanner plugin, `window_manager` (desktop), `path_provider`, `package_info_plus`, `device_info_plus`, `logging`, `flutter_secure_storage` (or equivalent), an audio plugin, `network_info_plus` is **not** needed (use `NetworkInterface.list()`), `build_runner`, `flutter_lints`, `mockito` or `mocktail` (pick one in Phase 0).

Versions in use (app, as of Phase 4): `refena_flutter ^3.7.0`, `web_socket_channel ^3.0.3`, `wakelock_plus ^1.7.0`, `pretty_qr_code ^3.6.0`, `path_provider ^2.1.6`, `fake_async ^1.3.3` (dev). `flutter_secure_storage ^11.2.0` holds the session tokens (Linux needs `libsecret-1-dev`); `mobile_scanner ^7.5.0` is the QR scanner (Android, iOS, macOS; typed address elsewhere). No audio plugin yet: `SystemSound` and `HapticFeedback`.

## 7. Starting a task
1. Read section 0 files.
2. `git checkout main && git pull` (if a remote exists), then create the phase branch.
3. Implement only the listed files.
4. Run section 5 checks.
5. Update `docs/STATUS.md` (what is done, what is next, any deviations and why).
6. Stop. Report to the user. Do not begin the next phase.

## 8. Which model does the work
Plan, audit and review with the strongest model; implement written briefs with a mid-tier model; do mechanical steps with a light one. Cheaper models get briefs that fix every file, signature, test and gate, plus the project pitfalls, and stop and report instead of guessing. Full policy, brief template and pitfalls: `docs/MODEL_STRATEGY.md`. No subagents unless the owner asks.

