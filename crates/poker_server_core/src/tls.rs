//! Encrypted transport for the host's LAN server (ADR-019).
//!
//! A host phone cannot get a certificate from a public authority (a LAN address has no name), so
//! each install makes its own self-signed certificate once and keeps it. Guests do not ask an
//! authority whether to trust it: they compare the certificate's SHA-256 fingerprint with the one
//! they were given in the QR code (or saw the first time they joined, for code and lobby joins).
//! Only TLS 1.3 is offered, with the `ring` crypto backend.

use std::collections::HashMap;
use std::fmt;
use std::future::Future;
use std::io;
use std::net::{IpAddr, Ipv6Addr, SocketAddr};
use std::path::Path;
use std::pin::Pin;
use std::sync::{Arc, Mutex, PoisonError};
use std::task::{Context, Poll};
use std::time::Duration;

use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use sha2::{Digest, Sha256};
use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio::task::{AbortHandle, JoinHandle};
use tokio::time::{Instant, Sleep};
use tokio_rustls::TlsAcceptor;
use tokio_rustls::server::TlsStream;

use crate::config::Limits;
use crate::net::guards::{ConnectionGuard, IpLimiter};
use crate::store::private;

/// First line of the identity file; the number is the format version.
const FILE_MAGIC: &[u8] = b"PCTLS1\n";

/// How long a new socket gets to send its first byte (a TLS client speaks at once).
const FIRST_BYTE_TIMEOUT: Duration = Duration::from_secs(2);

/// How long a client gets to finish the TLS handshake before the connection is dropped.
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);

/// Handshakes in flight at once, over all addresses.
const MAX_HANDSHAKES: usize = 64;

/// Handshakes in flight at once from one address.
const MAX_HANDSHAKES_PER_IP: usize = 8;

/// Finished handshakes waiting for the HTTP server to pick them up.
const READY_QUEUE: usize = 32;

/// An identity file is about 400 bytes; anything much larger is not ours and is not read whole.
const MAX_IDENTITY_FILE: u64 = 16 * 1024;

fn read_identity_file(path: &Path) -> io::Result<Vec<u8>> {
    use std::io::Read as _;
    let mut bytes = Vec::new();
    std::fs::File::open(path)?
        .take(MAX_IDENTITY_FILE + 1)
        .read_to_end(&mut bytes)?;
    Ok(bytes)
}

/// Why the TLS identity or configuration could not be made.
#[derive(Debug, thiserror::Error)]
pub enum TlsError {
    /// Making the key pair or the certificate failed.
    #[error("cannot make the certificate: {0}")]
    Generate(String),
    /// The identity file could not be written.
    #[error("cannot store the identity: {0}")]
    Store(#[from] io::Error),
    /// rustls refused the key and certificate.
    #[error("cannot set up TLS: {0}")]
    Config(String),
}

/// SHA-256 of a certificate's DER bytes. This is what a guest pins.
///
/// Written as 43 characters of URL-safe base64 without padding, which keeps the QR code small.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Fingerprint([u8; 32]);

impl Fingerprint {
    /// Length of the written form.
    pub const TEXT_LEN: usize = 43;

    /// The fingerprint of a certificate.
    #[must_use]
    pub fn of_certificate(der: &[u8]) -> Fingerprint {
        let mut bytes = [0_u8; 32];
        bytes.copy_from_slice(Sha256::digest(der).as_slice());
        Fingerprint(bytes)
    }

    /// Reads the written form; `None` when it is not exactly 43 URL-safe base64 characters for
    /// 32 bytes.
    #[must_use]
    pub fn parse(text: &str) -> Option<Fingerprint> {
        let bytes = b64url_decode(text)?;
        let bytes: [u8; 32] = bytes.try_into().ok()?;
        Some(Fingerprint(bytes))
    }

    /// The raw digest.
    #[must_use]
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Display for Fingerprint {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&b64url_encode(&self.0))
    }
}

impl fmt::Debug for Fingerprint {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Fingerprint({self})")
    }
}

const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

fn b64url_encode(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let b0 = u32::from(chunk.first().copied().unwrap_or(0));
        let b1 = u32::from(chunk.get(1).copied().unwrap_or(0));
        let b2 = u32::from(chunk.get(2).copied().unwrap_or(0));
        let n = (b0 << 16) | (b1 << 8) | b2;
        // 6 bits at a time; a short last chunk writes one character fewer per missing byte.
        let shown = chunk.len() + 1;
        for (i, shift) in [18_u32, 12, 6, 0].into_iter().enumerate() {
            if i < shown {
                let index = usize::try_from((n >> shift) & 63).unwrap_or(0);
                out.push(char::from(B64.get(index).copied().unwrap_or(b'A')));
            }
        }
    }
    out
}

fn b64url_decode(text: &str) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(text.len() * 3 / 4);
    let mut acc = 0_u32;
    let mut bits = 0_u32;
    for c in text.bytes() {
        let value = B64.iter().position(|b| *b == c)?;
        acc = (acc << 6) | u32::try_from(value).ok()?;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push(u8::try_from((acc >> bits) & 0xff).ok()?);
        }
    }
    // Leftover bits must be zero, otherwise two texts would name one fingerprint.
    let leftover_zero = acc & ((1 << bits) - 1) == 0;
    (text.len() % 4 != 1 && leftover_zero).then_some(out)
}

/// A host's certificate and private key.
#[derive(Clone)]
pub struct Identity {
    certificate: Vec<u8>,
    key: Vec<u8>,
}

impl fmt::Debug for Identity {
    // The key never goes into a log, not even by accident.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Identity")
            .field("fingerprint", &self.fingerprint())
            .finish_non_exhaustive()
    }
}

impl Identity {
    /// Makes a new self-signed identity (ECDSA P-256), valid for a century so that it never
    /// expires under a pinned guest: trust comes from the pin, not from a date.
    ///
    /// # Errors
    /// [`TlsError::Generate`] if the crypto library fails.
    pub fn generate() -> Result<Identity, TlsError> {
        let fail = |e: rcgen::Error| TlsError::Generate(e.to_string());
        let key_pair = rcgen::KeyPair::generate().map_err(fail)?;
        let mut params =
            rcgen::CertificateParams::new(vec!["localhost".to_owned()]).map_err(fail)?;
        params
            .distinguished_name
            .push(rcgen::DnType::CommonName, "Poker Credits host");
        params.not_before = rcgen::date_time_ymd(2024, 1, 1);
        params.not_after = rcgen::date_time_ymd(2124, 1, 1);
        let certificate = params.self_signed(&key_pair).map_err(fail)?;
        Ok(Identity {
            certificate: certificate.der().to_vec(),
            key: key_pair.serialize_der(),
        })
    }

    /// Loads the identity stored at `path`, or makes one and stores it there (owner-only).
    ///
    /// The identity must survive restarts: a guest that pinned it will refuse a host that comes
    /// back with a different one. A file that cannot be read back is replaced (and logged), which
    /// guests will see as a new host.
    ///
    /// # Errors
    /// [`TlsError`] when a new identity cannot be made or stored.
    pub fn load_or_create(path: &Path) -> Result<Identity, TlsError> {
        match read_identity_file(path) {
            Ok(bytes) => match Identity::from_file_bytes(&bytes) {
                Some(identity) if identity.server_config().is_ok() => return Ok(identity),
                _ => tracing::warn!(
                    path = %path.display(),
                    "the stored TLS identity is unreadable; making a new one"
                ),
            },
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => {
                tracing::warn!(%error, "cannot read the TLS identity; making a new one");
            }
        }
        let identity = Identity::generate()?;
        private::write_atomic(path, &identity.to_file_bytes())?;
        Ok(identity)
    }

    /// The pin a guest needs.
    #[must_use]
    pub fn fingerprint(&self) -> Fingerprint {
        Fingerprint::of_certificate(&self.certificate)
    }

    /// The certificate as DER bytes.
    #[must_use]
    pub fn certificate_der(&self) -> &[u8] {
        &self.certificate
    }

    fn to_file_bytes(&self) -> Vec<u8> {
        let mut out = FILE_MAGIC.to_vec();
        for part in [&self.certificate, &self.key] {
            let len = u32::try_from(part.len()).unwrap_or(u32::MAX);
            out.extend_from_slice(&len.to_be_bytes());
            out.extend_from_slice(part);
        }
        out
    }

    fn from_file_bytes(bytes: &[u8]) -> Option<Identity> {
        let rest = bytes.strip_prefix(FILE_MAGIC)?;
        let (certificate, rest) = take_part(rest)?;
        let (key, rest) = take_part(rest)?;
        rest.is_empty().then(|| Identity {
            certificate: certificate.to_vec(),
            key: key.to_vec(),
        })
    }

    /// rustls settings: TLS 1.3 only, no client certificates, HTTP/1.1 only (a WebSocket upgrade
    /// needs it, and h2 would need extended CONNECT).
    pub(crate) fn server_config(&self) -> Result<Arc<rustls::ServerConfig>, TlsError> {
        let config_error = |e: rustls::Error| TlsError::Config(e.to_string());
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let mut config = rustls::ServerConfig::builder_with_provider(provider)
            .with_protocol_versions(&[&rustls::version::TLS13])
            .map_err(config_error)?
            .with_no_client_auth()
            .with_single_cert(
                vec![CertificateDer::from(self.certificate.clone())],
                PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(self.key.clone())),
            )
            .map_err(config_error)?;
        config.alpn_protocols = vec![b"http/1.1".to_vec()];
        Ok(Arc::new(config))
    }
}

/// Splits `[len: u32 BE][len bytes]` off the front.
fn take_part(bytes: &[u8]) -> Option<(&[u8], &[u8])> {
    let (len, rest) = bytes.split_at_checked(4)?;
    let len = usize::try_from(u32::from_be_bytes(len.try_into().ok()?)).ok()?;
    rest.split_at_checked(len)
}

/// Accepts TCP connections, finishes their TLS handshakes in the background and hands the
/// encrypted streams to the HTTP server.
///
/// A phone on a shared network must not be tied up by a neighbour, so every stage is bounded:
/// - A socket that sends nothing within [`FIRST_BYTE_TIMEOUT`] is dropped, and a handshake gets
///   [`HANDSHAKE_TIMEOUT`] in all. Handshakes run off the accept path, so a silent client never
///   delays anyone else.
/// - At most [`MAX_HANDSHAKES`] run at once and [`MAX_HANDSHAKES_PER_IP`] per address. When the
///   pool is full, a newcomer takes the place of the oldest handshake of whichever address holds
///   the most, so a device that opens many sockets cannot crowd real guests out.
/// - An established connection is closed after a stretch of silence (a little over the
///   WebSocket idle timeout) and counts against the per-address connection limit until then.
#[derive(Debug)]
pub struct TlsListener {
    ready: mpsc::Receiver<(Guarded<TlsStream<TcpStream>>, SocketAddr)>,
    local_addr: SocketAddr,
    task: JoinHandle<()>,
}

impl TlsListener {
    /// Starts accepting on `listener`, with the connection limits of `limits`.
    ///
    /// # Errors
    /// [`TlsError`] when the identity is not accepted by rustls, or the socket has no address.
    pub fn new(
        listener: TcpListener,
        identity: &Identity,
        limits: &Limits,
    ) -> Result<TlsListener, TlsError> {
        let acceptor = TlsAcceptor::from(identity.server_config()?);
        let local_addr = listener.local_addr()?;
        let (tx, ready) = mpsc::channel(READY_QUEUE);
        let task = tokio::spawn(accept_loop(
            listener,
            acceptor,
            tx,
            Guards {
                idle: transport_idle(limits.idle_timeout),
                open: IpLimiter::new(open_cap(limits.max_connections_per_ip)),
            },
        ));
        Ok(TlsListener {
            ready,
            local_addr,
            task,
        })
    }
}

impl Drop for TlsListener {
    /// Closing the listener must free the port, or the next start would silently use another.
    fn drop(&mut self) {
        self.task.abort();
    }
}

impl axum::serve::Listener for TlsListener {
    type Io = Guarded<TlsStream<TcpStream>>;
    type Addr = SocketAddr;

    async fn accept(&mut self) -> (Self::Io, Self::Addr) {
        match self.ready.recv().await {
            Some(connection) => connection,
            // The accept task only ends when this listener is dropped, so this is unreachable;
            // waiting forever is the harmless answer.
            None => std::future::pending().await,
        }
    }

    fn local_addr(&self) -> io::Result<Self::Addr> {
        Ok(self.local_addr)
    }
}

/// The transport closes a silent connection a little after the WebSocket layer would, so the
/// WebSocket layer's own close (with a reason) wins whenever there is one.
fn transport_idle(websocket_idle: Duration) -> Duration {
    websocket_idle.saturating_add(websocket_idle / 4)
}

/// Sockets one address may hold open at the transport. The WebSocket layer enforces the real
/// per-address limit and tells the guest why; this one is the backstop for sockets that never
/// get that far (idle or half-open), so it is looser.
fn open_cap(websocket_limit: usize) -> usize {
    websocket_limit.saturating_mul(2).saturating_add(4)
}

/// What every accepted connection is held to.
#[derive(Clone, Debug)]
struct Guards {
    idle: Duration,
    open: IpLimiter,
}

async fn accept_loop(
    listener: TcpListener,
    acceptor: TlsAcceptor,
    ready: mpsc::Sender<(Guarded<TlsStream<TcpStream>>, SocketAddr)>,
    guards: Guards,
) {
    let pool = HandshakePool::default();
    loop {
        let (tcp, peer) = match listener.accept().await {
            Ok(connection) => connection,
            Err(error) => {
                // Out of file descriptors and the like: back off instead of spinning.
                tracing::warn!(%error, "accept failed");
                tokio::time::sleep(Duration::from_millis(200)).await;
                continue;
            }
        };
        let Some(open) = guards.open.try_acquire(peer.ip()) else {
            tracing::debug!(%peer, "too many connections from one address; dropping");
            continue;
        };
        let Some(admission) = pool.admit(peer.ip()) else {
            tracing::debug!(%peer, "too many handshakes in flight; dropping the connection");
            continue;
        };
        let _nodelay = tcp.set_nodelay(true);
        let acceptor = acceptor.clone();
        let ready = ready.clone();
        let idle = guards.idle;
        let id = admission.id;
        let handle = tokio::spawn(async move {
            let outcome = tokio::time::timeout(HANDSHAKE_TIMEOUT, handshake(&acceptor, tcp)).await;
            // The pool slot is free again as soon as the handshake is over, however it ended.
            drop(admission);
            match outcome {
                Ok(Ok(stream)) => {
                    let guarded = Guarded::new(stream, idle, open);
                    let _closed = ready.send((guarded, peer)).await;
                }
                Ok(Err(error)) => tracing::debug!(%peer, %error, "TLS handshake failed"),
                Err(_) => tracing::debug!(%peer, "TLS handshake timed out"),
            }
        });
        pool.attach(id, handle.abort_handle());
    }
}

/// Waits for the first bytes, then runs the handshake.
async fn handshake(acceptor: &TlsAcceptor, tcp: TcpStream) -> io::Result<TlsStream<TcpStream>> {
    let mut first = [0_u8; 1];
    match tokio::time::timeout(FIRST_BYTE_TIMEOUT, tcp.peek(&mut first)).await {
        Ok(Ok(n)) if n > 0 => {}
        Ok(Ok(_)) => return Err(io::ErrorKind::UnexpectedEof.into()),
        Ok(Err(error)) => return Err(error),
        Err(_) => return Err(io::ErrorKind::TimedOut.into()),
    }
    acceptor.accept(tcp).await
}

/// Which handshakes are running, so a crowded pool can make room for a newcomer.
#[derive(Clone, Debug, Default)]
struct HandshakePool {
    state: Arc<Mutex<PoolState>>,
}

#[derive(Debug, Default)]
struct PoolState {
    next_id: u64,
    entries: HashMap<u64, Pending>,
}

#[derive(Debug)]
struct Pending {
    owner: IpAddr,
    started: Instant,
    abort: Option<AbortHandle>,
}

/// One handshake's place in the pool; the place is given back when this is dropped.
#[derive(Debug)]
struct Admission {
    id: u64,
    pool: HandshakePool,
}

impl Drop for Admission {
    fn drop(&mut self) {
        self.pool.lock().entries.remove(&self.id);
    }
}

/// Handshakes are short, so addresses are grouped coarsely: all of one IPv6 `/64` share a budget
/// (a device can make billions of addresses there, link-local ones included).
fn pool_key(ip: IpAddr) -> IpAddr {
    match ip {
        IpAddr::V4(_) => ip,
        IpAddr::V6(v6) => {
            if let Some(v4) = v6.to_ipv4_mapped() {
                IpAddr::V4(v4)
            } else {
                let [a, b, c, d, ..] = v6.segments();
                IpAddr::V6(Ipv6Addr::new(a, b, c, d, 0, 0, 0, 0))
            }
        }
    }
}

impl HandshakePool {
    fn lock(&self) -> std::sync::MutexGuard<'_, PoolState> {
        self.state.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Takes a place for a handshake from `peer`, or `None` when it must be turned away.
    fn admit(&self, peer: IpAddr) -> Option<Admission> {
        let owner = pool_key(peer);
        let mut state = self.lock();
        let mine = state.entries.values().filter(|e| e.owner == owner).count();
        if mine >= MAX_HANDSHAKES_PER_IP {
            return None;
        }
        if state.entries.len() >= MAX_HANDSHAKES {
            // Fair share: the address with the most handshakes loses its oldest one, but only if
            // it holds more than the newcomer would after being let in.
            let mut counts: HashMap<IpAddr, usize> = HashMap::new();
            for entry in state.entries.values() {
                *counts.entry(entry.owner).or_insert(0) += 1;
            }
            let (&heaviest, &held) = counts.iter().max_by_key(|(_, held)| **held)?;
            if held <= mine + 1 {
                return None;
            }
            let victim = state
                .entries
                .iter()
                .filter(|(_, e)| e.owner == heaviest)
                .min_by_key(|(_, e)| e.started)
                .map(|(id, _)| *id)?;
            if let Some(evicted) = state.entries.remove(&victim)
                && let Some(abort) = evicted.abort
            {
                abort.abort();
            }
        }
        let id = state.next_id;
        state.next_id = state.next_id.wrapping_add(1);
        state.entries.insert(
            id,
            Pending {
                owner,
                started: Instant::now(),
                abort: None,
            },
        );
        drop(state);
        Some(Admission {
            id,
            pool: self.clone(),
        })
    }

    /// Lets a later eviction stop the task that runs handshake `id`.
    fn attach(&self, id: u64, abort: AbortHandle) {
        if let Some(entry) = self.lock().entries.get_mut(&id) {
            entry.abort = Some(abort);
        }
    }
}

/// An encrypted connection that is closed after a stretch of silence and holds one slot of the
/// per-address connection limit until it is dropped.
///
/// The timer restarts whenever bytes move in either direction, so a quiet but healthy WebSocket
/// (the client pings every 15 s) is never cut, while a socket that connects and says nothing, or
/// sends half a request and stops, cannot sit on the phone's file descriptors.
#[derive(Debug)]
pub struct Guarded<S> {
    inner: S,
    idle: Duration,
    timer: Pin<Box<Sleep>>,
    _slot: ConnectionGuard,
}

impl<S> Guarded<S> {
    fn new(inner: S, idle: Duration, slot: ConnectionGuard) -> Self {
        Guarded {
            inner,
            idle,
            timer: Box::pin(tokio::time::sleep(idle)),
            _slot: slot,
        }
    }

    fn touch(&mut self) {
        self.timer.as_mut().reset(Instant::now() + self.idle);
    }

    /// What to answer when the inner stream is not ready: still waiting, or timed out.
    fn waiting<T>(&mut self, cx: &mut Context<'_>) -> Poll<io::Result<T>> {
        match self.timer.as_mut().poll(cx) {
            Poll::Ready(()) => Poll::Ready(Err(io::ErrorKind::TimedOut.into())),
            Poll::Pending => Poll::Pending,
        }
    }
}

impl<S: AsyncRead + Unpin> AsyncRead for Guarded<S> {
    fn poll_read(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<io::Result<()>> {
        let this = &mut *self;
        let before = buf.filled().len();
        match Pin::new(&mut this.inner).poll_read(cx, buf) {
            Poll::Ready(result) => {
                if buf.filled().len() > before {
                    this.touch();
                }
                Poll::Ready(result)
            }
            Poll::Pending => this.waiting(cx),
        }
    }
}

impl<S: AsyncWrite + Unpin> AsyncWrite for Guarded<S> {
    fn poll_write(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        data: &[u8],
    ) -> Poll<io::Result<usize>> {
        let this = &mut *self;
        match Pin::new(&mut this.inner).poll_write(cx, data) {
            Poll::Ready(result) => {
                if matches!(result, Ok(written) if written > 0) {
                    this.touch();
                }
                Poll::Ready(result)
            }
            Poll::Pending => this.waiting(cx),
        }
    }

    fn poll_flush(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.inner).poll_flush(cx)
    }

    fn poll_shutdown(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.inner).poll_shutdown(cx)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v4(last: u8) -> IpAddr {
        IpAddr::V4(std::net::Ipv4Addr::new(10, 0, 0, last))
    }

    #[test]
    fn the_pool_turns_away_an_address_at_its_own_cap() {
        let pool = HandshakePool::default();
        let held: Vec<_> = (0..MAX_HANDSHAKES_PER_IP)
            .map(|_| pool.admit(v4(1)).unwrap())
            .collect();
        assert!(pool.admit(v4(1)).is_none());
        // Another address is unaffected, and a finished handshake gives its place back.
        assert!(pool.admit(v4(2)).is_some());
        drop(held);
        assert!(pool.admit(v4(1)).is_some());
    }

    #[test]
    fn a_full_pool_makes_room_by_evicting_the_heaviest_address() {
        let pool = HandshakePool::default();
        let mut held = Vec::new();
        for device in 0..(MAX_HANDSHAKES / MAX_HANDSHAKES_PER_IP) {
            for _ in 0..MAX_HANDSHAKES_PER_IP {
                held.push(pool.admit(v4(u8::try_from(device).unwrap())).unwrap());
            }
        }
        assert_eq!(pool.lock().entries.len(), MAX_HANDSHAKES);
        // A stranger is let in; the pool stays at its size.
        let newcomer = pool.admit(v4(200));
        assert!(newcomer.is_some());
        assert_eq!(pool.lock().entries.len(), MAX_HANDSHAKES);
        // A second one from the same stranger is fine too (it holds 2, the heaviest holds 7 or 8).
        assert!(pool.admit(v4(200)).is_some());
    }

    #[test]
    fn a_full_pool_of_equal_shares_turns_a_newcomer_away() {
        // 64 addresses with one handshake each: nobody holds more than the newcomer would.
        let pool = HandshakePool::default();
        let mut held = Vec::new();
        for device in 0..u8::try_from(MAX_HANDSHAKES).unwrap() {
            held.push(pool.admit(v4(device)).unwrap());
        }
        assert!(pool.admit(v4(200)).is_none());
    }

    #[test]
    fn ipv6_addresses_of_one_subnet_share_a_budget() {
        let a: IpAddr = "fe80::1:2:3:4".parse().unwrap();
        let b: IpAddr = "fe80::9:9:9:9".parse().unwrap();
        assert_eq!(pool_key(a), pool_key(b));
        let mapped: IpAddr = "::ffff:10.0.0.7".parse().unwrap();
        assert_eq!(pool_key(mapped), v4(7));
        assert_eq!(pool_key(v4(5)), v4(5));
    }

    #[test]
    fn base64_matches_known_vectors() {
        assert_eq!(b64url_encode(b""), "");
        assert_eq!(b64url_encode(b"f"), "Zg");
        assert_eq!(b64url_encode(b"fo"), "Zm8");
        assert_eq!(b64url_encode(b"foo"), "Zm9v");
        assert_eq!(b64url_encode(b"foobar"), "Zm9vYmFy");
        assert_eq!(b64url_encode(&[0xfb, 0xff]), "-_8");
    }

    #[test]
    fn base64_round_trips() {
        for len in 0..40_u8 {
            let bytes: Vec<u8> = (0..len).map(|i| i.wrapping_mul(37)).collect();
            assert_eq!(b64url_decode(&b64url_encode(&bytes)), Some(bytes));
        }
    }

    #[test]
    fn base64_refuses_what_it_did_not_write() {
        assert_eq!(b64url_decode("Zm9v+"), None, "standard alphabet");
        assert_eq!(b64url_decode("Zm9v="), None, "padding");
        assert_eq!(b64url_decode("Zh"), None, "non-zero leftover bits");
        assert_eq!(b64url_decode("Z"), None, "impossible length");
    }

    #[test]
    fn a_fingerprint_is_43_characters_and_parses_back() {
        let id = Identity::generate().unwrap();
        let text = id.fingerprint().to_string();
        assert_eq!(text.len(), Fingerprint::TEXT_LEN);
        assert_eq!(Fingerprint::parse(&text), Some(id.fingerprint()));
        assert_eq!(Fingerprint::parse(&text[1..]), None);
        assert_eq!(Fingerprint::parse(&format!("{text}A")), None);
        assert_eq!(Fingerprint::parse(""), None);
    }

    #[test]
    fn two_identities_never_share_a_fingerprint() {
        let a = Identity::generate().unwrap();
        let b = Identity::generate().unwrap();
        assert_ne!(a.fingerprint(), b.fingerprint());
    }

    #[test]
    fn the_server_config_accepts_a_generated_identity() {
        let config = Identity::generate().unwrap().server_config().unwrap();
        assert_eq!(config.alpn_protocols, vec![b"http/1.1".to_vec()]);
    }

    #[test]
    fn an_identity_survives_a_restart() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("tls-identity.bin");
        let first = Identity::load_or_create(&path).unwrap();
        let second = Identity::load_or_create(&path).unwrap();
        assert_eq!(first.fingerprint(), second.fingerprint());
    }

    #[cfg(unix)]
    #[test]
    fn the_identity_file_is_owner_only() {
        use std::os::unix::fs::PermissionsExt as _;
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("tls-identity.bin");
        Identity::load_or_create(&path).unwrap();
        let mode = std::fs::metadata(&path).unwrap().permissions().mode();
        assert_eq!(mode & 0o777, 0o600);
    }

    #[test]
    fn a_damaged_file_is_replaced_not_trusted() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("tls-identity.bin");
        let first = Identity::load_or_create(&path).unwrap();
        for damage in [
            vec![0_u8; 1 << 20],
            Vec::new(),
            b"garbage".to_vec(),
            first.to_file_bytes()[..30].to_vec(),
            [first.to_file_bytes(), vec![0]].concat(),
        ] {
            std::fs::write(&path, damage).unwrap();
            let again = Identity::load_or_create(&path).unwrap();
            assert_ne!(again.fingerprint(), first.fingerprint());
            let stored = Identity::load_or_create(&path).unwrap();
            assert_eq!(
                stored.fingerprint(),
                again.fingerprint(),
                "the new one is kept"
            );
        }
    }

    #[test]
    fn a_key_that_does_not_match_the_certificate_is_refused() {
        let a = Identity::generate().unwrap();
        let b = Identity::generate().unwrap();
        let mixed = Identity {
            certificate: a.certificate.clone(),
            key: b.key,
        };
        assert!(mixed.server_config().is_err());
    }

    #[test]
    fn debug_output_never_contains_the_key() {
        let id = Identity::generate().unwrap();
        let shown = format!("{id:?}");
        assert!(shown.contains("fingerprint"));
        assert!(!shown.contains(&b64url_encode(&id.key)), "{shown}");
        assert!(!shown.contains("Pkcs8"), "{shown}");
    }
}
