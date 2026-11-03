//! Persistence: an atomic snapshot plus a write-ahead journal per room
//! (`docs/RESILIENCE_AND_CRASH_HANDLING.md` 3.4).
//!
//! Layout: `<data_dir>/<ROOM_CODE>/snapshot.json` and `.../journal.jsonl`. State is the
//! snapshot with the journal replayed on top. A new snapshot makes the journal redundant.

pub mod journal;
pub mod snapshot;

use std::io;
use std::path::{Path, PathBuf};

use crate::config::Timings;
use crate::room::state::RoomState;

/// Why a store operation failed.
#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    /// Disk problem.
    #[error("store I/O: {0}")]
    Io(#[from] io::Error),
    /// A file exists but is not valid JSON of the expected shape.
    #[error("corrupt store file {path}: {reason}")]
    Corrupt {
        /// File.
        path: PathBuf,
        /// What was wrong.
        reason: String,
    },
}

/// Folder for one room.
#[must_use]
pub fn room_dir(data_dir: &Path, code: &str) -> PathBuf {
    data_dir.join(code)
}

/// A room rebuilt from disk.
#[derive(Debug)]
pub struct Restored {
    /// State after replaying the journal.
    pub state: RoomState,
    /// Sequence number of the last journal entry applied (or the snapshot's, if none).
    pub last_seq: u64,
    /// Journal entries that were skipped because they were marked poisoned.
    pub skipped_poisoned: u32,
    /// Journal entries that no longer applied (logged, state kept).
    pub failed_replays: u32,
}

/// Loads a room: snapshot, then every later journal entry through the reducer.
///
/// # Errors
/// [`StoreError`] when the snapshot is missing or corrupt, or the journal is corrupt before its
/// last line. A cut-off last line (power loss mid-write) is ignored.
pub fn restore(dir: &Path, timings: &Timings) -> Result<Restored, StoreError> {
    let snap = snapshot::read(dir)?;
    let mut state = snap.state;
    let mut last_seq = snap.journal_seq;
    let mut failed_replays = 0;
    let entries = journal::read(dir)?;
    for entry in entries.ops.into_iter().filter(|e| e.seq > snap.journal_seq) {
        match state.apply(entry.op, timings) {
            Ok(_) => {}
            Err(error) => {
                failed_replays += 1;
                tracing::warn!(seq = entry.seq, code = ?error.code, "journal entry no longer applies");
            }
        }
        last_seq = entry.seq;
    }
    Ok(Restored {
        state,
        last_seq,
        skipped_poisoned: entries.skipped_poisoned,
        failed_replays,
    })
}
