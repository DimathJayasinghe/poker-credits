//! A tiny WebSocket and HTTP client for the socket-level tests. It speaks just enough RFC 6455
//! (text frames, masking, close) so the tests need no extra dependency.
#![allow(
    dead_code,
    missing_docs,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing
)]

use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use poker_server_core::Fingerprint;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::{WebPkiSupportedAlgorithms, ring as ring_provider};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{DigitallySignedStruct, SignatureScheme};
use serde_json::Value;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio_rustls::TlsConnector;

/// How long a test waits for the server before it calls it a failure.
const WAIT: Duration = Duration::from_secs(5);

/// What the client received.
#[derive(Debug, PartialEq, Eq)]
pub enum Frame {
    Text(String),
    Ping,
    Close,
}

/// Either a plain TCP stream or a TLS one.
pub trait Conn: AsyncRead + AsyncWrite + Unpin + Send {}
impl<T: AsyncRead + AsyncWrite + Unpin + Send> Conn for T {}

pub struct WsClient {
    stream: Box<dyn Conn>,
    buf: Vec<u8>,
}

/// What a guest does with a host's certificate: accept exactly the pinned one (or any, for a first
/// contact), and check the handshake signature so the host must hold the key. TLS 1.3 only.
#[derive(Debug)]
struct Pinned {
    pin: Option<Fingerprint>,
    algorithms: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for Pinned {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        match self.pin {
            Some(pin) if Fingerprint::of_certificate(end_entity) != pin => Err(
                rustls::Error::General("certificate does not match the pin".into()),
            ),
            _ => Ok(ServerCertVerified::assertion()),
        }
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        Err(rustls::Error::PeerIncompatible(
            rustls::PeerIncompatible::Tls12NotOffered,
        ))
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// Opens a TLS connection the way the app does. `pin` is the fingerprint from the QR code;
/// `None` accepts whatever certificate the host shows (trust on first use).
pub async fn tls_connect(
    addr: SocketAddr,
    pin: Option<Fingerprint>,
) -> std::io::Result<Box<dyn Conn>> {
    tls_connect_with(addr, pin, &[&rustls::version::TLS13]).await
}

/// [`tls_connect`] with the protocol versions the client offers (to prove TLS 1.2 is refused).
pub async fn tls_connect_with(
    addr: SocketAddr,
    pin: Option<Fingerprint>,
    versions: &[&'static rustls::SupportedProtocolVersion],
) -> std::io::Result<Box<dyn Conn>> {
    let provider = Arc::new(ring_provider::default_provider());
    let verifier = Pinned {
        pin,
        algorithms: provider.signature_verification_algorithms,
    };
    let mut config = rustls::ClientConfig::builder_with_provider(provider)
        .with_protocol_versions(versions)
        .unwrap()
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(verifier))
        .with_no_client_auth();
    config.alpn_protocols = vec![b"http/1.1".to_vec()];
    let tcp = TcpStream::connect(addr).await?;
    let name = ServerName::IpAddress(addr.ip().into());
    let tls = TlsConnector::from(Arc::new(config))
        .connect(name, tcp)
        .await?;
    Ok(Box::new(tls))
}

/// Opens the TCP connection, sends the upgrade request and returns the stream with the status
/// code and any bytes that followed the response headers.
async fn handshake(addr: SocketAddr, origin: Option<&str>) -> (Box<dyn Conn>, u16, Vec<u8>) {
    let stream = TcpStream::connect(addr).await.unwrap();
    handshake_over(Box::new(stream), addr, origin).await
}

async fn handshake_over(
    mut stream: Box<dyn Conn>,
    addr: SocketAddr,
    origin: Option<&str>,
) -> (Box<dyn Conn>, u16, Vec<u8>) {
    let origin = origin.map_or_else(String::new, |o| format!("Origin: {o}\r\n"));
    let request = format!(
        "GET /v1/ws HTTP/1.1\r\nHost: {addr}\r\n{origin}Upgrade: websocket\r\nConnection: Upgrade\r\n\
         Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    );
    stream.write_all(request.as_bytes()).await.unwrap();
    let mut head = Vec::new();
    let mut byte = [0_u8; 1];
    while !head.ends_with(b"\r\n\r\n") {
        let n = tokio::time::timeout(WAIT, stream.read(&mut byte))
            .await
            .unwrap()
            .unwrap();
        assert!(n > 0, "server closed during the handshake");
        head.push(byte[0]);
    }
    let text = String::from_utf8_lossy(&head).into_owned();
    let status = text.split_whitespace().nth(1).unwrap().parse().unwrap();
    (stream, status, Vec::new())
}

impl WsClient {
    /// Connects and expects `101 Switching Protocols`.
    pub async fn connect(addr: SocketAddr) -> WsClient {
        let (stream, status, buf) = handshake(addr, None).await;
        assert_eq!(status, 101, "expected an upgrade");
        WsClient { stream, buf }
    }

    /// Connects and returns the HTTP status instead of asserting it (for refusals).
    pub async fn try_connect(addr: SocketAddr) -> Result<WsClient, u16> {
        Self::try_connect_from(addr, None).await
    }

    /// Connects over TLS, pinned to `pin`, and expects `101 Switching Protocols`.
    pub async fn connect_tls(addr: SocketAddr, pin: Option<Fingerprint>) -> WsClient {
        let stream = tls_connect(addr, pin).await.unwrap();
        let (stream, status, buf) = handshake_over(stream, addr, None).await;
        assert_eq!(status, 101, "expected an upgrade");
        WsClient { stream, buf }
    }

    /// Like [`WsClient::try_connect`], sending an `Origin` header like a browser page would.
    pub async fn try_connect_from(addr: SocketAddr, origin: Option<&str>) -> Result<WsClient, u16> {
        let (stream, status, buf) = handshake(addr, origin).await;
        if status == 101 {
            Ok(WsClient { stream, buf })
        } else {
            Err(status)
        }
    }

    pub async fn send_text(&mut self, text: &str) {
        let payload = text.as_bytes();
        let mask = [0x12, 0x34, 0x56, 0x78];
        let mut frame = vec![0x81];
        match payload.len() {
            n if n < 126 => frame.push(0x80 | u8::try_from(n).unwrap()),
            n if u16::try_from(n).is_ok() => {
                frame.push(0x80 | 0x7e);
                frame.extend_from_slice(&u16::try_from(n).unwrap().to_be_bytes());
            }
            n => {
                frame.push(0x80 | 0x7f);
                frame.extend_from_slice(&u64::try_from(n).unwrap().to_be_bytes());
            }
        }
        frame.extend_from_slice(&mask);
        frame.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
        // The server may already have closed (for example after a violation); that is the
        // behaviour under test, so a failed write is not an error here.
        let _ = self.stream.write_all(&frame).await;
    }

    /// Sends one frame exactly as described, for protocol abuse: any opcode, payload, `fin` bit,
    /// reserved bits, masking and even a length field that lies about the payload.
    pub async fn send_frame(
        &mut self,
        first: u8,
        payload: &[u8],
        masked: bool,
        claimed: Option<u64>,
    ) {
        let mask = [0xa5, 0x5a, 0x0f, 0xf0];
        let len = claimed.unwrap_or_else(|| u64::try_from(payload.len()).unwrap());
        let flag = if masked { 0x80 } else { 0 };
        let mut frame = vec![first];
        if len < 126 {
            frame.push(flag | u8::try_from(len).unwrap());
        } else if let Ok(short) = u16::try_from(len) {
            frame.push(flag | 0x7e);
            frame.extend_from_slice(&short.to_be_bytes());
        } else {
            frame.push(flag | 0x7f);
            frame.extend_from_slice(&len.to_be_bytes());
        }
        if masked {
            frame.extend_from_slice(&mask);
            frame.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
        } else {
            frame.extend_from_slice(payload);
        }
        let _ = self.stream.write_all(&frame).await;
    }

    /// Writes bytes to the socket untouched.
    pub async fn send_raw(&mut self, bytes: &[u8]) {
        let _ = self.stream.write_all(bytes).await;
    }

    pub async fn send(&mut self, message: Value) {
        self.send_text(&message.to_string()).await;
    }

    async fn fill(&mut self, wanted: usize) -> bool {
        while self.buf.len() < wanted {
            let mut chunk = [0_u8; 4096];
            match tokio::time::timeout(WAIT, self.stream.read(&mut chunk)).await {
                Ok(Ok(n)) if n > 0 => self.buf.extend_from_slice(&chunk[..n]),
                _ => return false,
            }
        }
        true
    }

    /// Next frame, or `None` when the connection ended.
    pub async fn recv_frame(&mut self) -> Option<Frame> {
        if !self.fill(2).await {
            return None;
        }
        let opcode = self.buf[0] & 0x0f;
        let (len, header) = match self.buf[1] & 0x7f {
            0x7e => {
                if !self.fill(4).await {
                    return None;
                }
                (
                    usize::from(u16::from_be_bytes([self.buf[2], self.buf[3]])),
                    4,
                )
            }
            0x7f => {
                if !self.fill(10).await {
                    return None;
                }
                let bytes: [u8; 8] = self.buf[2..10].try_into().unwrap();
                (usize::try_from(u64::from_be_bytes(bytes)).unwrap(), 10)
            }
            n => (usize::from(n), 2),
        };
        if !self.fill(header + len).await {
            return None;
        }
        let payload: Vec<u8> = self.buf[header..header + len].to_vec();
        self.buf.drain(..header + len);
        Some(match opcode {
            1 => Frame::Text(String::from_utf8(payload).unwrap()),
            9 => Frame::Ping,
            _ => Frame::Close,
        })
    }

    /// Next JSON message, skipping pings. `None` when the server closed the connection.
    pub async fn recv(&mut self) -> Option<Value> {
        loop {
            match self.recv_frame().await? {
                Frame::Text(text) => return Some(serde_json::from_str(&text).unwrap()),
                Frame::Ping => {}
                Frame::Close => return None,
            }
        }
    }

    /// Reads messages until one has this `type`; panics if the connection ends first.
    pub async fn expect(&mut self, message_type: &str) -> Value {
        loop {
            let message = self
                .recv()
                .await
                .unwrap_or_else(|| panic!("closed before {message_type}"));
            if message["type"] == message_type {
                return message;
            }
        }
    }

    /// Everything that arrives within `quiet` of silence.
    pub async fn drain(&mut self, quiet: Duration) -> Vec<Value> {
        let mut out = Vec::new();
        while let Ok(Some(message)) = tokio::time::timeout(quiet, self.recv()).await {
            out.push(message);
        }
        out
    }

    /// True once the server has closed the connection (after reading what is still queued).
    pub async fn closed(&mut self) -> bool {
        loop {
            match tokio::time::timeout(WAIT, self.recv_frame()).await {
                Ok(None | Some(Frame::Close)) => return true,
                Ok(Some(_)) => {}
                Err(_) => return false,
            }
        }
    }

    /// Drops the TCP connection without a close handshake, like a lost network.
    pub fn kill(self) {
        drop(self);
    }
}

/// `GET path` over plain HTTP. Returns the status and the body.
pub async fn http_get(addr: SocketAddr, path: &str) -> (u16, String) {
    let mut stream = TcpStream::connect(addr).await.unwrap();
    let request = format!("GET {path} HTTP/1.1\r\nHost: {addr}\r\nConnection: close\r\n\r\n");
    stream.write_all(request.as_bytes()).await.unwrap();
    let mut raw = Vec::new();
    tokio::time::timeout(WAIT, stream.read_to_end(&mut raw))
        .await
        .unwrap()
        .unwrap();
    let text = String::from_utf8_lossy(&raw).into_owned();
    let status = text.split_whitespace().nth(1).unwrap().parse().unwrap();
    let body = text
        .split_once("\r\n\r\n")
        .map(|(_, b)| b.to_owned())
        .unwrap_or_default();
    (status, dechunk(&body))
}

/// Axum answers small JSON with a content length, but be ready for chunked encoding too.
fn dechunk(body: &str) -> String {
    let Some((size_line, rest)) = body.split_once("\r\n") else {
        return body.to_owned();
    };
    match usize::from_str_radix(size_line.trim(), 16) {
        Ok(size) if rest.len() >= size => rest[..size].to_owned(),
        _ => body.to_owned(),
    }
}
