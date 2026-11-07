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
    /// Give up writing a frame to a socket after this long (a stuck TCP peer).
    pub write_timeout: Duration,
    /// Close a socket that has not sent `CREATE_ROOM`, `JOIN_ROOM` or `RESUME` by then.
    pub auth_timeout: Duration,
    /// Sustained HTTP requests per second per IP (room lookups are guessable, so limited).
    pub http_rate_per_second: u32,
    /// HTTP burst size per IP.
    pub http_burst: u32,
    /// Failed `JOIN_ROOM` / `RESUME` attempts per IP within [`Limits::join_failure_window`]
    /// before the address is blocked for [`Limits::join_block`].
    pub join_failures: u32,
    /// Window for counting failed joins.
    pub join_failure_window: Duration,
    /// How long an address stays blocked after too many failed joins.
    pub join_block: Duration,
    /// `CREATE_ROOM` per minute per IP.
    pub create_per_minute: u32,
    /// `CREATE_ROOM` burst per IP.
    pub create_burst: u32,
    /// Delete a room after this long without activity.
    pub room_ttl: Duration,
    /// A room that panics this many times within [`Limits::crash_window`] is frozen.
    pub crash_limit: usize,
    /// Window for counting room panics.
    pub crash_window: Duration,
    /// Browser origins (`https://play.example.com`) allowed to open a socket besides the server's
    /// own origin. Clients that send no `Origin` header (the native app) are always accepted.
    pub allowed_origins: Vec<String>,
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
            write_timeout: Duration::from_secs(10),
            auth_timeout: Duration::from_secs(10),
            http_rate_per_second: 2,
            http_burst: 10,
            join_failures: 20,
            join_failure_window: Duration::from_mins(1),
            join_block: Duration::from_mins(15),
            create_per_minute: 6,
            create_burst: 3,
            room_ttl: Duration::from_hours(1),
            crash_limit: 3,
            crash_window: Duration::from_mins(1),
            allowed_origins: Vec::new(),
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
    /// A player on turn who has no connection for this long is acted for (check or fold).
    pub disconnect_grace_ms: u64,
    /// A seat without any connection for this long is sat out.
    pub absent_sit_out_ms: u64,
    /// Solo games: multiplies every computer player's thinking time (1.0 normal, 0 in tests).
    pub bot_think_scale: f32,
    /// Solo games: pause between the end of a hand and the next deal.
    pub bot_next_hand_ms: u64,
}

impl Default for Timings {
    fn default() -> Self {
        Timings {
            away_after_ms: 5 * 60 * 1000,
            away_after_hands: 5,
            presence_check_ms: 90 * 1000,
            rebuy_window_ms: 2 * 60 * 1000,
            disconnect_grace_ms: 30 * 1000,
            absent_sit_out_ms: 10 * 60 * 1000,
            bot_think_scale: 1.0,
            bot_next_hand_ms: 3_000,
        }
    }
}
