//! Winners of a virtual hand from the hole cards and the board. Pure: the result is the same
//! `Allocation` a host would send, and the engine re-validates it like any other.

use crate::card::Card;
use crate::command::Allocation;
use crate::deal::Deal;
use crate::error::PokerError;
use crate::hand_rank::{HandCategory, HandRank, best_of};
use crate::state::Table;
use crate::types::PlayerId;

/// A revealed hand for the showdown screens.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Reveal {
    /// Whose hand.
    pub player_id: PlayerId,
    /// The two hole cards.
    pub cards: [Card; 2],
    /// What the hand is.
    pub category: HandCategory,
    /// The five cards that make it.
    pub best_five: [Card; 5],
}

fn rank_of(deal: &Deal, player: &PlayerId) -> Result<HandRank, PokerError> {
    let hole = deal.hole_of(player).ok_or(PokerError::UnknownPlayer)?;
    let mut seven = hole.to_vec();
    seven.extend(deal.board);
    best_of(&seven)
}

/// The winners of every pot: the best hand among each pot's eligible players, ties listed
/// together (the engine's odd-chip rule then splits). Pots come in main-pot-first order.
///
/// # Errors
/// [`PokerError::HandNotInProgress`] without a deal; [`PokerError::UnknownPlayer`] if an eligible
/// player was not dealt in.
pub fn allocations(table: &Table) -> Result<Vec<Allocation>, PokerError> {
    let deal = table.deal.as_ref().ok_or(PokerError::HandNotInProgress)?;
    let mut result = Vec::with_capacity(table.pots.len());
    for pot in &table.pots {
        let mut best: Option<HandRank> = None;
        let mut winners: Vec<PlayerId> = Vec::new();
        for index in &pot.eligible {
            let seat = table.seat(*index).ok_or(PokerError::UnknownPlayer)?;
            let rank = rank_of(deal, &seat.player_id)?;
            match best.as_ref().map(|current| rank.cmp(current)) {
                Some(std::cmp::Ordering::Less) => {}
                Some(std::cmp::Ordering::Equal) => winners.push(seat.player_id.clone()),
                _ => {
                    best = Some(rank);
                    winners = vec![seat.player_id.clone()];
                }
            }
        }
        result.push(Allocation {
            pot_index: pot.tier_index,
            winners,
        });
    }
    Ok(result)
}

/// The public hands of every revealed player. Empty without a deal or before a reveal.
#[must_use]
pub fn reveals(table: &Table) -> Vec<Reveal> {
    let Some(deal) = table.deal.as_ref() else {
        return Vec::new();
    };
    deal.revealed
        .iter()
        .filter_map(|player| {
            let cards = deal.hole_of(player)?;
            let rank = rank_of(deal, player).ok()?;
            Some(Reveal {
                player_id: player.clone(),
                cards,
                category: rank.category(),
                best_five: rank.best_five(),
            })
        })
        .collect()
}
