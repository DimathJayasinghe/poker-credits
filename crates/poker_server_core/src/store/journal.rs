//! Append-only journal: one JSON object per line, `fsync`ed before the change is broadcast.

use std::fs::{self, File, OpenOptions};
use std::io::Write as _;
use std::path::Path;

use serde::{Deserialize, Serialize};

use super::StoreError;
use crate::room::state::Op;

const FILE: &str = "journal.jsonl";

/// One line of the journal.
#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "entry", rename_all = "SCREAMING_SNAKE_CASE")]
enum Line {
    /// An accepted op.
    Op {
        /// Position in the journal.
        seq: u64,
        /// The op.
        op: Op,
    },
    /// The op with this `seq` made the room panic: skip it on replay.
    Poisoned {
        /// Entry to skip.
        seq: u64,
    },
}

/// A journaled op.
#[derive(Debug)]
pub struct Entry {
    /// Position in the journal.
    pub seq: u64,
    /// The op.
    pub op: Op,
}

/// What [`read`] found.
#[derive(Debug, Default)]
pub struct Entries {
    /// Ops to replay, in order, poisoned ones removed.
    pub ops: Vec<Entry>,
    /// How many were removed as poisoned.
    pub skipped_poisoned: u32,
    /// Highest sequence number on any line, poisoned ones included. New entries must continue
    /// after this, or a poisoned number would be handed out again and its new op skipped on the
    /// next replay.
    pub max_seq: u64,
}

/// An open journal for appending.
#[derive(Debug)]
pub struct Journal {
    file: File,
    next_seq: u64,
}

impl Journal {
    /// Opens (creating if needed) the journal; new entries continue after `last_seq`.
    ///
    /// # Errors
    /// [`StoreError::Io`].
    pub fn open(dir: &Path, last_seq: u64) -> Result<Self, StoreError> {
        fs::create_dir_all(dir)?;
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(dir.join(FILE))?;
        Ok(Journal {
            file,
            next_seq: last_seq.saturating_add(1),
        })
    }

    /// Sequence number of the last entry written (or the starting one).
    #[must_use]
    pub fn last_seq(&self) -> u64 {
        self.next_seq.saturating_sub(1)
    }

    /// Appends an op and waits until it is on disk. Returns its sequence number.
    ///
    /// # Errors
    /// [`StoreError::Io`]; the caller must then not apply the op.
    pub fn append(&mut self, op: &Op) -> Result<u64, StoreError> {
        let seq = self.next_seq;
        self.write_line(&Line::Op {
            seq,
            op: op.clone(),
        })?;
        self.next_seq = seq.saturating_add(1);
        Ok(seq)
    }

    /// Marks an entry as poisoned so the next replay skips it.
    ///
    /// # Errors
    /// [`StoreError::Io`].
    pub fn mark_poisoned(&mut self, seq: u64) -> Result<(), StoreError> {
        self.write_line(&Line::Poisoned { seq })
    }

    /// Empties the journal after a snapshot has captured everything in it. Numbering continues.
    ///
    /// # Errors
    /// [`StoreError::Io`].
    pub fn truncate(&mut self) -> Result<(), StoreError> {
        self.file.set_len(0)?;
        self.file.sync_all()?;
        Ok(())
    }

    fn write_line(&mut self, line: &Line) -> Result<(), StoreError> {
        let mut text = serde_json::to_string(line).map_err(|e| StoreError::Corrupt {
            path: "journal".into(),
            reason: e.to_string(),
        })?;
        text.push('\n');
        self.file.write_all(text.as_bytes())?;
        self.file.sync_data()?;
        Ok(())
    }
}

/// Reads the journal. A last line that is cut off or unparsable is ignored (power loss while
/// writing it); an unparsable line anywhere else is corruption.
///
/// # Errors
/// [`StoreError::Corrupt`] for a bad line before the last one; [`StoreError::Io`] for disk errors.
pub fn read(dir: &Path) -> Result<Entries, StoreError> {
    let path = dir.join(FILE);
    let text = match fs::read(&path) {
        Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Entries::default()),
        Err(error) => return Err(error.into()),
    };
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    let mut ops = Vec::new();
    let mut poisoned = Vec::new();
    for (index, raw) in lines.iter().enumerate() {
        match serde_json::from_str::<Line>(raw) {
            Ok(Line::Op { seq, op }) => ops.push(Entry { seq, op }),
            Ok(Line::Poisoned { seq }) => poisoned.push(seq),
            Err(error) if index + 1 == lines.len() => {
                tracing::warn!(%error, "ignoring cut-off last journal line");
            }
            Err(error) => {
                return Err(StoreError::Corrupt {
                    path,
                    reason: format!("line {}: {error}", index + 1),
                });
            }
        }
    }
    let max_seq = ops
        .iter()
        .map(|e| e.seq)
        .chain(poisoned.iter().copied())
        .max()
        .unwrap_or(0);
    let before = ops.len();
    ops.retain(|e| !poisoned.contains(&e.seq));
    let skipped_poisoned = u32::try_from(before - ops.len()).unwrap_or(u32::MAX);
    Ok(Entries {
        ops,
        skipped_poisoned,
        max_seq,
    })
}
