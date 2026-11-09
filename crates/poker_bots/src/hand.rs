//! What a hand is worth on a board, without sampling: the made hand, the draws, how wet the
//! board is and which cards block a bluff. Pure functions of cards (no state, no randomness).

use poker_engine::card::{Card, Rank, Suit};
use poker_engine::hand_rank::{HandCategory, best_of};

/// A straight draw.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StraightDraw {
    /// Nothing to draw to.
    None,
    /// One rank completes it.
    Gutshot,
    /// Two ranks complete it (or two gutshots).
    OpenEnded,
}

/// The draws a hand has on a board with cards to come.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Draws {
    /// Four to a flush with at least one of my cards in it.
    pub flush: bool,
    /// The straight draw.
    pub straight: StraightDraw,
}

impl Draws {
    /// Any draw at all.
    #[must_use]
    pub fn any(self) -> bool {
        self.flush || self.straight != StraightDraw::None
    }

    /// A draw with about a third or more chance to arrive: a flush draw or an open-ended draw.
    #[must_use]
    pub fn strong(self) -> bool {
        self.flush || self.straight == StraightDraw::OpenEnded
    }
}

/// The category the board makes on its own (counting repeated ranks; with five cards, flushes and
/// straights too).
fn board_category(board: &[Card]) -> HandCategory {
    if board.len() >= 5
        && let Ok(rank) = best_of(board)
    {
        return rank.category();
    }
    let mut counts: Vec<usize> = Rank::ALL
        .iter()
        .map(|r| board.iter().filter(|c| c.rank == *r).count())
        .filter(|n| *n > 0)
        .collect();
    counts.sort_unstable_by(|a, b| b.cmp(a));
    match (
        counts.first().copied().unwrap_or(0),
        counts.get(1).copied().unwrap_or(0),
    ) {
        (4, _) => HandCategory::FourOfAKind,
        (3, 2) => HandCategory::FullHouse,
        (3, _) => HandCategory::ThreeOfAKind,
        (2, 2) => HandCategory::TwoPair,
        (2, _) => HandCategory::Pair,
        _ => HandCategory::HighCard,
    }
}

/// A hand that adds nothing to the board: worth a little more with a high card in hand, and about
/// a split when the board itself is a straight or better.
fn plays_the_board(hole: [Card; 2], on_board: HandCategory) -> f32 {
    if on_board >= HandCategory::Straight {
        return 0.36;
    }
    let kicker = hole.iter().map(|h| h.rank.value()).max().unwrap_or(2);
    0.22 + 0.04 * f32::from(kicker.saturating_sub(2)) / 12.0
}

fn pair_strength(hole: [Card; 2], board: &[Card]) -> f32 {
    let top = board.iter().map(|c| c.rank).max();
    if hole[0].rank == hole[1].rank {
        return if top.is_some_and(|t| hole[0].rank > t) {
            0.70
        } else {
            0.44
        };
    }
    let matched = hole
        .iter()
        .map(|h| h.rank)
        .filter(|r| board.iter().any(|b| b.rank == *r))
        .max();
    let Some(rank) = matched else {
        return 0.30;
    };
    if Some(rank) == top {
        let kicker = hole
            .iter()
            .map(|h| h.rank)
            .filter(|r| *r != rank)
            .max()
            .unwrap_or(Rank::Two);
        return if kicker >= Rank::Ten { 0.68 } else { 0.64 };
    }
    let mut distinct: Vec<Rank> = board.iter().map(|c| c.rank).collect();
    distinct.sort_unstable_by(|a, b| b.cmp(a));
    distinct.dedup();
    if distinct.get(1) == Some(&rank) {
        0.48
    } else {
        0.38
    }
}

/// How strong my hand is against one random hand, from its made category alone (0 to 1). The
/// cards that play are only mine if they beat what the board already makes.
#[must_use]
pub fn made_strength(hole: [Card; 2], board: &[Card]) -> f32 {
    let mut cards = hole.to_vec();
    cards.extend_from_slice(board);
    let Ok(rank) = best_of(&cards) else {
        return 0.3;
    };
    let category = rank.category();
    let on_board = board_category(board);
    let improved = if board.len() >= 5 {
        best_of(board).is_ok_and(|b| rank > b)
    } else {
        category > on_board
    };
    if !improved {
        return plays_the_board(hole, on_board);
    }
    let pocket = hole[0].rank == hole[1].rank;
    match category {
        HandCategory::HighCard => plays_the_board(hole, on_board),
        HandCategory::Pair => pair_strength(hole, board),
        HandCategory::TwoPair => {
            if on_board >= HandCategory::Pair {
                0.60
            } else {
                0.72
            }
        }
        HandCategory::ThreeOfAKind => {
            if pocket {
                0.84
            } else if on_board >= HandCategory::Pair {
                0.74
            } else {
                0.78
            }
        }
        HandCategory::Straight => 0.86,
        HandCategory::Flush => 0.90,
        HandCategory::FullHouse => 0.95,
        HandCategory::FourOfAKind | HandCategory::StraightFlush => 0.99,
    }
}

/// [`made_strength`] against `opponents` hands: every extra opponent makes a hand worth less.
#[must_use]
pub fn made_hand_tier(hole: [Card; 2], board: &[Card], opponents: usize) -> f32 {
    #[allow(clippy::cast_precision_loss, reason = "at most nine opponents")]
    let extra = opponents.saturating_sub(1) as f32;
    made_strength(hole, board).powf(1.0 + 0.12 * extra)
}

/// Bit `v` set for each rank value `v` in 2..=14, and bit 1 as well for an ace (the wheel).
fn rank_bits<'a>(cards: impl Iterator<Item = &'a Card>) -> u16 {
    cards.fold(0_u16, |bits, card| {
        let value = u16::from(card.rank.value());
        let ace_low = if value == 14 { 1 << 1 } else { 0 };
        bits | (1 << value) | ace_low
    })
}

/// The draws my hole cards have with this board (none when the board is complete).
#[must_use]
pub fn draws(hole: [Card; 2], board: &[Card]) -> Draws {
    let none = Draws {
        flush: false,
        straight: StraightDraw::None,
    };
    if board.len() < 3 || board.len() >= 5 {
        return none;
    }
    let mut cards = hole.to_vec();
    cards.extend_from_slice(board);
    if best_of(&cards).is_ok_and(|r| r.category() >= HandCategory::Straight) {
        return none;
    }
    let flush = Suit::ALL.iter().any(|suit| {
        let total = cards.iter().filter(|c| c.suit == *suit).count();
        let mine = hole.iter().filter(|c| c.suit == *suit).count();
        total == 4 && mine >= 1
    });
    let all = rank_bits(cards.iter());
    let mine = rank_bits(hole.iter());
    let mut completing = 0_u16;
    for low in 1..=10_u16 {
        let window: u16 = (low..low + 5).fold(0, |bits, v| bits | (1 << v));
        let present = all & window;
        if present.count_ones() == 4 && mine & window != 0 {
            let missing = window & !present;
            // The ace counts once whether it completes the low or the high end.
            let value = missing.trailing_zeros();
            completing |= 1 << if value == 1 { 14 } else { value };
        }
    }
    let straight = match completing.count_ones() {
        0 => StraightDraw::None,
        1 => StraightDraw::Gutshot,
        _ => StraightDraw::OpenEnded,
    };
    Draws { flush, straight }
}

/// How much the board invites draws and made hands (0 dry, 1 very wet): flush potential and
/// connected cards raise it, a paired board lowers it.
#[must_use]
pub fn wetness(board: &[Card]) -> f32 {
    if board.len() < 3 {
        return 0.3;
    }
    let suited = Suit::ALL
        .iter()
        .map(|s| board.iter().filter(|c| c.suit == *s).count())
        .max()
        .unwrap_or(0);
    let flush = match suited {
        0..=1 => 0.0,
        2 => 0.15,
        3 => 0.55,
        4 => 0.85,
        _ => 0.25,
    };
    let bits = rank_bits(board.iter());
    let connected = (1..=10_u16)
        .map(|low| {
            let window: u16 = (low..low + 5).fold(0, |b, v| b | (1 << v));
            (bits & window).count_ones()
        })
        .max()
        .unwrap_or(0);
    let straight = match connected {
        0..=2 => 0.0,
        3 => 0.5,
        4 => 0.9,
        _ => 0.3,
    };
    let paired = Rank::ALL
        .iter()
        .any(|r| board.iter().filter(|c| c.rank == *r).count() >= 2);
    let wet = 0.55 * flush + 0.55 * straight;
    let wet: f32 = if paired { wet * 0.6 } else { wet };
    wet.clamp(0.0, 1.0)
}

/// How much my hole cards block hands an opponent would call or raise with (0 to 1): the nut
/// flush card on a flush board, a card of the top rank.
#[must_use]
pub fn blockers(hole: [Card; 2], board: &[Card]) -> f32 {
    let mut score = 0.0_f32;
    for suit in Suit::ALL {
        if board.iter().filter(|c| c.suit == suit).count() < 3 {
            continue;
        }
        let nuts = Rank::ALL
            .iter()
            .rev()
            .find(|r| !board.iter().any(|c| c.suit == suit && c.rank == **r))
            .copied();
        if hole.iter().any(|h| h.suit == suit && Some(h.rank) == nuts) {
            score += 0.6;
        } else if hole.iter().any(|h| h.suit == suit && h.rank >= Rank::Queen) {
            score += 0.3;
        }
    }
    if let Some(top) = board.iter().map(|c| c.rank).max()
        && hole.iter().any(|h| h.rank == top)
    {
        score += 0.15;
    }
    score.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn c(text: &str) -> Card {
        text.parse().unwrap()
    }
    fn hole(a: &str, b: &str) -> [Card; 2] {
        [c(a), c(b)]
    }
    fn board(text: &str) -> Vec<Card> {
        text.split_whitespace().map(c).collect()
    }

    #[test]
    fn a_hand_that_only_plays_the_board_is_not_a_monster() {
        let junk = hole("2c", "3d");
        for (name, b, below) in [
            ("trips on the board", "Ks Kd Kh 9c 4d", 0.35),
            ("trips on the flop", "Ks Kd Kh", 0.35),
            ("two pair on the board", "As Ad 7s 7h Kc", 0.35),
            ("a flush on the board", "Ah 9h 5h Jh 4h", 0.5),
            ("a straight on the board", "5s 6d 7h 8c 9d", 0.5),
        ] {
            let tier = made_strength(junk, &board(b));
            assert!(tier < below, "{name}: {tier}");
        }
    }

    #[test]
    fn a_hand_that_improves_the_board_is_strong() {
        for (name, h, b, at_least) in [
            ("full house", hole("2c", "2d"), "Ks Kd 2h 9c 4d", 0.9),
            ("set", hole("9c", "9d"), "9s Kd 4h", 0.8),
            ("flush", hole("Ah", "Kh"), "Qh 9h 2h", 0.88),
            (
                "nut flush on a flush board",
                hole("Ah", "2c"),
                "Kh 9h 5h Jh 3h",
                0.85,
            ),
            ("two pair", hole("Ac", "9d"), "9s Ad 4h", 0.65),
        ] {
            let tier = made_strength(h, &board(b));
            assert!(tier >= at_least, "{name}: {tier}");
        }
    }

    #[test]
    fn pairs_are_ranked_by_how_high_they_are() {
        let b = board("Ah 7c 2d");
        let top = made_strength(hole("Ad", "Kc"), &b);
        let under = made_strength(hole("5c", "5d"), &b);
        let over = made_strength(hole("Qc", "Qd"), &board("9h 7c 2d"));
        let none = made_strength(hole("Kc", "Qd"), &b);
        assert!(top > 0.6, "top pair {top}");
        assert!((0.35..0.5).contains(&under), "underpair {under}");
        assert!(over > 0.65, "overpair {over}");
        assert!(none < 0.3, "no pair {none}");
    }

    #[test]
    fn more_opponents_make_a_hand_worth_less() {
        let b = board("Ah 7c 2d");
        let h = hole("Ad", "Kc");
        assert!(made_hand_tier(h, &b, 1) > made_hand_tier(h, &b, 4));
    }

    #[test]
    fn draws_are_found_and_board_only_draws_are_not_mine() {
        let d = draws(hole("Ah", "5h"), &board("Kh 9h 2c"));
        assert!(d.flush && d.strong());
        let d = draws(hole("9c", "Tc"), &board("8d Jh 2s"));
        assert_eq!(d.straight, StraightDraw::OpenEnded);
        let d = draws(hole("9c", "Tc"), &board("Jh Kd 2s"));
        assert_eq!(d.straight, StraightDraw::Gutshot);
        assert!(d.any() && !d.strong());
        // The wheel draw.
        let d = draws(hole("Ah", "2c"), &board("3d 4h 9s"));
        assert_eq!(d.straight, StraightDraw::Gutshot);
        // Four to a straight on the board is nobody's draw in particular.
        let d = draws(hole("2c", "2d"), &board("5s 6d 7h 8c"));
        assert!(!d.any());
        // A made straight or flush has nothing left to draw to.
        assert!(!draws(hole("9c", "Tc"), &board("7d 8h Jh")).any());
        assert!(!draws(hole("Ah", "Kh"), &board("Qh 9h 2h 5h")).flush);
        // Nothing to draw to on a complete board.
        assert!(!draws(hole("Ah", "5h"), &board("Kh 9h 2c 3h 8d")).any());
    }

    #[test]
    fn wet_boards_are_wetter_than_dry_ones() {
        let dry = wetness(&board("Ks 7d 2c"));
        let wet = wetness(&board("9h Th Jh"));
        let paired = wetness(&board("Ks Kd 2c"));
        assert!(wet > dry + 0.3, "wet {wet} dry {dry}");
        assert!(paired <= dry + 0.05, "paired {paired} dry {dry}");
        for w in [dry, wet, paired] {
            assert!((0.0..=1.0).contains(&w));
        }
    }

    #[test]
    fn the_nut_flush_card_blocks_a_bluff_catcher() {
        let b = board("Kh 9h 5h");
        assert!(blockers(hole("Ah", "2c"), &b) >= 0.5);
        assert!(blockers(hole("2c", "3d"), &b) <= 0.1);
    }
}
