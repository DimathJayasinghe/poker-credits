//! Builds a [`BotView`] from the engine's table. This is the single place that reads a table on
//! behalf of a bot, and it copies out only what the seat is allowed to know: the seat's own hole
//! cards, the shown board and public seat data.

use poker_engine::state::Table;
use poker_engine::validator::legal_actions;
use poker_engine::{Chips, SeatIndex};

use crate::view::{BotView, PublicAction, SeatView};

/// The view for `seat`, or `None` when the seat does not exist or holds no cards.
///
/// `history` is the public betting of the current hand, kept by the caller.
#[must_use]
pub fn view_for_seat(table: &Table, seat: SeatIndex, history: &[PublicAction]) -> Option<BotView> {
    let me = table.seat(seat)?;
    let deal = table.deal.as_ref()?;
    let hole = deal.hole_of(&me.player_id)?;
    let seats = table
        .seats
        .iter()
        .map(|s| SeatView {
            index: s.index,
            player_id: s.player_id.clone(),
            chips: s.chips,
            street_bet: s.street_bet,
            hand_contrib: s.hand_contrib,
            status: s.status,
            sitting_out: s.sitting_out,
        })
        .collect();
    Some(BotView {
        me: seat,
        hole,
        board: deal.visible_board().to_vec(),
        phase: table.phase,
        pot_total: table.total_pot(),
        seats,
        button: table.dealer,
        to_call: table.current_bet.saturating_sub(me.street_bet),
        legal: legal_actions(table, me),
        blinds: table.hand_blinds,
        hand_number: table.hand_number,
        history: history.to_vec(),
    })
}

/// Chips as a plain number for strategy arithmetic.
#[must_use]
pub fn num(chips: Chips) -> f32 {
    #[allow(
        clippy::cast_precision_loss,
        reason = "chip counts stay far below 2^24 in play; the ratio is what matters"
    )]
    {
        chips.get() as f32
    }
}
