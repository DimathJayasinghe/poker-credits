//! Limits on who may connect and how fast: per-IP connection counting and token buckets.
//!
//! These are not game state, so plain locks are fine here; no guard is held across an `.await`.

use std::collections::HashMap;
use std::net::{IpAddr, Ipv6Addr};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use tokio::time::Instant;

type Counts = Arc<Mutex<HashMap<IpAddr, usize>>>;

/// Whether a WebSocket upgrade with this `Origin` header may proceed.
///
/// Browsers always send `Origin`, and any web page can open a socket to a LAN address, so an
/// origin is accepted only when it is the server's own (its host and port equal the `Host`
/// header, which is how a web player served by the same server connects) or is listed in
/// `allowed`. A request without `Origin` comes from a native client, not a page, and passes.
/// The opaque origin `null` (sandboxed frames, `file:`) never passes.
#[must_use]
pub fn origin_allowed(origin: Option<&str>, host: Option<&str>, allowed: &[String]) -> bool {
    let Some(origin) = origin else {
        return true;
    };
    let origin = origin.trim().trim_end_matches('/');
    if origin.eq_ignore_ascii_case("null") {
        return false;
    }
    if allowed
        .iter()
        .any(|a| a.trim().trim_end_matches('/').eq_ignore_ascii_case(origin))
    {
        return true;
    }
    let authority = origin
        .strip_prefix("http://")
        .or_else(|| origin.strip_prefix("https://"));
    matches!((authority, host), (Some(authority), Some(host)) if !authority.is_empty() && authority.eq_ignore_ascii_case(host.trim()))
}

/// The identity limits are counted against.
///
/// One IPv6 customer normally owns a whole `/64` (billions of addresses), so counting single
/// addresses would give a scanner a fresh budget per request. Global unicast addresses
/// (`2000::/3`) are therefore reduced to their `/64` prefix, and IPv4-mapped IPv6 addresses
/// (`::ffff:a.b.c.d`) are treated as the IPv4 address they carry.
///
/// Addresses that only exist on a local network (loopback, link-local `fe80::/10`, unique-local
/// `fc00::/7`) stay exact: every phone on one Wi-Fi or hotspot shares such a prefix, and in LAN
/// host mode they must not use up each other's budgets.
#[must_use]
pub fn limiter_key(ip: IpAddr) -> IpAddr {
    match ip {
        IpAddr::V4(_) => ip,
        IpAddr::V6(v6) => {
            if let Some(v4) = v6.to_ipv4_mapped() {
                return IpAddr::V4(v4);
            }
            let [a, b, c, d, ..] = v6.segments();
            let global_unicast = a & 0xe000 == 0x2000;
            if global_unicast {
                IpAddr::V6(Ipv6Addr::new(a, b, c, d, 0, 0, 0, 0))
            } else {
                ip
            }
        }
    }
}

/// Caps simultaneous connections per IP address.
#[derive(Clone, Debug)]
pub struct IpLimiter {
    max: usize,
    counts: Counts,
}

impl IpLimiter {
    /// At most `max` connections per address.
    #[must_use]
    pub fn new(max: usize) -> Self {
        IpLimiter {
            max,
            counts: Counts::default(),
        }
    }

    /// Takes one slot, or `None` when the address is at its limit. The slot is returned when
    /// the guard is dropped, however the connection task ends.
    #[must_use]
    pub fn try_acquire(&self, ip: IpAddr) -> Option<ConnectionGuard> {
        let ip = limiter_key(ip);
        let mut counts = self.counts.lock().unwrap_or_else(PoisonError::into_inner);
        let count = counts.entry(ip).or_insert(0);
        if *count >= self.max {
            return None;
        }
        *count += 1;
        Some(ConnectionGuard {
            ip,
            counts: Arc::clone(&self.counts),
        })
    }

    /// Connections currently held by `ip`.
    #[must_use]
    pub fn open(&self, ip: IpAddr) -> usize {
        let ip = limiter_key(ip);
        let counts = self.counts.lock().unwrap_or_else(PoisonError::into_inner);
        counts.get(&ip).copied().unwrap_or(0)
    }
}

/// One connection slot of an [`IpLimiter`].
#[derive(Debug)]
pub struct ConnectionGuard {
    ip: IpAddr,
    counts: Counts,
}

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        let mut counts = self.counts.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(count) = counts.get_mut(&self.ip) {
            *count = count.saturating_sub(1);
            if *count == 0 {
                counts.remove(&self.ip);
            }
        }
    }
}

/// Token bucket: `per_minute` tokens refill continuously up to `burst`.
///
/// Works in micro-tokens (a token is 1 000 000) and microseconds so that frequent polling never
/// rounds the refill away.
#[derive(Clone, Copy, Debug)]
pub struct TokenBucket {
    per_minute: u64,
    capacity_micro: u64,
    tokens_micro: u64,
    last: Instant,
}

const TOKEN: u64 = 1_000_000;

impl TokenBucket {
    /// A full bucket.
    #[must_use]
    pub fn new(per_minute: u32, burst: u32, now: Instant) -> Self {
        let capacity_micro = u64::from(burst.max(1)) * TOKEN;
        TokenBucket {
            per_minute: u64::from(per_minute),
            capacity_micro,
            tokens_micro: capacity_micro,
            last: now,
        }
    }

    /// Takes one token if there is one.
    pub fn allow(&mut self, now: Instant) -> bool {
        let elapsed_us =
            u64::try_from(now.saturating_duration_since(self.last).as_micros()).unwrap_or(u64::MAX);
        self.last = now;
        // per_minute tokens per 60 s: elapsed_us * per_minute / 60 micro-tokens.
        let refill = elapsed_us.saturating_mul(self.per_minute) / 60;
        self.tokens_micro = self
            .tokens_micro
            .saturating_add(refill)
            .min(self.capacity_micro);
        if self.tokens_micro >= TOKEN {
            self.tokens_micro -= TOKEN;
            true
        } else {
            false
        }
    }

    fn is_full(&self, now: Instant) -> bool {
        let mut probe = *self;
        probe.allow(now);
        probe.tokens_micro.saturating_add(TOKEN) >= probe.capacity_micro
    }
}

/// A [`TokenBucket`] per key (an IP address, for the HTTP endpoints).
#[derive(Debug)]
pub struct KeyedRateLimiter {
    per_minute: u32,
    burst: u32,
    buckets: Mutex<HashMap<IpAddr, TokenBucket>>,
}

/// Above this many tracked addresses, idle ones are forgotten.
const PRUNE_ABOVE: usize = 4096;

impl KeyedRateLimiter {
    /// Same rate for every key.
    #[must_use]
    pub fn new(per_minute: u32, burst: u32) -> Self {
        KeyedRateLimiter {
            per_minute,
            burst,
            buckets: Mutex::new(HashMap::new()),
        }
    }

    /// May this address make a request now?
    pub fn check(&self, ip: IpAddr) -> bool {
        let ip = limiter_key(ip);
        let now = Instant::now();
        let mut buckets = self.buckets.lock().unwrap_or_else(PoisonError::into_inner);
        if buckets.len() > PRUNE_ABOVE {
            buckets.retain(|_, bucket| !bucket.is_full(now));
        }
        buckets
            .entry(ip)
            .or_insert_with(|| TokenBucket::new(self.per_minute, self.burst, now))
            .allow(now)
    }
}

/// Blocks an address that fails too often (wrong room codes, bad tokens): after `max`
/// failures within `window` it is refused for `block`. Successes are not counted, so a busy
/// table behind one NAT address is not punished for playing.
#[derive(Debug)]
pub struct FailureLimiter {
    max: u32,
    window: Duration,
    block: Duration,
    entries: Mutex<HashMap<IpAddr, FailureEntry>>,
}

#[derive(Clone, Copy, Debug)]
struct FailureEntry {
    window_start: Instant,
    failures: u32,
    blocked_until: Option<Instant>,
}

impl FailureLimiter {
    /// `max` failures in `window` earn a `block`.
    #[must_use]
    pub fn new(max: u32, window: Duration, block: Duration) -> Self {
        FailureLimiter {
            max,
            window,
            block,
            entries: Mutex::new(HashMap::new()),
        }
    }

    /// May this address try now?
    pub fn allowed(&self, ip: IpAddr) -> bool {
        let ip = limiter_key(ip);
        let now = Instant::now();
        let entries = self.entries.lock().unwrap_or_else(PoisonError::into_inner);
        entries
            .get(&ip)
            .and_then(|entry| entry.blocked_until)
            .is_none_or(|until| now >= until)
    }

    /// Counts one failed attempt.
    pub fn record_failure(&self, ip: IpAddr) {
        let ip = limiter_key(ip);
        let now = Instant::now();
        let mut entries = self.entries.lock().unwrap_or_else(PoisonError::into_inner);
        if entries.len() > PRUNE_ABOVE {
            let window = self.window;
            entries.retain(|_, e| {
                e.blocked_until.is_some_and(|until| now < until)
                    || now.saturating_duration_since(e.window_start) < window
            });
        }
        let entry = entries.entry(ip).or_insert(FailureEntry {
            window_start: now,
            failures: 0,
            blocked_until: None,
        });
        if now.saturating_duration_since(entry.window_start) >= self.window {
            entry.window_start = now;
            entry.failures = 0;
        }
        entry.failures += 1;
        if entry.failures >= self.max {
            entry.blocked_until = Some(now + self.block);
            entry.failures = 0;
            entry.window_start = now;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::net::Ipv4Addr;

    use super::*;

    const IP: IpAddr = IpAddr::V4(Ipv4Addr::LOCALHOST);

    #[test]
    fn ip_slots_are_returned_on_drop() {
        let limiter = IpLimiter::new(2);
        let a = limiter.try_acquire(IP);
        let b = limiter.try_acquire(IP);
        assert!(a.is_some() && b.is_some());
        assert!(limiter.try_acquire(IP).is_none());
        drop(a);
        assert_eq!(limiter.open(IP), 1);
        let c = limiter.try_acquire(IP);
        assert!(c.is_some());
        drop(b);
        drop(c);
        assert_eq!(limiter.open(IP), 0, "all slots returned");
    }

    #[tokio::test(start_paused = true)]
    async fn bucket_allows_a_burst_then_refills() {
        let mut bucket = TokenBucket::new(600, 3, Instant::now());
        assert!(bucket.allow(Instant::now()));
        assert!(bucket.allow(Instant::now()));
        assert!(bucket.allow(Instant::now()));
        assert!(!bucket.allow(Instant::now()), "burst of 3 is used up");
        tokio::time::sleep(Duration::from_millis(100)).await;
        assert!(
            bucket.allow(Instant::now()),
            "10 per second refills one token in 100 ms"
        );
        assert!(!bucket.allow(Instant::now()));
        tokio::time::sleep(Duration::from_mins(1)).await;
        for _ in 0..3 {
            assert!(bucket.allow(Instant::now()));
        }
        assert!(!bucket.allow(Instant::now()), "never more than the burst");
    }

    #[tokio::test(start_paused = true)]
    async fn polling_often_does_not_round_the_refill_away() {
        let mut bucket = TokenBucket::new(6, 1, Instant::now());
        assert!(bucket.allow(Instant::now()));
        // 6 per minute is one token per 10 s; ask every millisecond.
        let mut granted_after_ms = None;
        for ms in 1..=11_000_u32 {
            tokio::time::sleep(Duration::from_millis(1)).await;
            if bucket.allow(Instant::now()) {
                granted_after_ms = Some(ms);
                break;
            }
        }
        let ms = granted_after_ms.expect("a token arrives");
        assert!((9_990..=10_010).contains(&ms), "after {ms} ms");
    }

    #[tokio::test(start_paused = true)]
    async fn too_many_failures_block_an_address_for_a_while() {
        let limiter = FailureLimiter::new(3, Duration::from_mins(1), Duration::from_mins(15));
        let other: IpAddr = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 2));
        limiter.record_failure(IP);
        limiter.record_failure(IP);
        assert!(limiter.allowed(IP), "two failures are fine");
        limiter.record_failure(IP);
        assert!(!limiter.allowed(IP), "the third blocks");
        assert!(limiter.allowed(other), "other addresses are unaffected");
        tokio::time::sleep(Duration::from_mins(14)).await;
        assert!(!limiter.allowed(IP));
        tokio::time::sleep(Duration::from_mins(2)).await;
        assert!(limiter.allowed(IP), "the block ends");
    }

    #[test]
    fn ipv6_addresses_share_a_budget_per_64_prefix() {
        let in_prefix =
            |last: u16| -> IpAddr { format!("2001:db8:1:2::{last:x}").parse().unwrap() };
        let other_prefix: IpAddr = "2001:db8:1:3::1".parse().unwrap();
        assert_eq!(limiter_key(in_prefix(1)), limiter_key(in_prefix(0xffff)));
        assert_ne!(limiter_key(in_prefix(1)), limiter_key(other_prefix));
        let high_bits: IpAddr = "2001:db8:1:2:aaaa:bbbb:cccc:dddd".parse().unwrap();
        assert_eq!(limiter_key(high_bits), limiter_key(in_prefix(1)));
    }

    #[test]
    fn local_network_ipv6_addresses_stay_exact() {
        for text in [
            "fe80::1",
            "fe80::2",
            "fd12:3456:789a:1::5",
            "fd12:3456:789a:1::6",
            "::1",
        ] {
            let ip: IpAddr = text.parse().unwrap();
            assert_eq!(limiter_key(ip), ip, "{text} must keep its own budget");
        }
    }

    #[test]
    fn ipv4_mapped_ipv6_is_the_ipv4_address() {
        let mapped: IpAddr = "::ffff:10.0.0.1".parse().unwrap();
        assert_eq!(limiter_key(mapped), IpAddr::V4(Ipv4Addr::new(10, 0, 0, 1)));
        let plain: IpAddr = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 1));
        assert_eq!(limiter_key(plain), plain);
    }

    #[tokio::test(start_paused = true)]
    async fn rotating_addresses_inside_one_prefix_does_not_reset_the_failure_budget() {
        let limiter = FailureLimiter::new(3, Duration::from_mins(1), Duration::from_mins(15));
        for n in 1..=3_u16 {
            limiter.record_failure(format!("2001:db8:9:9::{n:x}").parse().unwrap());
        }
        assert!(!limiter.allowed("2001:db8:9:9::dead:beef".parse().unwrap()));
        assert!(
            limiter.allowed("2001:db8:9:8::1".parse().unwrap()),
            "a different /64 is separate"
        );
    }

    #[test]
    fn connection_slots_are_counted_per_prefix() {
        let limiter = IpLimiter::new(2);
        let a = limiter.try_acquire("2001:db8::1".parse().unwrap());
        let b = limiter.try_acquire("2001:db8::2".parse().unwrap());
        assert!(a.is_some() && b.is_some());
        assert!(
            limiter
                .try_acquire("2001:db8::3".parse().unwrap())
                .is_none()
        );
    }

    #[tokio::test(start_paused = true)]
    async fn old_failures_are_forgotten() {
        let limiter = FailureLimiter::new(3, Duration::from_mins(1), Duration::from_mins(15));
        limiter.record_failure(IP);
        limiter.record_failure(IP);
        tokio::time::sleep(Duration::from_mins(2)).await;
        limiter.record_failure(IP);
        limiter.record_failure(IP);
        assert!(limiter.allowed(IP), "only two failures inside one window");
    }
}

#[cfg(test)]
mod origin_tests {
    use super::origin_allowed;

    fn check(origin: Option<&str>, host: Option<&str>, allowed: &[&str]) -> bool {
        let allowed: Vec<String> = allowed.iter().map(|a| (*a).to_owned()).collect();
        origin_allowed(origin, host, &allowed)
    }

    #[test]
    fn native_clients_send_no_origin() {
        assert!(check(None, Some("192.168.1.5:7878"), &[]));
    }

    #[test]
    fn same_origin_passes_for_http_and_https() {
        assert!(check(
            Some("http://192.168.1.5:7878"),
            Some("192.168.1.5:7878"),
            &[]
        ));
        assert!(check(
            Some("https://Play.Example.com"),
            Some("play.example.com"),
            &[]
        ));
    }

    #[test]
    fn foreign_pages_are_refused() {
        assert!(!check(
            Some("https://evil.example"),
            Some("192.168.1.5:7878"),
            &[]
        ));
        assert!(!check(
            Some("http://192.168.1.5:9999"),
            Some("192.168.1.5:7878"),
            &[]
        ));
        assert!(!check(
            Some("http://192.168.1.5"),
            Some("192.168.1.5:7878"),
            &[]
        ));
        assert!(!check(Some("null"), Some("null"), &[]));
        assert!(!check(Some("file://"), Some(""), &[]));
        assert!(!check(Some("http://"), Some(""), &[]));
        assert!(!check(Some("https://evil.example"), None, &[]));
    }

    #[test]
    fn listed_origins_pass() {
        assert!(check(
            Some("https://play.example.com/"),
            Some("10.0.0.2:7878"),
            &["https://play.example.com"]
        ));
        assert!(!check(
            Some("https://other.example.com"),
            Some("10.0.0.2:7878"),
            &["https://play.example.com"]
        ));
    }
}
