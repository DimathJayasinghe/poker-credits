//! Keeps room actors alive: if one panics it is rebuilt from snapshot plus journal and the
//! connections are re-attached. A room that keeps panicking is frozen instead of looping.

use std::collections::VecDeque;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use tokio::sync::watch;
use tokio::task::JoinHandle;
use tokio::time::Instant;

use crate::config::{Limits, Timings};
use crate::registry::Registry;
use crate::room::actor::{self, Clock, ExitReason};
use crate::room::handle::{RoomHandle, RoomStatus};
use crate::store::StoreError;
use crate::store::journal::Journal;

/// Counts a panic and rebuilds the room, retrying (and poisoning the journal entry) when the
/// replay itself panics. `None` means: give up and freeze.
pub(crate) fn recover(
    dir: &Path,
    limits: &Limits,
    timings: &Timings,
    clock: Clock,
    strikes: &mut VecDeque<Instant>,
) -> Option<(RoomHandle, JoinHandle<ExitReason>)> {
    loop {
        let now = Instant::now();
        strikes.push_back(now);
        while strikes
            .front()
            .is_some_and(|t| now.duration_since(*t) > limits.crash_window)
        {
            strikes.pop_front();
        }
        if strikes.len() >= limits.crash_limit {
            tracing::error!(dir = %dir.display(), "room keeps crashing; freezing it");
            return None;
        }
        match actor::restore(dir.to_path_buf(), limits, timings, clock) {
            Ok(room) => return Some(room),
            Err(StoreError::ReplayPanic { seq }) => {
                tracing::error!(seq, "journal entry panicked on replay; marking it poisoned");
                let marked =
                    Journal::open(dir, 0).and_then(|mut journal| journal.mark_poisoned(seq));
                if let Err(error) = marked {
                    tracing::error!(%error, "cannot mark the entry poisoned; freezing the room");
                    return None;
                }
            }
            Err(error) => {
                tracing::error!(%error, "cannot restore the room; freezing it");
                return None;
            }
        }
    }
}

/// Watches one room until it is over.
pub(crate) async fn supervise(
    registry: Registry,
    code: String,
    dir: Option<PathBuf>,
    mut task: JoinHandle<ExitReason>,
    status: Arc<watch::Sender<RoomStatus>>,
) {
    let limits = registry.limits().clone();
    let timings = registry.timings().clone();
    let clock = registry.clock();
    let mut strikes = VecDeque::new();
    loop {
        match (&mut task).await {
            Ok(reason) => {
                tracing::info!(%code, ?reason, "room stopped");
                if matches!(reason, ExitReason::Ended | ExitReason::Expired)
                    && let Some(dir) = &dir
                    && let Err(error) = tokio::fs::remove_dir_all(dir).await
                {
                    tracing::warn!(%error, "could not delete the room's files");
                }
                status.send_replace(RoomStatus::Gone);
                registry.forget(&code);
                return;
            }
            Err(error) if error.is_panic() => {
                tracing::error!(%code, "room task panicked");
                let rebuilt = dir
                    .as_deref()
                    .and_then(|dir| recover(dir, &limits, &timings, clock, &mut strikes));
                if let Some((handle, next)) = rebuilt {
                    status.send_replace(RoomStatus::Running(handle));
                    task = next;
                } else {
                    // Files stay on disk for support; the registry keeps the code so that
                    // resumes get ROOM_CRASHED instead of ROOM_NOT_FOUND.
                    status.send_replace(RoomStatus::Frozen);
                    return;
                }
            }
            Err(_) => {
                status.send_replace(RoomStatus::Gone);
                registry.forget(&code);
                return;
            }
        }
    }
}
