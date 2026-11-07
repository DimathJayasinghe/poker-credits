//! Owner-only files. A snapshot or journal of a virtual room holds the shuffled deck and every
//! player's hole cards, so on a shared machine nobody but the server's user may read them.

use std::fs::{self, File, OpenOptions};
use std::io;
use std::path::Path;

/// Creates `dir` (and parents) and restricts `dir` itself to the owner.
pub(super) fn create_dir(dir: &Path) -> io::Result<()> {
    fs::create_dir_all(dir)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700))?;
    }
    Ok(())
}

/// Open options for a store file: created readable and writable by the owner only.
pub(super) fn options() -> OpenOptions {
    // Only the unix branch below changes the options; elsewhere `mut` would be unused.
    #[cfg_attr(not(unix), allow(unused_mut))]
    let mut options = OpenOptions::new();
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt as _;
        options.mode(0o600);
    }
    options
}

/// Tightens a file that already existed (written by an older version) to owner-only.
pub(super) fn restrict(file: &File) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        file.set_permissions(fs::Permissions::from_mode(0o600))?;
    }
    #[cfg(not(unix))]
    let _ = file;
    Ok(())
}
