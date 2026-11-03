//! Authoritative poker server core, shared by the cloud binary and the app's embedded host mode.
//!
//! Implementation starts in Phase 2; see `docs/AGENT_CODING_GUIDE.md`.

pub mod config;
pub mod protocol;
pub mod room;
pub mod util;

/// Wire protocol version spoken by this build (`v` field of every message).
pub const PROTOCOL_VERSION: u16 = 1;

#[cfg(test)]
mod tests {
    use super::PROTOCOL_VERSION;

    #[test]
    fn protocol_version_starts_at_one() {
        assert_eq!(PROTOCOL_VERSION, 1);
    }
}
