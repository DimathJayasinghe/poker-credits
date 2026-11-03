//! Limits on who may connect and how fast: per-IP connection counting and token buckets.
//!
//! These are not game state, so plain locks are fine here; no guard is held across an `.await`.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex, PoisonError};

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

/// Token bucket: `per_second` tokens refill continuously up to `burst`.
#[derive(Clone, Copy, Debug)]
pub struct TokenBucket {
    per_second: u64,
    capacity_milli: u64,
    tokens_milli: u64,
    last: Instant,
}

impl TokenBucket {
    /// A full bucket.
    #[must_use]
    pub fn new(per_second: u32, burst: u32, now: Instant) -> Self {
        let capacity_milli = u64::from(burst.max(1)) * 1000;
        TokenBucket {
            per_second: u64::from(per_second),
            capacity_milli,
            tokens_milli: capacity_milli,
            last: now,
        }
    }

    /// Takes one token if there is one.
    pub fn allow(&mut self, now: Instant) -> bool {
        let elapsed_ms =
            u64::try_from(now.saturating_duration_since(self.last).as_millis()).unwrap_or(u64::MAX);
        self.last = now;
        // One token per `1000 / per_second` ms, in milli-tokens: per_second milli-tokens per ms.
        let refill = elapsed_ms.saturating_mul(self.per_second);
        self.tokens_milli = self
            .tokens_milli
            .saturating_add(refill)
            .min(self.capacity_milli);
        if self.tokens_milli >= 1000 {
            self.tokens_milli -= 1000;
            true
        } else {
            false
        }
    }

    fn is_full(&self, now: Instant) -> bool {
        let mut probe = *self;
        probe.allow(now);
        probe.tokens_milli.saturating_add(1000) >= probe.capacity_milli
    }
}

/// A [`TokenBucket`] per key (an IP address, for the HTTP endpoints).
#[derive(Debug)]
pub struct KeyedRateLimiter {
    per_second: u32,
    burst: u32,
    buckets: Mutex<HashMap<IpAddr, TokenBucket>>,
}

/// Above this many tracked addresses, idle ones are forgotten.
const PRUNE_ABOVE: usize = 4096;

impl KeyedRateLimiter {
    /// Same rate for every key.
    #[must_use]
    pub fn new(per_second: u32, burst: u32) -> Self {
        KeyedRateLimiter {
            per_second,
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
            .or_insert_with(|| TokenBucket::new(self.per_second, self.burst, now))
            .allow(now)
    }
}

#[cfg(test)]
mod tests {
    use std::net::Ipv4Addr;
    use std::time::Duration;

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
        let mut bucket = TokenBucket::new(10, 3, Instant::now());
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
}
