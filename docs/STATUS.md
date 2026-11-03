# Project Status & Handoff

Last updated: 2026-11-02 (branch `feature/engine-core`, stacked on the unmerged `chore/bootstrap`).

## Where we are
**Phase 0 (bootstrap) is done and Phase 1 (engine) is implemented for review.** The old TypeScript scaffold was deleted (owner approved 2026-11-01). The stack was changed to **Flutter (app) + Rust (engine and server)**, and the docs were rewritten to match, using LocalSend (`~/Documents/dev_projects/localsend`) as the model for repo layout, Flutter-Rust bridging and crash handling.

### Done
- Studied LocalSend: workspaces (Cargo + pub), FRB + cargokit, `ServerEventV2`-style event channel, `ensureRunning` probe on resume, listener-failure restart, init error app, drop guards, signaling-server idle timeout / ping / per-IP limits, desktop single-instance, logcat logging, pinned toolchains.
- Verified LocalSend has **no** Rust panic strategy and no global Dart error hooks (only `runZonedGuarded` in child isolates). Those are our own design (ADR-011).
- Rewrote: `README.md`, `pocker_credit_plan.md`, `docs/DECISIONS.md` (ADR-001/002/003 superseded; ADR-008 to ADR-012 added), `docs/ARCHITECTURE.md` (head and tail; state machine and pot sections kept), `docs/API_AND_EVENTS.md` (WebSocket JSON protocol, resume handshake), `docs/CODING_STANDARDS.md`, `docs/AGENT_CODING_GUIDE.md`, `docs/SECURITY_AND_EDGE_CASES.md` (targeted edits).
- New: `docs/RESILIENCE_AND_CRASH_HANDLING.md`, this file, root `CLAUDE.md`.
- Owner decisions 2026-11-01: **neo-brutalist UI** (ADR-013, `docs/UI_DESIGN.md`); **web build later, codebase web-ready from day one** (ADR-014); old scaffold deleted; docs may be committed.
- Dev tooling added: `docs/DEV_SETUP.md`, `.fvmrc`, `rust-toolchain.toml`, `rustfmt.toml`, `clippy.toml`, `.editorconfig`, `.githooks/pre-commit` (enabled via `core.hooksPath`), `tool/check_web_safe.sh`, `tool/setup_dev.sh`, `tool/claude_post_edit.sh`, `.graphifyignore`, graphify rules in `CLAUDE.md`, `.vscode/extensions.json`, rewritten `.gitignore` and `.env.example`.
- Unchanged and still valid: `docs/GAME_LOGIC_AND_RULES.md` (language-neutral; checked for TypeScript references: none).

## Pending actions for the owner (blocked in auto mode)
1. Apply Claude Code project settings yourself (auto mode refuses to write them): `mkdir -p .claude && cp tool/claude-settings.proposed.json .claude/settings.json` (plugins, permissions, format hook).
2. ~~graphify hooks~~ Installed. Optional `graphify claude install` still not run (edits `.claude/settings.json`).
3. ~~Install toolchains~~ Done for Rust, rust-analyzer, FVM, Flutter 3.41.9 and Linux desktop packages. Android cmdline-tools, licences, FRB codegen 2.13.0, nextest and deny are installed too. Remaining: add `~/.cargo/bin` and `~/.pub-cache/bin` to your zsh `PATH` (I could not edit `~/.zshrc`).
4. Build the first graph with `/graphify .` when ready (costs tokens), or wait for Phase 1 code.

## Phase 0 status
Done on branch `chore/bootstrap` (not merged): Cargo workspace with empty crates, Flutter app (6 platforms) with pub workspace, `poker_protocol` package, brutalist theme skeleton (tokens, BrutalButton, BrutalCard), init error screen, global error hooks, platform seam, bundled fonts, CI workflow, platform permissions, bridge spike. Verified locally: `cargo fmt/clippy/test`, `flutter analyze`, 25 Dart tests, `tool/check_web_safe.sh`, `flutter build web --no-web-resources-cdn`, `flutter build linux`, Linux app launches, spike Android APK builds. **Not verified:** iOS/macOS/Windows builds (need those OSes), CI on GitHub (never pushed), `ws://` on real devices (Phase 5).

## Phase 1 status (engine)
Implemented on `feature/engine-core` (branched from `chore/bootstrap`, nothing committed yet): `crates/poker_engine` with `types`, `state`, `command`, `event`, `error`, `validator`, `pots`, `blinds`, `button`, `machine`, `undo`. Verified locally: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace` (92 tests; the 3 proptest properties check that chips are conserved over arbitrary command sequences, that rejected commands never mutate state, that accepted commands replay to an identical state through a JSON snapshot round trip, and that every command built from the engine's own legal actions is accepted). Rules the spec left open are listed in `docs/GAME_LOGIC_AND_RULES.md` section 9 for owner review.

Deviations from the guide's file list: there is no separate `AdminCommand`; all commands are variants of `Command`, and `Command::origin()` returns `Player`, `Host` or `Server` so the server can enforce who may send what (`Timeout` is `Server`: only the turn timer may time a player out; the server must bind `player_id` to the session for `Action` and `SetSittingOut`). `undo.rs` is public, not private.

## Phase 2 status (server core), in progress on `feature/server-core`
Done and committed: `protocol.rs` + golden fixtures, `config.rs` (Limits, Timings), `util/` (room code, token hash, panic hook), `room/state.rs` + `room/ops.rs` (pure `RoomState::apply` reducer: join, act, timeout, host commands, rebuy, presence check, removals), `room/view.rs`, `store/` (atomic `snapshot.json`, fsynced `journal.jsonl` with poisoned-entry marks, `store::restore`). Tests: `tests/reducer.rs` (20), `tests/store.rs` (7: replay equals live, cut-off last line ignored, mid-file corruption detected, snapshot/journal overlap). Verified: fmt, clippy `-D warnings`, `cargo test --workspace`.

Also done: `room/actor.rs` + `room/handle.rs` (one task per room; every change is applied to a clone, journaled, then swapped in and broadcast; snapshot plus journal truncate at hand end, config change and rebuy; turn timeout and presence ticks from a paused-time-friendly `Clock`; room TTL; slow consumers dropped by `try_send`; `create()` and `restore()`). `tests/actor.rs` (10 tests over plain channels). The reducer id counter now advances inside `Op::Join` so replay reproduces ids.

Also done: `supervisor.rs` (awaits each room task; on panic rebuilds from snapshot plus journal, marks a journal entry poisoned if replay itself panics, freezes the room at 3 panics within 60 s or when there is no data folder), `registry.rs` (`create_room`, `join_room`, `resume_room`, `restore_all`, `shutdown`, `max_rooms`, unique codes), `room/session.rs` (a connection's link that re-attaches to the restarted room: `ROOM_RECOVERED` then `SNAPSHOT`, or `ROOM_CRASHED` when frozen), `ConnSender`/`ConnReceiver` (the actor can close a connection even though the socket task keeps a sender for re-attach). Panic tests use the `test-hooks` cargo feature (enabled only through the crate's own dev-dependency; verified absent from the `poker_server` feature tree). `tests/supervision.rs` (9 tests).

Also done (Phase 2 complete, pending owner review):
- **Disconnect rules** (`room/absence.rs`, journaled as `Op::DisconnectTimeout` / `Op::SetSittingOut`): a player on turn with no connection is checked or folded for after 30 s (counted from the later of the disconnect and the turn start); a seat with no connection for 10 minutes is sat out. After a server restart everybody counts as disconnected until they resume.
- **One live connection per participant**: a newer one gets the seat, the older one receives `SUPERSEDED` and is closed, with no disconnect notice.
- **Network layer** (`net/`): `GET /v1/ws`, `/health`, `/v1/info`, `/v1/room/{code}` (rate limited per IP). First message must be `CREATE_ROOM`, `JOIN_ROOM` or `RESUME` within 10 s (`PING` is allowed); fixable join errors keep the socket open. 16 KiB frames, idle timeout reset only by inbound frames, token bucket with 3 strikes, per-IP connection cap with a drop guard, write timeout, and a `Session` drop guard that always tells the room.
- **`start()` / `ServerHandle` / `ServerEvent`** in `lib.rs`, `event.rs`; `server/` binary reads `POKER_BIND` (default `0.0.0.0:7878`), `POKER_DATA_DIR` (default `./data`), `POKER_SERVER_NAME`, `RUST_LOG`; stops cleanly on Ctrl-C or SIGTERM.
- **Abuse limits** (security review): wrong room codes and tokens are counted per IP across connections (20 per minute, then a 15 minute block); `CREATE_ROOM` 6 per minute per IP; every inbound data frame, garbage included, is charged to the connection bucket and only well-formed requests reset the idle timer; the last queued message (for example `ROOM_EXPIRED`) is flushed before a socket closes because its room ended.
- **Journal fix:** a poisoned entry's sequence number is never reused (`journal::read` reports the highest number on any line).
- **Plan RC checklist (pocker_credit_plan.md section on RC tests):** RC-001 `tests/actor.rs` `rc001_*`; RC-002 `tests/net.rs` `a_hand_over_real_sockets` and `tests/actor.rs`; RC-003 `rc003_*` (with paused clock); RC-004 `rc004_*`; RC-005 `tests/reducer.rs` `rc005_*`; RC-006 actor-level slow consumer test; RC-007 `the_room_survives_a_restart_from_disk` and `rooms_survive_a_server_restart`; RC-008 `rc008_*` in `tests/supervision.rs`. Property test `tests/replay_property.rs`: 64 random sequences of joins, hands, actions, undo, pause/resume, timeouts, top-ups, kicks, sit-outs and snapshots at random points; after every step `restore(snapshot + journal)` equals the live state. Coverage note: accepted operations reach 7 hands, undo, pause, kicks and top-ups, but random play essentially never reaches `BEGIN_SHOWDOWN` / `RESOLVE_SHOWDOWN` (needs everybody all-in), so showdown replay is only covered by the engine's own property tests, not by this one.
- **Tests:** `tests/net.rs` (26, real sockets with a hand-written minimal WebSocket client in `tests/support/ws_client.rs`, so no new dependency): HTTP endpoints, framing, auth, idle and auth timeouts, rate limit, per-IP cap, a hand with duplicate action, concurrent joins (never more than 10 seats, one winner per seat), resume, wrong tokens, superseding, kick, server restart, crash recovery under connected sockets. Verified: fmt, clippy `-D warnings`, `cargo test --workspace`, binary smoke run with curl and SIGTERM.

Deviations from the guide, for review:
- `ServerConfig.data_dir` is `Option<PathBuf>` (tests run in memory) and `events` is an optional bounded sender; `ServerEvent` is minimal (`Listening`, `RoomsRestored`, `Stopped`).
- No `SeatReservationGuard`: a join is one atomic step inside the room actor, so nothing is reserved across an `.await`. A join whose connection dies before `JOINED` is delivered leaves a seated, disconnected player; the grace, 10 minute and presence rules clean that up.
- Behind a reverse proxy every client appears as the proxy's IP (per-IP caps would hit all players together). A `trust_proxy` option reading `X-Forwarded-For` is not implemented; decide before deploying behind one.
- `everyone_hears_room_expired_before_the_socket_closes` passes with and without the flush fix in a local mutation check (the race is too narrow to trigger from outside); it guards the behaviour, it does not prove the race fixed.
- Not tested over real sockets: a slow reader filling the outbound queue (needs megabytes of unread data). The policy itself (queue full means the room drops the connection) is tested at actor level in `tests/actor.rs`, and a room-side close ending the socket is tested through the kick test.
- Not tested: a journal replay that panics (poisoning path).

Still to do: Phase 3 (protocol package and bridge), plus open owner questions below. Update `docs/API_AND_EVENTS.md` section 6 error list if the exhaustive `PokerError` mapping gained codes (check against `protocol.rs`).

`main` was fast-forwarded locally (not pushed) to the store commit `056923d` on 2026-11-03; the actor work is on `feature/server-core` only.

## Next step
1. Owner reviews Phase 0 (`chore/bootstrap`) and Phase 1 (`feature/engine-core`, which contains Phase 0) and merges to `main`.
2. Start **Phase 2** (server core and cloud binary) after approval. The engine's `PokerError` variants `NothingToCall`, `BettingNotReopened`, `NotPaused`, `NotEnoughPlayers`, `UnknownPlayer`, `PlayerExists`, `InvalidSeat`, `InvalidAmount`, `Overflow`, `IllegalTransition`, `NothingToUndo` and `InvalidAllocation` have no wire code yet in `API_AND_EVENTS.md` section 6; add them when writing the exhaustive `From<PokerError> for ErrorCode`.
3. Open owner questions from the engine work: when busted players are removed (decision 19; the policy below proposes a 2-minute rebuy window first). Inactive-player policy approved 2026-11-02 and recorded in `RESILIENCE_AND_CRASH_HANDLING.md` section 3.8 (engine layer done; presence check with 90 s vote and the busted-player rebuy window are Phase 2). Answered 2026-11-02: no missed-blind catch-up (decision 10); several short all-ins that add up reopen betting per TDA rule 47 (decision 4).

## Decisions made by the assistant (not yet confirmed by the owner)
Please confirm or change; each is recorded in the docs.
| # | Call | Where |
| :--- | :--- | :--- |
| 1 | (Superseded by owner decision) Web is later, code web-ready now; web build is Player/Spectator only, no hosting from the browser. | ADR-014 |
| 2 | Host's own UI connects to its embedded server over loopback WebSocket (one code path for host, LAN, cloud). | ADR-004, Architecture 3.4 |
| 3 | No Dart child isolates at first; Rust runs on its own threads. | Architecture 3.5 |
| 4 | Refena + dart_mappable kept from LocalSend. | ADR-008 |
| 5 | Crate/package names and layout (`crates/poker_engine`, `crates/poker_server_core`, `server/`, `packages/poker_protocol`, `packages/poker_bridge`). | ADR-009 |
| 6 | Write-ahead action journal in addition to snapshots, so a mid-hand kill loses nothing. | ADR-011 |
| 7 | Timings: ping 15 s, idle timeout 45 s, turn grace on disconnect 30 s, room TTL 60 min, 10 players, 20 spectators. | Resilience 3.6 |
| 8 | LAN uses plain `ws://`; TLS with fingerprint in QR deferred. | ADR-012 |
| 9 | QR is the primary LAN join path; multicast discovery is Phase 6 optional. | ADR-012 |
| 10 | Default port 7878 for host mode. | Architecture 6.1 |
| 11 | `actionSeq` is monotonic per session, server-owned (`nextActionSeq`), advances only on applied actions. | API 5.3 |

## Open questions for the owner
0. **Downtime and turn deadlines** (new): deadlines are absolute, so a player on turn when the server went down is timed out right after a restart, before anyone can reconnect. Extend deadlines by the downtime on restore, or keep it? Also: 4-character room codes (about 1 million) are the weak point of cloud mode even with per-IP limits; consider 6 characters. And: behind a reverse proxy the per-IP limits need `X-Forwarded-For` support, which does not exist yet.
1. ~~Browser guests~~ **Answered:** web later (Phase 7), codebase kept web-ready (ADR-014). Still open: should the web build also be able to **host**? Plan says no (host mode is native only).
2. Is iOS hosting required to work in the background? Plain iOS does not allow it; the plan says "keep the app in the foreground while hosting". If background hosting is a must, the cloud mode is the answer on iOS.
3. Cloud hosting target and budget (Fly.io, Render, your own VPS)? Affects the Dockerfile and data-volume docs only.
4. App name, bundle id and publisher accounts (Apple Developer, Google Play) for Phase 6.
5. Turn timer: add a small network-latency grace before auto-fold (see plan, RC-003)?
6. ~~Delete the old scaffold~~ Done.
7. Brutalist palette and fonts (`docs/UI_DESIGN.md` section 2: Archivo Black + Space Mono, signal yellow) are the assistant's proposal; confirm or adjust before Phase 4.

## Things to verify during Phase 0 / 3 (marked "verify" in docs)
- ~~How `flutter_rust_bridge` surfaces a Rust panic in Dart~~ Verified in the Phase 0 spike: `PanicException`, app survives. See `docs/SPIKE_BRIDGE_FINDINGS.md`.
- Whether iOS multicast entitlement still needs Apple approval (only matters for Phase 6 discovery).
- Exact plugin choices and versions for QR scanning, secure storage and audio.
- That the Rust toolchain version copied from LocalSend (`1.97.1`, as pinned there on 2026-11-01) is available locally; otherwise choose the current stable and record it.

## How to resume
1. Read this file, then `docs/DECISIONS.md` ADR-008 to ADR-012.
2. `git status` and `git log --oneline`; check which branch holds the latest work.
3. Follow `docs/AGENT_CODING_GUIDE.md` section 7 for the phase you are assigned.
