//! Atomic JSON snapshot: write a temp file, `fsync`, rename over the old one, `fsync` the folder.

use std::fs::{self, File};
use std::io::Write as _;
use std::path::Path;

use serde::{Deserialize, Serialize};

use super::StoreError;
use crate::room::state::RoomState;

const FILE: &str = "snapshot.json";
const TEMP: &str = "snapshot.json.tmp";

/// What is written to `snapshot.json`.
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotFile {
    /// File format version.
    pub v: u16,
    /// Last journal entry already contained in `state`.
    pub journal_seq: u64,
    /// The room.
    pub state: RoomState,
}

/// Writes the snapshot atomically; a crash leaves either the old or the new file, never half.
///
/// # Errors
/// [`StoreError::Io`].
pub fn write(dir: &Path, state: &RoomState, journal_seq: u64) -> Result<(), StoreError> {
    fs::create_dir_all(dir)?;
    let body = serde_json::to_vec(&SnapshotFile {
        v: 1,
        journal_seq,
        state: state.clone(),
    })
    .map_err(|e| StoreError::Corrupt {
        path: dir.join(FILE),
        reason: e.to_string(),
    })?;
    let temp = dir.join(TEMP);
    let mut file = File::create(&temp)?;
    file.write_all(&body)?;
    file.sync_all()?;
    drop(file);
    fs::rename(&temp, dir.join(FILE))?;
    sync_dir(dir);
    Ok(())
}

/// Reads the snapshot.
///
/// # Errors
/// [`StoreError::Io`] if it is missing, [`StoreError::Corrupt`] if it does not parse.
pub fn read(dir: &Path) -> Result<SnapshotFile, StoreError> {
    let path = dir.join(FILE);
    let bytes = fs::read(&path)?;
    serde_json::from_slice(&bytes).map_err(|e| StoreError::Corrupt {
        path,
        reason: e.to_string(),
    })
}

/// Best effort: make the rename itself durable. Not possible on every platform.
fn sync_dir(dir: &Path) {
    if let Ok(handle) = File::open(dir) {
        let _ = handle.sync_all();
    }
}
