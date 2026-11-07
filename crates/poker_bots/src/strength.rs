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
