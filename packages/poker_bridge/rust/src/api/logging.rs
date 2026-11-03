//! Logging and panic reporting for the embedded server.
#![forbid(unsafe_code)]

use std::sync::Once;

use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

static INIT: Once = Once::new();

/// Runs once when the library is loaded (before any other call).
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // FRB's own hook records the backtrace that `PanicException` carries in Dart.
    flutter_rust_bridge::setup_default_user_utils();
    // Ours is installed after it and chains to it, so both keep working.
    poker_server_core::util::panic_hook::install();
}

/// Routes Rust logs to the platform log (logcat on Android, stderr elsewhere). Safe to call
/// more than once; only the first call has an effect.
///
/// `filter` uses the `RUST_LOG` syntax, for example `info` or `poker_server_core=debug`.
#[flutter_rust_bridge::frb(sync)]
pub fn init_logging(filter: String) {
    INIT.call_once(|| {
        let filter = EnvFilter::try_new(&filter).unwrap_or_else(|_| EnvFilter::new("info"));
        let registry = tracing_subscriber::registry().with(filter);
        #[cfg(target_os = "android")]
        {
            if let Ok(layer) = tracing_android::layer("PokerCredits") {
                let _already_set = registry.with(layer).try_init();
                return;
            }
        }
        let _already_set = registry
            .with(tracing_subscriber::fmt::layer().with_writer(std::io::stderr))
            .try_init();
    });
}

/// Makes the Rust side panic. For the Dart-side tests of the panic handling only.
#[cfg(feature = "test-hooks")]
#[flutter_rust_bridge::frb(sync)]
#[allow(clippy::panic, reason = "the point of this function")]
pub fn panic_for_test() {
    panic!("test panic requested from Dart");
}
