//! Bridge between the Flutter app and the embedded `poker_server_core` server.
//!
//! Everything Dart can call lives in [`api`]; `flutter_rust_bridge_codegen generate` turns it
//! into `frb_generated.rs` and `lib/src/rust/`. The Dart side wraps every call in a facade that
//! catches `PanicException` (see `docs/SPIKE_BRIDGE_FINDINGS.md`).

pub mod api;

// Generated code: uses `unsafe` and does not follow our lint rules. Do not edit it by hand.
#[allow(
    unsafe_code,
    missing_docs,
    clippy::all,
    clippy::pedantic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic
)]
mod frb_generated;
