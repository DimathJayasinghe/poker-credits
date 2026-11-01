# Developer Setup

Everything needed to work on Poker Credits: toolchains, Claude Code plugins, graphify, git hooks and the helper scripts. Run `bash tool/setup_dev.sh` at any time for a checklist of what is missing on your machine.

## 1. Toolchains

| Tool | Why | Install |
| :--- | :--- | :--- |
| **rustup + cargo** | Rust workspace. Version comes from `rust-toolchain.toml` (rustup installs it on first use). | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| **rust-analyzer** | Code intelligence, also used by the Claude Code LSP plugin. | `rustup component add rust-analyzer` |
| **FVM** | Pins Flutter per `.fvmrc`. Always run `fvm flutter` / `fvm dart`. | `dart pub global activate fvm` (add `~/.pub-cache/bin` to `PATH`), then `fvm install` in the repo |
| **flutter_rust_bridge_codegen** | Generates Dart/Rust bridge code. Version must match the `flutter_rust_bridge` dependency. | `cargo install flutter_rust_bridge_codegen` (Phase 3) |
| **cargo-nextest**, **cargo-deny** (optional) | Faster tests, dependency and licence audit. | `cargo install cargo-nextest cargo-deny --locked` |
| **graphify** | Knowledge graph of the codebase (section 3). | `uv tool install graphifyy` or `pip install graphifyy` |

Machine state on the dev machine (2026-11-01, Ubuntu): installed and verified: rustup 1.29.2 with the pinned Rust 1.97.1, rust-analyzer, Android Rust targets (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`), FVM 4.3.2 with the pinned Flutter 3.41.9 (`fvm install`), and the Linux desktop packages (`clang cmake ninja-build pkg-config libgtk-3-dev build-essential`). Both pins from LocalSend resolved fine. **Still open:** Android `cmdline-tools` and licence acceptance (`fvm flutter doctor --android-licenses`, you must accept the licences yourself), `flutter_rust_bridge_codegen` (Phase 3, version must match the pubspec dependency), optional `cargo-nextest`/`cargo-deny`. Shells need `~/.cargo/bin` and `~/.pub-cache/bin` on `PATH` (zsh does not source `~/.profile` in every setup; add both to `~/.zshrc`). `bash tool/setup_dev.sh --install` can redo these steps, asking first.

Platform extras (only for the targets you build): Android SDK + NDK and `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`; Linux desktop needs `clang cmake ninja-build pkg-config libgtk-3-dev`; Windows needs Visual Studio 2022 with the C++ desktop workload; iOS/macOS need Xcode and the Apple Rust targets.

Pins: `.fvmrc` (Flutter 3.41.9) and `rust-toolchain.toml` (Rust 1.97.1) were copied from LocalSend on 2026-11-01 as starting points. If the installed versions differ or are unavailable, change the pin, say so in `docs/STATUS.md`, and keep CI in sync.

## 2. Claude Code plugins and project settings

Recommended plugins for this repo (all from `claude-plugins-official`):

| Plugin | Use here |
| :--- | :--- |
| `rust-analyzer-lsp` | Rust diagnostics and navigation (needs `rust-analyzer` on `PATH`). |
| `feature-dev` | Guided feature work and architecture/review agents for each phase. |
| `code-review`, `code-simplifier` | Review before every phase commit. |
| `security-guidance` | Token handling, input validation, network code. |
| `context7` | Up-to-date docs for axum, tokio, serde, Flutter, Refena, flutter_rust_bridge. |
| `superpowers` | Brainstorming, TDD, planning, verification workflows. |
| `frontend-design` | Neo-brutalist UI work (`docs/UI_DESIGN.md`). |
| `claude-md-management` | Keep `CLAUDE.md` accurate. |

`typescript-lsp` (enabled in the user-level settings from the earlier project) is irrelevant now and the proposed project file switches it off here.

There is no official Dart LSP plugin in the catalog. The Dart analysis server runs inside VS Code (Dart-Code) and via `fvm flutter analyze`.

### Applying the project settings (needs your action)
The ready-made project settings live at **`tool/claude-settings.proposed.json`**. They contain: the plugin list above, an allow-list of **exact** commands (no wildcards on `cargo`, `fvm` or `git`, because flags such as `--config`, `-Z`, `--output` and `--ext-diff` can turn an allowed command into arbitrary execution; anything else prompts, including `build_runner`, codegen, `cargo build`), read-only `graphify` queries, a deny-list for `.env`, signing keys, `RUSTC_WRAPPER`, `--config` and `-Z`, and protection of `.claude/`, `.githooks/` and the format-hook script from agent edits, and a `PostToolUse` hook that auto-formats edited `.rs`/`.dart` files through `tool/claude_post_edit.sh`.

Claude Code's auto mode refused to write `.claude/settings.json` itself (it counts as self-modification of permissions and hooks), so apply it yourself after reviewing it:

```bash
mkdir -p .claude && cp tool/claude-settings.proposed.json .claude/settings.json
```

Then restart Claude Code in the repo and install the plugins when prompted. Commit `.claude/settings.json` so the setup is shared. Personal overrides go in `.claude/settings.local.json` (not committed).

## 3. graphify (codebase knowledge graph)

graphify turns the repo into a queryable graph (god nodes, communities, relationships) so Claude can answer architecture questions with a small subgraph instead of reading files.

### Already configured in the repo
- `.graphifyignore`: excludes build output, generated code (FRB, mappers), platform scaffolding, fonts and images, fixtures, secrets.
- `.gitignore`: commits `graphify-out/graph.json` and `GRAPH_REPORT.md`, ignores the cache, scratch files and `graph.html`.
- `CLAUDE.md`: contains the same "## graphify" section that `graphify claude install` writes (query before grep, `graphify update .` after code changes). It applies once a graph exists.

### Steps for you (blocked in auto mode, need your approval)
Auto mode refused to run these because they register persistent hooks:
```bash
graphify hook install     # post-commit and post-checkout git hooks, plus a merge driver for graph.json
graphify claude install   # optional: adds the PreToolUse nudge hook to .claude/settings.json
```
`core.hooksPath` is `.githooks`, so `graphify hook install` appends to files in `.githooks/`. If you prefer not to commit those, run `git config --local core.hooksPath ""` first and keep graphify's hooks in `.git/hooks`, then use `.githooks/pre-commit` manually.

### Building the graph
- Now (docs only): `/graphify .` extracts concepts from the Markdown docs with LLM subagents. It costs tokens; worth doing once the docs settle.
- From Phase 1 on: code changes are indexed locally with no API cost: `graphify update .` (AST only). For a first code-only build: `graphify extract . --code-only`. For Rust dependency edges add `--cargo`.
- Query: `graphify query "how does a room recover from a panic"`, `graphify path "RoomActor" "Journal"`, `graphify explain "Supervisor"`, `graphify god-nodes`.

## 4. Git hooks and scripts

| File | Purpose |
| :--- | :--- |
| `.githooks/pre-commit` | Enable with `git config core.hooksPath .githooks` (already set in this clone). Runs `cargo fmt --check` and `cargo clippy` for staged Rust, `dart format` and `check_web_safe.sh` for staged Dart. Each part skips itself when the tool or project part does not exist yet. |
| `tool/check_web_safe.sh` | ADR-014/013 guard: banned imports (`dart:io`, `dart:ffi`, `Platform.isX`, `poker_bridge`) in web-safe code, colour literals outside `theme/tokens.dart`, `google_fonts`, stray `kIsWeb`. CI runs it. |
| `tool/setup_dev.sh` | Toolchain checklist and optional installer. |
| `tool/claude_post_edit.sh` | Formatter hook used by Claude Code (inert until the settings are applied). |
| `rustfmt.toml`, `clippy.toml`, `.editorconfig` | Formatter and lint thresholds. Lint levels live in the root `Cargo.toml` `[workspace.lints]` (created in Phase 0). |
| `.vscode/extensions.json` | Recommends rust-analyzer, Dart/Flutter, TOML, EditorConfig, CodeLLDB. |

## 5. Cloning on a fresh machine
```bash
git clone <repo> && cd pocker-credits
bash tool/setup_dev.sh --install
git config core.hooksPath .githooks
fvm install            # Flutter from .fvmrc
cargo --version        # rustup installs rust-toolchain.toml on first use
```
