//! Main and side pots from per-player contributions. Pure chip arithmetic: no hand ranking, no
//! turn order.

use crate::state::PotTier;
use crate::types::{Chips, SeatIndex};

/// What one seat has put into the hand.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Contribution {
    /// Seat that paid.
    pub seat: SeatIndex,
    /// Chips paid over the whole hand.
    pub amount: Chips,
    /// Folded players pay into pots but cannot win them.
    pub folded: bool,
}

/// The part of the biggest contribution that nobody matched.
///
/// It is the top contribution minus the second-highest contribution among *all* contributors,
/// folded players included: a folder who matched a bet means that bet was called. Returns `None`
/// when two seats tie for the top.
#[must_use]
pub fn uncalled_refund(contributions: &[Contribution]) -> Option<(SeatIndex, Chips)> {
    let top = contributions
        .iter()
        .max_by_key(|c| (c.amount, std::cmp::Reverse(c.seat)))?;
    let second = contributions
        .iter()
        .filter(|c| c.seat != top.seat)
        .map(|c| c.amount)
        .max()
        .unwrap_or(Chips::ZERO);
    let excess = top.amount.saturating_sub(second);
    if excess.is_zero() {
        None
    } else {
        Some((top.seat, excess))
    }
}

/// Splits contributions into a main pot and side pots.
///
/// One tier per distinct contribution level of a non-folded player. Each tier collects the slice
/// of every contribution between the previous level and this one, and only non-folded players who
/// reached the level can win it. Chips a folded player put in above the highest live level are
/// added to the last pot. Apply [`uncalled_refund`] first.
#[must_use]
pub fn calculate(contributions: &[Contribution]) -> Vec<PotTier> {
    let mut levels: Vec<Chips> = contributions
        .iter()
        .filter(|c| !c.folded && !c.amount.is_zero())
        .map(|c| c.amount)
        .collect();
    levels.sort_unstable();
    levels.dedup();

    let mut pots = Vec::with_capacity(levels.len());
    let mut previous = Chips::ZERO;
    for (position, level) in levels.iter().enumerate() {
        let amount = contributions
            .iter()
            .map(|c| c.amount.min(*level).saturating_sub(c.amount.min(previous)))
            .fold(Chips::ZERO, Chips::saturating_add);
        let mut eligible: Vec<SeatIndex> = contributions
            .iter()
            .filter(|c| !c.folded && c.amount >= *level)
            .map(|c| c.seat)
            .collect();
        eligible.sort_unstable();
        pots.push(PotTier {
            tier_index: u32::try_from(position).unwrap_or(u32::MAX),
            amount,
            eligible,
        });
        previous = *level;
    }

    let leftover = contributions
        .iter()
        .map(|c| c.amount.saturating_sub(previous))
        .fold(Chips::ZERO, Chips::saturating_add);
    if !leftover.is_zero()
        && let Some(last) = pots.last_mut()
    {
        last.amount = last.amount.saturating_add(leftover);
    }
    pots
}

/// Orders winners clockwise starting with the first seat after the button.
///
/// This is the order the odd-chip rule needs.
#[must_use]
pub fn clockwise_from_button(winners: &[SeatIndex], button: Option<SeatIndex>) -> Vec<SeatIndex> {
    let mut ordered = winners.to_vec();
    ordered.sort_unstable_by_key(|seat| (button.is_some_and(|b| *seat <= b), *seat));
    ordered
}

/// Splits one pot among winners already ordered with [`clockwise_from_button`].
///
/// Everyone gets the floor share; the remainder goes one chip each to the first winners in order
/// (the earliest seat clockwise from the button gets the odd chip). The shares always add up to
/// `amount`.
#[must_use]
pub fn split(amount: Chips, ordered_winners: &[SeatIndex]) -> Vec<(SeatIndex, Chips)> {
    let count = u64::try_from(ordered_winners.len()).unwrap_or(0);
    let Some(base) = amount.get().checked_div(count) else {
        return Vec::new();
    };
    let remainder = amount.get().checked_rem(count).unwrap_or(0);
    let mut extra = remainder;
    ordered_winners
        .iter()
        .map(|seat| {
            let bonus = u64::from(extra > 0);
            extra = extra.saturating_sub(1);
            (*seat, Chips::clamped(base.saturating_add(bonus)))
        })
        .collect()
}
