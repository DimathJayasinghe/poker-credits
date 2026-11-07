//! Owner-only files. A snapshot or journal of a virtual room holds the shuffled deck and every
//! player's hole cards, so on a shared machine nobody but the server's user may read them.

use std::fs::{self, File, OpenOptions};
use std::io;
use std::path::Path;

/// Creates `dir` (and parents) and restricts `dir` itself to the owner.
pub(crate) fn create_dir(dir: &Path) -> io::Result<()> {
    fs::create_dir_all(dir)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700))?;
    }
    Ok(())
}

/// Open options for a store file: created readable and writable by the owner only.
pub(crate) fn options() -> OpenOptions {
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
pub(crate) fn restrict(file: &File) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        file.set_permissions(fs::Permissions::from_mode(0o600))?;
    }
    #[cfg(not(unix))]
    let _ = file;
    Ok(())
}

/// Writes `bytes` to `path` so a reader never sees half a file: owner-only temp file, `fsync`,
/// rename over the old one.
pub(crate) fn write_atomic(path: &Path, bytes: &[u8]) -> io::Result<()> {
    use std::io::Write as _;
    if let Some(dir) = path.parent() {
        create_dir(dir)?;
    }
    let mut temp = path.as_os_str().to_owned();
    temp.push(".tmp");
    let temp = std::path::PathBuf::from(temp);
    let mut file = options()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&temp)?;
    restrict(&file)?;
    file.write_all(bytes)?;
    file.sync_all()?;
    drop(file);
    fs::rename(&temp, path)
}
