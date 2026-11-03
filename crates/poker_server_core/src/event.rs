//! Events the embedding app can observe (the host app turns them into a Dart stream).

use std::net::SocketAddr;

/// Something that happened to the server as a whole.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ServerEvent {
    /// The listener is up.
    Listening(SocketAddr),
    /// Rooms found on disk were started again.
    RoomsRestored(usize),
    /// The server has stopped.
    Stopped,
}
