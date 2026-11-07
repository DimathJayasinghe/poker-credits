//! Plain first names for the bots, so they read as people at the table.

use crate::rng::BotRng;

/// 40 names: letters only, 3 to 8 characters, all valid room names.
pub const NAMES: [&str; 40] = [
    "Maya", "Liam", "Noah", "Ava", "Ethan", "Zoe", "Lucas", "Mia", "Owen", "Ella", "Caleb", "Nora",
    "Isaac", "Ruby", "Jonas", "Iris", "Felix", "Hana", "Marco", "Lena", "Tariq", "Sana", "Diego",
    "Amara", "Kenji", "Priya", "Oscar", "Leila", "Viktor", "Nadia", "Rafael", "Yuki", "Elias",
    "Carla", "Hugo", "Tessa", "Anders", "Mira", "Dante", "Freya",
];

/// `count` different names, avoiding any in `taken` (compared ignoring case). Fewer come back only
/// if the pool runs out.
pub fn pick_names(count: usize, taken: &[&str], rng: &mut BotRng) -> Vec<&'static str> {
    let mut pool: Vec<&'static str> = NAMES
        .iter()
        .copied()
        .filter(|n| !taken.iter().any(|t| t.eq_ignore_ascii_case(n)))
        .collect();
    let mut picked = Vec::with_capacity(count);
    while picked.len() < count && !pool.is_empty() {
        let index = usize::try_from(rng.below(u32::try_from(pool.len()).unwrap_or(1))).unwrap_or(0);
        picked.push(pool.swap_remove(index));
    }
    picked
}
