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

Machine state on the dev machine (2026-11-01, Ubuntu): installed and verified: rustup 1.29.2 with the pinned Rust 1.97.1, rust-analyzer, Android Rust targets (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`), FVM 4.3.2 with the pinned Flutter 3.41.9 (`fvm install`), and the Linux desktop packages (`clang cmake ninja-build pkg-config libgtk-3-dev build-essential`). Both pins from LocalSend resolved fine. Also installed: Android `cmdline-tools` (in `~/Android/Sdk`) with all SDK licences accepted at your request, `flutter_rust_bridge_codegen` 2.13.0 (**the `flutter_rust_bridge` Dart and Rust dependencies must be pinned to 2.13.0** in Phase 3), `cargo-nextest` 0.9.150, `cargo-deny` 0.20.2, and the graphify git hooks. `fvm flutter doctor` reports no issues. **Still open:** shells need `~/.cargo/bin` and `~/.pub-cache/bin` on `PATH`; auto mode refused to edit `~/.zshrc`, so add `. "$HOME/.cargo/env"` and `export PATH="$PATH:$HOME/.pub-cache/bin"` there yourself. `.claude/settings.json` is also not applied (refused as self-modification). `bash tool/setup_dev.sh --install` can redo these steps, asking first.

Platform extras (only for the targets you build): Android SDK + NDK and `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`; Linux desktop needs `clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev` (plus `libsecret-1-0` and a keyring such as gnome-keyring at run time, for the session tokens); `flutter build linux` also needs `ld` and `ar` next to llvm's `clang` (install `lld`, or put wrapper scripts on `PATH`); Windows needs Visual Studio 2022 with the C++ desktop workload; iOS/macOS need Xcode and the Apple Rust targets.

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
| `pr-review-toolkit` | Review agents for error handling, test coverage, types and comments before each phase merge. |
| `chrome-devtools-mcp` | Inspect and screenshot the live Flutter web build, profile performance, check console errors (UI verification from Phase 4). |
| `commit-commands` | Commit / push / PR workflows. |

UI/design skills already present at user level and useful here: `vectorlab-ui-ux-skills` (spacing, typography, colour, anti-slop, forms, motion, reduced motion, empty states) and `ui-theme-designer`. Installed on 2026-11-01 at user scope with `claude plugin install <name>@claude-plugins-official`: `rust-analyzer-lsp`, `pr-review-toolkit`, `chrome-devtools-mcp`, `commit-commands`. They load on the next Claude Code session start.

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
- `.gitignore`: ignores all of `graphify-out/`. The post-commit hook rewrites the graph after every commit, so tracking it would leave the tree dirty after each commit. Each clone builds its own graph. Revisit committing `graph.json` once there is real code.
- `CLAUDE.md`: contains the same "## graphify" section that `graphify claude install` writes (query before grep, `graphify update .` after code changes). It applies once a graph exists.

### Hooks (installed on this clone)
`graphify hook install` was run: `.githooks/post-commit` and `.githooks/post-checkout` rebuild the code graph after commits and checkouts (AST only, no LLM), and `.gitattributes` maps `graphify-out/graph.json` to graphify's union merge driver (unused while the graph is ignored). The hook files are committed; the merge driver is local git config, so after every fresh clone run `graphify hook install` again. Not installed: `graphify claude install` (it edits `.claude/settings.json`, which auto mode refuses; its `CLAUDE.md` text is already in the repo).

### Building the graph
- Now (docs only): `/graphify .` extracts concepts from the Markdown docs with LLM subagents. It costs tokens; worth doing once the docs settle.
- From Phase 1 on: code changes are indexed locally with no API cost: `graphify update .` (AST only). For a first code-only build: `graphify extract . --code-only`. For Rust dependency edges add `--cargo`.
- Query: `graphify query "how does a room recover from a panic"`, `graphify path "RoomActor" "Journal"`, `graphify explain "Supervisor"`, `graphify god-nodes`.

## 4. Git hooks and scripts

| File | Purpose |
| :--- | :--- |
| `.githooks/pre-commit` | Enable with `git config core.hooksPath .githooks` (already set in this clone). Runs `cargo fmt --check`, `cargo clippy` and `check_no_state_logging.sh` for staged Rust, `dart format` and `check_web_safe.sh` for staged Dart. Each part skips itself when the tool or project part does not exist yet. |
| `.githooks/commit-msg` | Rejects commit messages containing AI/tool attribution (`Co-Authored-By: Claude`, "Generated with ...", robot emoji). Project rule; also applies to PR text, which no hook can check, so review it by hand. |
| `tool/check_web_safe.sh` | ADR-014/013 guard: banned imports (`dart:io`, `dart:ffi`, `Platform.isX`, `poker_bridge`) in web-safe code, colour literals outside `theme/tokens.dart`, `google_fonts`, stray `kIsWeb`. CI runs it. |
| `tool/check_no_state_logging.sh` | ADR-016 guard: fails on a `tracing` macro that formats state, an op, a message, a view or cards with `?` or `%` (the deck would end up in a log). `--self-test` shows it still catches a planted violation. CI (rust job) and the pre-commit hook run it. |
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

## Sound effects
- The clips in `app/assets/sounds/` are generated: `python3 tool/sounds/make_sounds.py` (numpy only), then `python3 tool/sounds/analyze.py` (add `--images` for spectrograms in `$TMPDIR`). Open `tool/sounds/audition.html` in a browser to listen to them one by one.
- Linux desktop builds need `libasound2-dev` (`sudo apt install libasound2-dev`); CI installs it. Without sudo: `apt-get download libasound2-dev`, unpack it with `dpkg -x` and point `CPATH` at `usr/include`.
- To hear what the app really outputs without using the speakers on Linux: create a null sink (`pactl load-module module-null-sink sink_name=smoke_sink`), run the app with `PIPEWIRE_NODE=smoke_sink`, and record `smoke_sink.monitor` with `parec`.
