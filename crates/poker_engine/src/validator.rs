//! What a seat may do, and how an action turns into chips moved.
//!
//! The minimum raise increment and the "betting reopened" test live here so the server can show
//! `TURN_PROMPT.legal` and the machine can enforce it from the same code.

use std::cmp::Ordering;

use serde::{Deserialize, Serialize};

use crate::command::PlayerAction;
use crate::error::PokerError;
use crate::event::ActionKind;
use crate::state::{Seat, Table};
use crate::types::Chips;

/// Mirrors `TURN_PROMPT.legal` field for field.
#[allow(
    clippy::struct_excessive_bools,
    reason = "mirrors the wire message `legal` object"
)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LegalActions {
    /// Folding is always possible.
    pub can_fold: bool,
    /// Nothing is owed.
    pub can_check: bool,
    /// Something is owed.
    pub can_call: bool,
    /// Chips the call costs (capped at the stack).
    pub call_amount: Chips,
    /// A bet or raise is allowed (including an all-in over the bet).
    pub can_raise: bool,
    /// Smallest legal raise-to total, capped at the stack (zero when `can_raise` is false).
    pub min_raise_to: Chips,
    /// Largest raise-to total, the whole stack (zero when `can_raise` is false).
    pub max_raise_to: Chips,
}

/// An action turned into numbers, ready to apply.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Resolved {
    /// What to show in the ticker.
    pub kind: ActionKind,
    /// Chips leaving the stack.
    pub add: Chips,
    /// Street total of the seat afterwards.
    pub new_street_bet: Chips,
    /// The stack is empty afterwards.
    pub all_in: bool,
    /// A full bet or raise: it resets the raise increment and reopens betting.
    pub full_raise: bool,
}

fn to_call(table: &Table, seat: &Seat) -> Chips {
    table.current_bet.saturating_sub(seat.street_bet)
}

fn stack_total(seat: &Seat) -> Chips {
    seat.street_bet.saturating_add(seat.chips)
}

/// A seat may raise only if a full raise happened since it last acted. A short all-in does not
/// bump the raise count, so it does not reopen betting for players who already acted.
fn raise_reopened(table: &Table, seat: &Seat) -> bool {
    seat.acted_at_raise
        .is_none_or(|seen| seen < table.raise_count)
}

fn full_min_raise_to(table: &Table) -> Chips {
    table.current_bet.saturating_add(table.last_raise_delta)
}

fn bet_or_raise(table: &Table) -> ActionKind {
    if table.current_bet.is_zero() {
        ActionKind::Bet
    } else {
        ActionKind::Raise
    }
}

/// The options for `seat` right now.
#[must_use]
pub fn legal_actions(table: &Table, seat: &Seat) -> LegalActions {
    let owed = to_call(table, seat);
    let total = stack_total(seat);
    let can_raise = raise_reopened(table, seat) && total > table.current_bet;
    LegalActions {
        can_fold: true,
        can_check: owed.is_zero(),
        can_call: !owed.is_zero(),
        call_amount: owed.min(seat.chips),
        can_raise,
        min_raise_to: if can_raise {
            full_min_raise_to(table).min(total)
        } else {
            Chips::ZERO
        },
        max_raise_to: if can_raise { total } else { Chips::ZERO },
    }
}

fn call_resolved(seat: &Seat, owed: Chips) -> Resolved {
    let add = owed.min(seat.chips);
    Resolved {
        kind: ActionKind::Call,
        add,
        new_street_bet: seat.street_bet.saturating_add(add),
        all_in: add == seat.chips,
        full_raise: false,
    }
}

fn all_in_or_raise(table: &Table, seat: &Seat) -> Result<Resolved, PokerError> {
    let total = stack_total(seat);
    if total <= table.current_bet {
        return Ok(call_resolved(seat, seat.chips));
    }
    if !raise_reopened(table, seat) {
        return Err(PokerError::BettingNotReopened);
    }
    Ok(Resolved {
        kind: bet_or_raise(table),
        add: seat.chips,
        new_street_bet: total,
        all_in: true,
        full_raise: total >= full_min_raise_to(table),
    })
}

fn raise_to(table: &Table, seat: &Seat, to_amount: Chips) -> Result<Resolved, PokerError> {
    if !raise_reopened(table, seat) {
        return Err(PokerError::BettingNotReopened);
    }
    let min = full_min_raise_to(table);
    if to_amount < min {
        return Err(PokerError::BelowMinRaise {
            min_raise_to: min.min(stack_total(seat)),
        });
    }
    Ok(Resolved {
        kind: bet_or_raise(table),
        add: to_amount.saturating_sub(seat.street_bet),
        new_street_bet: to_amount,
        all_in: false,
        full_raise: true,
    })
}

/// Checks `action` against the rules and computes its effect. Nothing is changed.
///
/// # Errors
/// [`PokerError::CannotCheck`], [`PokerError::NothingToCall`], [`PokerError::BelowMinRaise`],
/// [`PokerError::BettingNotReopened`] or [`PokerError::InsufficientFunds`] when the action is
/// illegal for this seat.
pub fn resolve(table: &Table, seat: &Seat, action: PlayerAction) -> Result<Resolved, PokerError> {
    let owed = to_call(table, seat);
    match action {
        PlayerAction::Fold => Ok(Resolved {
            kind: ActionKind::Fold,
            add: Chips::ZERO,
            new_street_bet: seat.street_bet,
            all_in: false,
            full_raise: false,
        }),
        PlayerAction::Check if owed.is_zero() => Ok(Resolved {
            kind: ActionKind::Check,
            add: Chips::ZERO,
            new_street_bet: seat.street_bet,
            all_in: false,
            full_raise: false,
        }),
        PlayerAction::Check => Err(PokerError::CannotCheck),
        PlayerAction::Call if owed.is_zero() => Err(PokerError::NothingToCall),
        PlayerAction::Call => Ok(call_resolved(seat, owed)),
        PlayerAction::AllIn => all_in_or_raise(table, seat),
        PlayerAction::Raise { to_amount } => {
            let total = stack_total(seat);
            match to_amount.cmp(&total) {
                Ordering::Greater => Err(PokerError::InsufficientFunds { max_to: total }),
                Ordering::Equal => all_in_or_raise(table, seat),
                Ordering::Less => raise_to(table, seat, to_amount),
            }
        }
    }
}
