# Phase 0 Spike: flutter_rust_bridge findings

Throwaway spike (not in the repo) run on 2026-11-01/02 to learn how `flutter_rust_bridge` (FRB) and cargokit behave before Phase 3. Tooling: `flutter_rust_bridge_codegen` 2.13.0, Rust 1.97.1, Flutter 3.41.9, Ubuntu 26.04.

## Results

| Question | Result |
| :--- | :--- |
| Does FRB + cargokit build and run on Linux desktop? | **Yes.** `flutter test integration_test -d linux` compiled the Rust library through cargokit, loaded it and called it. |
| How does a Rust panic surface in Dart? | As a Dart **`PanicException`** (class from the `flutter_rust_bridge` package) whose text carries the panic message and a full **Rust backtrace**. Verified for a synchronous (`#[frb(sync)]`) function and for an `async fn`. |
| Does the app survive a panic? | **Yes.** After both panics, a following call returned normally. The panic is converted at the boundary; the process does not abort (we do not set `panic = "abort"`). |
| Does it build for Android? | See "Android" below. |

## What this means for the design
- The bridge facade (`packages/poker_bridge/lib`) must catch `PanicException` at every call and map it to a typed app error (log with the Rust backtrace, show a non-fatal error, offer to restart the embedded server). This closes the "verify" item in `RESILIENCE_AND_CRASH_HANDLING.md` section 1.
- FRB only reports panics that happen **inside a bridged call**. A panic in a spawned tokio task (a room actor) never reaches Dart by itself. That is exactly why the room supervisor reports `ROOM_RECOVERED` / `ROOM_CRASHED` through the `ServerEvent` stream (ADR-011); do not rely on FRB for background-task panics.
- FRB installs its own panic hook (`setup_default_user_utils` in the template's `init_app`) that records the backtrace. Our `util/panic_hook.rs` must chain to the previous hook, not replace it (already specified: "chain to the previous hook").

## Practical notes for Phase 3
- Template layout: the Flutter package contains `rust/` (the crate `rust_lib_<name>`), `rust_builder/` (cargokit plugin), `lib/src/rust/` (generated Dart) and `flutter_rust_bridge.yaml` (`rust_input: crate::api`, `rust_root: rust/`, `dart_output: lib/src/rust`). Our ADR-009 puts this under `packages/poker_bridge/`; generate the package with `flutter_rust_bridge_codegen create` / `integrate` and move it, then trim the demo code.
- `flutter_rust_bridge_codegen generate` needs a Rust toolchain resolvable from the crate directory. Inside this repo `rust-toolchain.toml` provides it; outside the repo set `RUSTUP_TOOLCHAIN=1.97.1`.
- Codegen runs `cargo expand` and **installs `cargo-expand` automatically** on first use (an extra download and compile). Install it once up front: `cargo install cargo-expand --locked`.
- FRB Dart and Rust dependencies must be pinned to the codegen version (2.13.0): `flutter_rust_bridge: 2.13.0` in pubspec, `flutter_rust_bridge = "=2.13.0"` in Cargo.toml.
- Integration tests that load the native library open a real window and need a display; keep them out of the default CI job (run them in a separate desktop job or locally).
- Cargokit builds for every enabled ABI; the first Android build is slow and downloads Gradle, the NDK pieces and crates. Use `--target-platform android-arm64` for quick checks.
