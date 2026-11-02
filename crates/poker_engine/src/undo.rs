//! Five-deep undo. The history is part of the serialised [`GameState`], so a room restored from a
//! snapshot can still undo exactly as the live room could.

use crate::error::PokerError;
use crate::event::Event;
use crate::state::{GameState, Table};

/// How many steps the host can take back.
pub const UNDO_DEPTH: usize = 5;

/// Remembers `before` as the state to return to, dropping the oldest entry when full.
pub fn record(state: &mut GameState, before: Table) {
    state.history.push(before);
    if state.history.len() > UNDO_DEPTH {
        state.history.remove(0);
    }
}

/// Restores the previous table.
///
/// The pause flag and every seat's sit-out flag are kept as they are now: undoing while paused (the
/// usual way to settle a dispute) must not silently unpause the game, and a player's request to
/// sit out the next hand must survive the host taking back an action.
///
/// # Errors
/// [`PokerError::NothingToUndo`] when the history is empty.
pub fn undo(state: &mut GameState, events: &mut Vec<Event>) -> Result<(), PokerError> {
    let mut previous = state.history.pop().ok_or(PokerError::NothingToUndo)?;
    previous.paused = state.table.paused && previous.phase.is_betting();
    for seat in &mut previous.seats {
        if let Some(current) = state.table.seat_of(&seat.player_id) {
            seat.sitting_out = current.sitting_out;
        }
    }
    state.table = previous;
    events.push(Event::UndoApplied);
    Ok(())
}
