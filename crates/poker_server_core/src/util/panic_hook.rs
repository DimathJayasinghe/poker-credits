//! Process-wide panic hook: log message, location and backtrace through `tracing`, then call the
//! previous hook. `panic = "abort"` must never be set; room supervision relies on unwinding.

use std::backtrace::Backtrace;
use std::panic;

/// Installs the hook once. Safe to call again; each call chains to the previous hook.
pub fn install() {
    let previous = panic::take_hook();
    panic::set_hook(Box::new(move |info| {
        let location = info.location().map_or_else(
            || "unknown location".to_owned(),
            |l| format!("{}:{}:{}", l.file(), l.line(), l.column()),
        );
        let payload = info
            .payload()
            .downcast_ref::<&str>()
            .map(|s| (*s).to_owned())
            .or_else(|| info.payload().downcast_ref::<String>().cloned())
            .unwrap_or_else(|| "non-string panic payload".to_owned());
        tracing::error!(%location, %payload, backtrace = %Backtrace::force_capture(), "panic");
        previous(info);
    }));
}
