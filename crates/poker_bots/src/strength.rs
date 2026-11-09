//! Starting-hand strength: a 169-entry table (13 pairs, 78 suited, 78 offsuit hands) built at
//! compile time from the Chen formula, so it is auditable and costs 169 bytes.

use poker_engine::card::{Card, Rank};

/// Half-points of the highest card in the Chen formula.
#[allow(
    clippy::cast_possible_truncation,
    clippy::cast_possible_wrap,
    reason = "rank indexes are 0..13"
)]
const fn high_halves(rank: usize) -> i32 {
    // rank 0 = Two .. 12 = Ace
    match rank {
        12 => 20,
        11 => 16,
        10 => 14,
        9 => 12,
        other => other as i32 + 2,
    }
}

/// Chen score in half-points for a hand with `high >= low` rank indexes.
const fn chen_halves(high: usize, low: usize, suited: bool) -> i32 {
    let base = high_halves(high);
    if high == low {
        let doubled = base * 2;
        return if doubled < 10 { 10 } else { doubled };
    }
    let mut score = base;
    if suited {
        score += 4;
    }
    let gap = high - low - 1;
    score -= match gap {
        0 => 0,
        1 => 2,
        2 => 4,
        3 => 8,
        _ => 10,
    };
    if gap <= 1 && high < 10 {
        score += 2;
    }
    score
}

#[allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::indexing_slicing,
    reason = "evaluated at compile time: a mistake here fails the build, and the value is clamped to 0..=255"
)]
const fn build() -> [u8; 169] {
    let mut table = [0_u8; 169];
    let mut row = 0;
    while row < 13 {
        let mut col = 0;
        while col < 13 {
            let (high, low, suited) = if row >= col {
                (row, col, row != col)
            } else {
                (col, row, false)
            };
            let halves = chen_halves(high, low, suited) + 4;
            let clamped = if halves < 0 {
                0
            } else if halves > 44 {
                44
            } else {
                halves
            };
            table[row * 13 + col] = (clamped * 255 / 44) as u8;
            col += 1;
        }
        row += 1;
    }
    table
}

/// Strength 0..=255 for each (high, low, suited) combination: pairs and suited hands sit at
/// `high * 13 + low`, offsuit hands at `low * 13 + high`.
static TABLE: [u8; 169] = build();

fn rank_index(rank: Rank) -> usize {
    Rank::ALL.iter().position(|r| *r == rank).unwrap_or(0)
}

/// How strong a starting hand is, from 0.0 (worst) to 1.0 (pocket aces).
#[must_use]
pub fn preflop_strength(hole: [Card; 2]) -> f32 {
    let (a, b) = (rank_index(hole[0].rank), rank_index(hole[1].rank));
    let (high, low) = (a.max(b), a.min(b));
    let suited = hole[0].suit == hole[1].suit;
    let index = if high == low || suited {
        high * 13 + low
    } else {
        low * 13 + high
    };
    f32::from(TABLE.get(index).copied().unwrap_or(0)) / 255.0
}

/// Shifts a starting-hand strength for the situation: later position plays a little wider, and
/// every extra opponent still in lowers what a speculative hand is worth.
///
/// `late_position` is 0.0 for the first to act and 1.0 for the button.
#[must_use]
pub fn preflop_adjust(strength: f32, late_position: f32, opponents: usize) -> f32 {
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let extra = opponents.saturating_sub(1) as f32;
    (strength + 0.08 * (late_position.clamp(0.0, 1.0) - 0.5) - 0.012 * extra).clamp(0.0, 1.0)
}

/// Every starting hand's strength, best first (1326 numbers, built once).
fn ranked_combos() -> &'static [f32] {
    static RANKED: std::sync::OnceLock<Vec<f32>> = std::sync::OnceLock::new();
    RANKED.get_or_init(|| {
        let deck: Vec<Card> = Rank::ALL
            .iter()
            .flat_map(|r| {
                poker_engine::card::Suit::ALL
                    .iter()
                    .map(move |s| Card::new(*r, *s))
            })
            .collect();
        let mut all = Vec::with_capacity(1326);
        for (i, a) in deck.iter().enumerate() {
            for b in deck.iter().skip(i + 1) {
                all.push(preflop_strength([*a, *b]));
            }
        }
        all.sort_unstable_by(|x, y| y.total_cmp(x));
        all
    })
}

/// The lowest [`preflop_strength`] among the best `fraction` (0 to 1) of all 1326 starting hands.
/// A player who plays the top 15% of hands plays every hand at or above `top_fraction_threshold(0.15)`.
#[must_use]
pub fn top_fraction_threshold(fraction: f32) -> f32 {
    let ranked = ranked_combos();
    if fraction >= 1.0 {
        return 0.0;
    }
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        clippy::cast_precision_loss,
        reason = "an index into 1326 hands"
    )]
    let wanted = (fraction.max(0.0) * ranked.len() as f32).round() as usize;
    let value = ranked.get(wanted.max(1) - 1).copied().unwrap_or(0.0);
    // Many hands share one strength: take whichever side of the tie is nearer the share asked for.
    let with_ties = ranked.iter().take_while(|x| **x >= value).count();
    let without = ranked.iter().take_while(|x| **x > value).count();
    if without > 0 && with_ties.abs_diff(wanted) > wanted.abs_diff(without) {
        return ranked.get(without - 1).copied().unwrap_or(value);
    }
    value
}

/// How much of the deck of starting hands to shove with at `stack_bb` big blinds behind: nearly
/// everything at 2bb, about a third at 8bb, a tenth at 12bb. Later position and fewer opponents
/// push wider.
#[must_use]
pub fn push_fraction(stack_bb: f32, late_position: f32, opponents: usize) -> f32 {
    let base = (1.3 - 0.1 * stack_bb).max(0.0);
    let position = 0.75 + 0.5 * late_position.clamp(0.0, 1.0);
    let heads_up = match opponents {
        0 | 1 => 1.5,
        2 => 1.15,
        _ => 1.0,
    };
    (base * position * heads_up).clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use poker_engine::card::Suit;

    fn hole(text: &str) -> [Card; 2] {
        let mut it = text.split_whitespace().map(|t| t.parse::<Card>().unwrap());
        [it.next().unwrap(), it.next().unwrap()]
    }

    fn all_combos() -> Vec<[Card; 2]> {
        let deck: Vec<Card> = Rank::ALL
            .iter()
            .flat_map(|r| Suit::ALL.iter().map(move |s| Card::new(*r, *s)))
            .collect();
        let mut out = Vec::new();
        for (i, a) in deck.iter().enumerate() {
            for b in deck.iter().skip(i + 1) {
                out.push([*a, *b]);
            }
        }
        out
    }

    #[test]
    fn the_top_fraction_threshold_matches_its_share_of_hands() {
        let combos = all_combos();
        assert_eq!(combos.len(), 1326);
        for fraction in [0.05_f32, 0.15, 0.30, 0.50, 0.80] {
            let threshold = top_fraction_threshold(fraction);
            let covered = combos
                .iter()
                .filter(|h| preflop_strength(**h) >= threshold)
                .count();
            let share = f32::from(u16::try_from(covered).unwrap()) / 1326.0;
            assert!(
                (share - fraction).abs() < 0.06,
                "top {fraction}: threshold {threshold} covers {share}"
            );
        }
        assert!(top_fraction_threshold(0.05) > top_fraction_threshold(0.30));
        assert!(preflop_strength(hole("Ah Ad")) >= top_fraction_threshold(0.05));
        assert!(preflop_strength(hole("7c 2d")) < top_fraction_threshold(0.50));
        assert!(top_fraction_threshold(1.0) <= 0.0001);
    }

    #[test]
    fn the_shoving_range_widens_as_the_stack_shrinks() {
        let at = |bb: f32| push_fraction(bb, 0.5, 5);
        assert!(at(2.0) > at(4.0) && at(4.0) > at(7.0) && at(7.0) > at(10.0));
        assert!(at(10.0) > at(13.0) || at(13.0) < 0.15);
        assert!(at(2.0) > 0.85, "{}", at(2.0));
        assert!((0.15..0.45).contains(&at(9.0)), "{}", at(9.0));
        assert!(push_fraction(8.0, 1.0, 5) > push_fraction(8.0, 0.0, 5));
        assert!(push_fraction(8.0, 0.5, 1) > push_fraction(8.0, 0.5, 6));
        for bb in [0.5_f32, 3.0, 12.0, 40.0] {
            assert!((0.0..=1.0).contains(&push_fraction(bb, 0.5, 3)));
        }
    }
}
