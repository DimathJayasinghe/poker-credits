# Project Status & Handoff

Last updated: 2026-11-01 (branch `docs/flutter-rust-pivot`).

## Where we are
**Design phase. No product code exists yet.** The old TypeScript scaffold was deleted (owner approved 2026-11-01). The stack was changed to **Flutter (app) + Rust (engine and server)**, and the docs were rewritten to match, using LocalSend (`~/Documents/dev_projects/localsend`) as the model for repo layout, Flutter-Rust bridging and crash handling.

### Done
- Studied LocalSend: workspaces (Cargo + pub), FRB + cargokit, `ServerEventV2`-style event channel, `ensureRunning` probe on resume, listener-failure restart, init error app, drop guards, signaling-server idle timeout / ping / per-IP limits, desktop single-instance, logcat logging, pinned toolchains.
- Verified LocalSend has **no** Rust panic strategy and no global Dart error hooks (only `runZonedGuarded` in child isolates). Those are our own design (ADR-011).
- Rewrote: `README.md`, `pocker_credit_plan.md`, `docs/DECISIONS.md` (ADR-001/002/003 superseded; ADR-008 to ADR-012 added), `docs/ARCHITECTURE.md` (head and tail; state machine and pot sections kept), `docs/API_AND_EVENTS.md` (WebSocket JSON protocol, resume handshake), `docs/CODING_STANDARDS.md`, `docs/AGENT_CODING_GUIDE.md`, `docs/SECURITY_AND_EDGE_CASES.md` (targeted edits).
- New: `docs/RESILIENCE_AND_CRASH_HANDLING.md`, this file, root `CLAUDE.md`.
- Owner decisions 2026-11-01: **neo-brutalist UI** (ADR-013, `docs/UI_DESIGN.md`); **web build later, codebase web-ready from day one** (ADR-014); old scaffold deleted; docs may be committed.
- Dev tooling added: `docs/DEV_SETUP.md`, `.fvmrc`, `rust-toolchain.toml`, `rustfmt.toml`, `clippy.toml`, `.editorconfig`, `.githooks/pre-commit` (enabled via `core.hooksPath`), `tool/check_web_safe.sh`, `tool/setup_dev.sh`, `tool/claude_post_edit.sh`, `.graphifyignore`, graphify rules in `CLAUDE.md`, `.vscode/extensions.json`, rewritten `.gitignore` and `.env.example`.
- Unchanged and still valid: `docs/GAME_LOGIC_AND_RULES.md` (language-neutral; checked for TypeScript references: none).

## Pending actions for the owner (blocked in auto mode)
1. Apply Claude Code project settings: `mkdir -p .claude && cp tool/claude-settings.proposed.json .claude/settings.json` (plugins, permissions, format hook).
2. `graphify hook install` (git post-commit/post-checkout hooks and merge driver) and optionally `graphify claude install`.
3. ~~Install toolchains~~ Done for Rust, rust-analyzer, FVM, Flutter 3.41.9 and Linux desktop packages. Remaining: Android cmdline-tools + licences, add `~/.cargo/bin` and `~/.pub-cache/bin` to your zsh `PATH`.
4. Build the first graph with `/graphify .` when ready (costs tokens), or wait for Phase 1 code.

## Next step
1. Owner reviews this doc set and the open questions below.
2. Start **Phase 0** (see `docs/AGENT_CODING_GUIDE.md` section 3) on a `chore/bootstrap` branch. Include the labelled throwaway spike for FRB/cargokit and panic behaviour.

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
1. ~~Browser guests~~ **Answered:** web later (Phase 7), codebase kept web-ready (ADR-014). Still open: should the web build also be able to **host**? Plan says no (host mode is native only).
2. Is iOS hosting required to work in the background? Plain iOS does not allow it; the plan says "keep the app in the foreground while hosting". If background hosting is a must, the cloud mode is the answer on iOS.
3. Cloud hosting target and budget (Fly.io, Render, your own VPS)? Affects the Dockerfile and data-volume docs only.
4. App name, bundle id and publisher accounts (Apple Developer, Google Play) for Phase 6.
5. Turn timer: add a small network-latency grace before auto-fold (see plan, RC-003)?
6. ~~Delete the old scaffold~~ Done.
7. Brutalist palette and fonts (`docs/UI_DESIGN.md` section 2: Archivo Black + Space Mono, signal yellow) are the assistant's proposal; confirm or adjust before Phase 4.

## Things to verify during Phase 0 / 3 (marked "verify" in docs)
- How `flutter_rust_bridge` surfaces a Rust panic in Dart (expected: exception; confirm and document).
- Whether iOS multicast entitlement still needs Apple approval (only matters for Phase 6 discovery).
- Exact plugin choices and versions for QR scanning, secure storage and audio.
- That the Rust toolchain version copied from LocalSend (`1.97.1`, as pinned there on 2026-11-01) is available locally; otherwise choose the current stable and record it.

## How to resume
1. Read this file, then `docs/DECISIONS.md` ADR-008 to ADR-012.
2. `git status` and `git log --oneline`; check which branch holds the latest work.
3. Follow `docs/AGENT_CODING_GUIDE.md` section 7 for the phase you are assigned.
