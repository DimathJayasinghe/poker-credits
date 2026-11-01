//! Standalone cloud server entry point. Real startup (config from env, panic hook, listener)
//! arrives in Phase 2.

fn main() {
    println!(
        "poker_server {} (protocol v{})",
        env!("CARGO_PKG_VERSION"),
        poker_server_core::PROTOCOL_VERSION
    );
}
