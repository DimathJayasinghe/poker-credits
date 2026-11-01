# CLAUDE.md

Poker Credits: Flutter app + Rust engine/server for physical-card Texas Hold'em with digital chips.

**Current state and next step: `docs/STATUS.md`. Read it first.**

## Rules
- Always use **`fvm flutter`** / **`fvm dart`**, never the bare binaries (Flutter is pinned in `.fvmrc`, once Phase 0 exists).
- Rust toolchain is pinned in `rust-toolchain.toml`. Never set `panic = "abort"`.
- All game rules live in `crates/poker_engine`. The Dart app holds **no** poker rules.
- Do not add dependencies outside the list in `docs/AGENT_CODING_GUIDE.md` section 6 without asking.
- UI is neo-brutalist (`docs/UI_DESIGN.md`): use `widget/brutal/` and tokens only. Web is deferred but the code must stay web-safe (ADR-014): platform-specific code only in `app/lib/platform/`; run `bash tool/check_web_safe.sh`.
- Dev tooling, plugins and graphify: `docs/DEV_SETUP.md`.
- Commit only when asked. Conventional Commits, scopes in the agent guide.

## Doc map
| Need | File |
| :--- | :--- |
| Why / decisions | `docs/DECISIONS.md` |
| Components, state machine, pots | `docs/ARCHITECTURE.md` |
| Wire protocol | `docs/API_AND_EVENTS.md` |
| Crash handling, reconnect, journal | `docs/RESILIENCE_AND_CRASH_HANDLING.md` |
| Rules of poker as implemented | `docs/GAME_LOGIC_AND_RULES.md` |
| Security, edge cases | `docs/SECURITY_AND_EDGE_CASES.md` |
| Code standards, tests | `docs/CODING_STANDARDS.md` |
| Phase-by-phase tasks | `docs/AGENT_CODING_GUIDE.md` |
| UI design system | `docs/UI_DESIGN.md` |
| Dev setup, plugins, graphify | `docs/DEV_SETUP.md` |
| Plan | `pocker_credit_plan.md` |

## Reference repo
`~/Documents/dev_projects/localsend` is the design model (layout, FRB bridge, lifecycle recovery, init error app). Read-only reference; its own AGENTS.md disallows AI contributions upstream.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships. (Not built yet: build it with `/graphify .` once Phase 1 code exists; until `graphify-out/graph.json` exists, ignore the rules below. Setup details: `docs/DEV_SETUP.md`.)

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
