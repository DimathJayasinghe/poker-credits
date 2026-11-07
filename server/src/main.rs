//! Standalone cloud server.
//!
//! Environment: `POKER_BIND` (default `0.0.0.0:7878`), `POKER_DATA_DIR` (default `./data`),
//! `POKER_SERVER_NAME` (default `Poker Credits`),
//! `POKER_ALLOWED_ORIGINS` (comma-separated browser origins besides the server's own, default none), `RUST_LOG` (default `info`).

use std::net::SocketAddr;
use std::path::PathBuf;

use anyhow::Context as _;
use poker_server_core::config::{Limits, Timings};
use poker_server_core::util::panic_hook;
use poker_server_core::{ServerConfig, ServerMode};
use tracing_subscriber::EnvFilter;

const DEFAULT_BIND: &str = "0.0.0.0:7878";
const DEFAULT_DATA_DIR: &str = "./data";
const DEFAULT_NAME: &str = "Poker Credits";

/// Settings read from the environment.
#[derive(Debug, PartialEq, Eq)]
struct Settings {
    bind: SocketAddr,
    data_dir: PathBuf,
    server_name: String,
    allowed_origins: Vec<String>,
}

impl Settings {
    /// Reads settings through `get` (the process environment in `main`, a map in tests).
    fn from_lookup(get: impl Fn(&str) -> Option<String>) -> anyhow::Result<Self> {
        let bind = get("POKER_BIND").unwrap_or_else(|| DEFAULT_BIND.to_owned());
        let bind = bind
            .parse::<SocketAddr>()
            .with_context(|| format!("POKER_BIND must look like 0.0.0.0:7878, got {bind:?}"))?;
        Ok(Settings {
            bind,
            data_dir: get("POKER_DATA_DIR")
                .map_or_else(|| PathBuf::from(DEFAULT_DATA_DIR), PathBuf::from),
            server_name: get("POKER_SERVER_NAME")
                .filter(|name| !name.trim().is_empty())
                .unwrap_or_else(|| DEFAULT_NAME.to_owned()),
            allowed_origins: get("POKER_ALLOWED_ORIGINS")
                .map(|list| {
                    list.split(',')
                        .map(|origin| origin.trim().to_owned())
                        .filter(|origin| !origin.is_empty())
                        .collect()
                })
                .unwrap_or_default(),
        })
    }
}

/// Resolves on Ctrl-C or, on Unix, `SIGTERM` (what container platforms send).
async fn shutdown_signal() {
    let ctrl_c = async {
        if let Err(error) = tokio::signal::ctrl_c().await {
            tracing::error!(%error, "cannot listen for Ctrl-C");
            std::future::pending::<()>().await;
        }
    };
    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut stream) => {
                stream.recv().await;
            }
            Err(error) => {
                tracing::error!(%error, "cannot listen for SIGTERM");
                std::future::pending::<()>().await;
            }
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();
    tokio::select! {
        () = ctrl_c => {}
        () = terminate => {}
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();
    panic_hook::install();
    let settings = Settings::from_lookup(|key| std::env::var(key).ok())?;
    let server = poker_server_core::start(ServerConfig {
        bind: settings.bind,
        data_dir: Some(settings.data_dir),
        limits: Limits {
            allowed_origins: settings.allowed_origins,
            ..Limits::default()
        },
        timings: Timings::default(),
        mode: ServerMode::Cloud,
        server_name: settings.server_name,
        events: None,
        tls: None,
    })
    .await
    .context("could not start the server")?;
    tracing::info!(
        version = env!("CARGO_PKG_VERSION"),
        protocol = poker_server_core::PROTOCOL_VERSION,
        addr = %server.local_addr(),
        "poker_server running"
    );
    shutdown_signal().await;
    tracing::info!("shutting down");
    server.stop().await;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::*;

    fn settings(pairs: &[(&str, &str)]) -> anyhow::Result<Settings> {
        let map: HashMap<String, String> = pairs
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect();
        Settings::from_lookup(|key| map.get(key).cloned())
    }

    #[test]
    fn allowed_origins_are_a_trimmed_comma_list() {
        assert!(settings(&[]).unwrap().allowed_origins.is_empty());
        let s = settings(&[(
            "POKER_ALLOWED_ORIGINS",
            " https://a.example , ,https://b.example ",
        )])
        .unwrap();
        assert_eq!(
            s.allowed_origins,
            ["https://a.example", "https://b.example"]
        );
    }

    #[test]
    fn defaults_apply_when_nothing_is_set() {
        let s = settings(&[]).unwrap();
        assert_eq!(s.bind, "0.0.0.0:7878".parse().unwrap());
        assert_eq!(s.data_dir, PathBuf::from("./data"));
        assert_eq!(s.server_name, "Poker Credits");
    }

    #[test]
    fn environment_overrides_defaults() {
        let s = settings(&[
            ("POKER_BIND", "127.0.0.1:9000"),
            ("POKER_DATA_DIR", "/var/lib/poker"),
            ("POKER_SERVER_NAME", "Club"),
        ])
        .unwrap();
        assert_eq!(s.bind.port(), 9000);
        assert_eq!(s.data_dir, PathBuf::from("/var/lib/poker"));
        assert_eq!(s.server_name, "Club");
    }

    #[test]
    fn a_bad_bind_address_is_a_clear_error() {
        let error = settings(&[("POKER_BIND", "nonsense")]).unwrap_err();
        assert!(error.to_string().contains("POKER_BIND"), "{error}");
    }

    #[test]
    fn a_blank_server_name_falls_back_to_the_default() {
        assert_eq!(
            settings(&[("POKER_SERVER_NAME", "  ")])
                .unwrap()
                .server_name,
            "Poker Credits"
        );
    }
}
