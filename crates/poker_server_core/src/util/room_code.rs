//! Room codes: four characters from an alphabet without look-alikes (no `0/O`, `1/I`).

/// Allowed characters. 32 of them, so a random byte masked with 31 is perfectly uniform.
pub const ALPHABET: &[u8; 32] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/// Length of a room code.
pub const LENGTH: usize = 4;

/// Makes a random code from the OS RNG.
///
/// # Errors
/// If the OS random source fails.
pub fn generate() -> Result<String, getrandom::Error> {
    let mut bytes = [0_u8; LENGTH];
    getrandom::fill(&mut bytes)?;
    Ok(bytes
        .iter()
        .filter_map(|b| ALPHABET.get(usize::from(b & 31)))
        .map(|c| char::from(*c))
        .collect())
}

/// Uppercases and validates user input; `None` when it cannot be a room code.
#[must_use]
pub fn normalize(input: &str) -> Option<String> {
    let upper = input.trim().to_ascii_uppercase();
    let valid = upper.len() == LENGTH && upper.bytes().all(|b| ALPHABET.contains(&b));
    valid.then_some(upper)
}
