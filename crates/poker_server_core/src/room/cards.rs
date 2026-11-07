//! Virtual-card behaviour of a room: who may see which cards, and the server-made showdown.
//!
//! Everything here is a pure function of [`RoomState`]; the shuffle itself is drawn by the actor
//! and arrives inside the journaled `StartHand` (see ADR-016).

use poker_engine::Phase;
use poker_engine::showdown;

use super::state::{Op, RoomError, RoomState, engine_id};
use crate::protocol::{CardMode, ServerMessage};

impl RoomState {
    /// Whether this room deals and ranks cards itself.
    #[must_use]
    pub fn is_virtual(&self) -> bool {
        self.config.card_mode == CardMode::Virtual
    }

    /// The private `HOLE_CARDS` message for one participant: their own two cards of the current
    /// (or just finished) deal, `None` for spectators, late joiners and physical rooms.
    #[must_use]
    pub fn hole_cards_for(&self, player_id: &str) -> Option<ServerMessage> {
        let deal = self.game.table.deal.as_ref()?;
        let cards = deal.hole_of(&engine_id(player_id))?;
        Some(ServerMessage::HoleCards {
            hand_number: deal.hand_number,
            cards,
        })
    }

    /// Betting is over in a virtual room and the server has to run the showdown itself: the
    /// all-in run-out or the showdown is waiting and nothing is holding the game.
    #[must_use]
    pub fn needs_auto_showdown(&self) -> bool {
        let table = &self.game.table;
        self.is_virtual()
            && !self.ended
            && !table.paused
            && table.deal.is_some()
            && matches!(table.phase, Phase::AllInRunout | Phase::Showdown)
    }

    /// The journaled op that ends the hand, if one is due. Computed from the table alone, so the
    /// same table always gets the same payout.
    ///
    /// # Errors
    /// A [`RoomError`] if the showdown cannot be ranked (it should never happen).
    pub fn auto_showdown_op(&self, at_ms: u64) -> Result<Option<Op>, RoomError> {
        if !self.needs_auto_showdown() {
            return Ok(None);
        }
        let allocations = showdown::allocations(&self.game.table)?;
        Ok(Some(Op::AutoShowdown { allocations, at_ms }))
    }
}
