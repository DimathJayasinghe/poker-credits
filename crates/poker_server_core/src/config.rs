//! Limits and timings. Defaults follow `docs/RESILIENCE_AND_CRASH_HANDLING.md` 3.6 and 3.8.

use std::time::Duration;

/// Spectators per room (the default for [`Limits::max_spectators`]).
pub const MAX_SPECTATORS: usize = 20;

/// Connection and room limits.
#[derive(Clone, Debug)]
pub struct Limits {
    /// Seated players per room (the engine allows at most 10).
    pub max_players: usize,
    /// Spectators per room.
    pub max_spectators: usize,
    /// Messages queued per connection before it is dropped as a slow consumer.
    pub outbound_queue: usize,
    /// Messages queued in a room inbox.
    pub room_inbox: usize,
    /// Connections per IP address.
    pub max_connections_per_ip: usize,
    /// Rooms per server.
    pub max_rooms: usize,
    /// Client ping interval hint.
    pub ping_interval: Duration,
    /// Close a connection with no frame for this long.
    pub idle_timeout: Duration,
    /// Sustained messages per second per connection.
    pub rate_per_second: u32,
    /// Burst size per connection.
    pub rate_burst: u32,
    /// Strikes before a rate-limited connection is closed.
    pub rate_strikes: u32,
    /// Delete a room after this long without activity.
    pub room_ttl: Duration,
    /// A room that panics this many times within [`Limits::crash_window`] is frozen.
    pub crash_limit: usize,
    /// Window for counting room panics.
    pub crash_window: Duration,
}

impl Default for Limits {
    fn default() -> Self {
        Limits {
            max_players: 10,
            max_spectators: MAX_SPECTATORS,
            outbound_queue: 64,
            room_inbox: 256,
            max_connections_per_ip: 40,
            max_rooms: 100,
            ping_interval: Duration::from_secs(15),
            idle_timeout: Duration::from_secs(45),
            rate_per_second: 10,
            rate_burst: 20,
            rate_strikes: 3,
            room_ttl: Duration::from_hours(1),
            crash_limit: 3,
            crash_window: Duration::from_mins(1),
        }
    }
}

/// Inactive-player policy (`RESILIENCE_AND_CRASH_HANDLING.md` 3.8).
#[derive(Clone, Debug)]
pub struct Timings {
    /// Start a presence check after a player has sat out this long...
    pub away_after_ms: u64,
    /// ...or for this many hands, whichever comes first.
    pub away_after_hands: u32,
    /// How long a presence check stays open.
    pub presence_check_ms: u64,
    /// How long a busted player has to ask for a rebuy.
    pub rebuy_window_ms: u64,
}

impl Default for Timings {
    fn default() -> Self {
        Timings {
            away_after_ms: 5 * 60 * 1000,
            away_after_hands: 5,
            presence_check_ms: 90 * 1000,
            rebuy_window_ms: 2 * 60 * 1000,
        }
    }
}
