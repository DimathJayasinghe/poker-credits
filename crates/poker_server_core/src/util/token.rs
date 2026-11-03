//! Session and host tokens: 128 random bits from the OS RNG. Only SHA-256 hashes are ever stored
//! (in snapshots and the journal), and comparison is constant-time.

use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

/// Makes a token: 32 lowercase hex characters.
///
/// # Errors
/// If the OS random source fails.
pub fn generate() -> Result<String, getrandom::Error> {
    let mut bytes = [0_u8; 16];
    getrandom::fill(&mut bytes)?;
    Ok(hex(&bytes))
}

/// SHA-256 of a token as lowercase hex; this is what gets persisted.
#[must_use]
pub fn hash(token: &str) -> String {
    hex(Sha256::digest(token.as_bytes()).as_slice())
}

/// Does `token` match the stored hash? Constant-time in the hash length.
#[must_use]
pub fn matches(token: &str, stored_hash: &str) -> bool {
    hash(token).as_bytes().ct_eq(stored_hash.as_bytes()).into()
}

fn hex(bytes: &[u8]) -> String {
    use std::fmt::Write as _;
    bytes
        .iter()
        .fold(String::with_capacity(bytes.len() * 2), |mut out, b| {
            let _ = write!(out, "{b:02x}");
            out
        })
}

#[cfg(test)]
mod tests {
    use super::{generate, hash, matches};

    #[test]
    fn tokens_are_random_hex_and_hash_matches() {
        let token = generate().unwrap();
        assert_eq!(token.len(), 32);
        assert!(token.bytes().all(|b| b.is_ascii_hexdigit()));
        assert_ne!(token, generate().unwrap());
        let stored = hash(&token);
        assert_eq!(stored.len(), 64);
        assert!(matches(&token, &stored));
        assert!(!matches("wrong", &stored));
        assert!(!matches(&token, "short"));
    }
}
