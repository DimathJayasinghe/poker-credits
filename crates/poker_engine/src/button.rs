//! Dealer button, blind positions, dead button and heads-up.
//!
//! Rule (documented in `GAME_LOGIC_AND_RULES.md`): the big blind moves to the next player who can
//! be dealt in every hand, so nobody skips it. The small blind is the seat just before the big
//! blind and the button the seat before that. If the small blind seat cannot be dealt in the
//! small blind is dead (nobody posts it); if the button seat cannot be dealt in the button is
//! dead (it still marks where action starts after the flop). Heads-up the button posts the small
//! blind.

use crate::error::PokerError;
use crate::state::{Seat, Table};
use crate::types::SeatIndex;

/// Where everybody sits for the next hand.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Positions {
    /// Button seat (possibly dead).
    pub dealer: SeatIndex,
    /// Small blind seat, `None` when the small blind is dead.
    pub small_blind: Option<SeatIndex>,
    /// Big blind seat.
    pub big_blind: SeatIndex,
}

fn next_eligible_after(table: &Table, from: SeatIndex) -> Option<SeatIndex> {
    table
        .seats_after(from)
        .find(|seat| seat.is_eligible())
        .map(|seat| seat.index)
}

/// The seat just before `index` going counter-clockwise, wrapping around the table.
fn previous_seat(table: &Table, index: SeatIndex) -> Option<&Seat> {
    table
        .seats
        .iter()
        .rev()
        .find(|seat| seat.index < index)
        .or_else(|| table.seats.last())
}

/// Works out button and blinds for the next hand.
///
/// # Errors
/// [`PokerError::NotEnoughPlayers`] unless at least two seats can be dealt in.
pub fn next_positions(table: &Table) -> Result<Positions, PokerError> {
    let eligible: Vec<SeatIndex> = table
        .seats
        .iter()
        .filter(|seat| seat.is_eligible())
        .map(|seat| seat.index)
        .collect();
    let (Some(first), true) = (eligible.first().copied(), eligible.len() >= 2) else {
        return Err(PokerError::NotEnoughPlayers);
    };

    let Some(last_big_blind) = table.big_blind_seat else {
        return first_hand(table, first, eligible.len());
    };

    let big_blind =
        next_eligible_after(table, last_big_blind).ok_or(PokerError::NotEnoughPlayers)?;
    if eligible.len() == 2 {
        let small_blind = eligible.iter().copied().find(|seat| *seat != big_blind);
        return match small_blind {
            Some(seat) => Ok(Positions {
                dealer: seat,
                small_blind: Some(seat),
                big_blind,
            }),
            None => Err(PokerError::NotEnoughPlayers),
        };
    }

    let small_candidate = previous_seat(table, big_blind).ok_or(PokerError::NotEnoughPlayers)?;
    let dealer = previous_seat(table, small_candidate.index)
        .ok_or(PokerError::NotEnoughPlayers)?
        .index;
    Ok(Positions {
        dealer,
        small_blind: small_candidate
            .is_eligible()
            .then_some(small_candidate.index),
        big_blind,
    })
}

fn first_hand(table: &Table, dealer: SeatIndex, eligible: usize) -> Result<Positions, PokerError> {
    if eligible == 2 {
        let big_blind = next_eligible_after(table, dealer).ok_or(PokerError::NotEnoughPlayers)?;
        return Ok(Positions {
            dealer,
            small_blind: Some(dealer),
            big_blind,
        });
    }
    let small_blind = next_eligible_after(table, dealer).ok_or(PokerError::NotEnoughPlayers)?;
    let big_blind = next_eligible_after(table, small_blind).ok_or(PokerError::NotEnoughPlayers)?;
    Ok(Positions {
        dealer,
        small_blind: Some(small_blind),
        big_blind,
    })
}
