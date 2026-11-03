//! Limits on who may connect and how fast: per-IP connection counting and token buckets.
//!
//! These are not game state, so plain locks are fine here; no guard is held across an `.await`.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use tokio::time::Instant;

type Counts = Arc<Mutex<HashMap<IpAddr, usize>>>;

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
        let now = Instant::now();
        let entries = self.entries.lock().unwrap_or_else(PoisonError::into_inner);
        entries
            .get(&ip)
            .and_then(|entry| entry.blocked_until)
            .is_none_or(|until| now >= until)
    }

    /// Counts one failed attempt.
    pub fn record_failure(&self, ip: IpAddr) {
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
