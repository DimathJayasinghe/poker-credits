//! `RoomState` to `RoomView`: the public table state sent in `STATE_UPDATE` and `SNAPSHOT`.
//! It never contains tokens, hashes or anything private.

use poker_engine::{HandStatus, Phase};

use super::state::RoomState;
use crate::protocol::{PotView, RoomView, SeatView, WirePhase};

fn wire_phase(phase: Phase, paused: bool) -> WirePhase {
    if paused {
        return WirePhase::Paused;
    }
    match phase {
        Phase::Lobby => WirePhase::Lobby,
        Phase::PreFlop => WirePhase::PreFlop,
        Phase::Flop => WirePhase::Flop,
        Phase::Turn => WirePhase::Turn,
        Phase::River => WirePhase::River,
        Phase::AllInRunout => WirePhase::AllInRunout,
        Phase::Showdown => WirePhase::Showdown,
        Phase::NextHandPrep => WirePhase::NextHandPrep,
    }
}

impl RoomState {
    /// The public view. `is_connected` tells whether a player id has a live connection (the
    /// state itself does not track connections).
    #[must_use]
    pub fn view(&self, is_connected: &dyn Fn(&str) -> bool) -> RoomView {
        let table = &self.game.table;
        let seats = table
            .seats
            .iter()
            .map(|seat| {
                let id = seat.player_id.as_str();
                SeatView {
                    seat_index: seat.index.get(),
                    player_id: id.to_owned(),
                    name: self
                        .players
                        .get(id)
                        .map_or_else(String::new, |p| p.name.clone()),
                    chips: seat.chips.get(),
                    street_bet: seat.street_bet.get(),
                    has_folded: seat.status == HandStatus::Folded,
                    is_all_in: seat.status == HandStatus::AllIn,
                    is_sitting_out: seat.sitting_out,
                    is_connected: is_connected(id),
                }
            })
            .collect();
        let pots = table
            .pots
            .iter()
            .map(|tier| PotView {
                tier_index: tier.tier_index,
                amount: tier.amount.get(),
                eligible_player_ids: tier
                    .eligible
                    .iter()
                    .filter_map(|index| table.seat(*index))
                    .map(|seat| seat.player_id.to_string())
                    .collect(),
            })
            .collect();
        let min_raise_to = self
            .game
            .legal_actions()
            .map_or(0, |(_, legal)| legal.min_raise_to.get());
        let spectators = self.players.values().filter(|p| p.seat.is_none()).count();
        RoomView {
            room_code: self.code.clone(),
            hand_number: table.hand_number,
            phase: wire_phase(table.phase, table.paused),
            dealer_seat: table.dealer.map(poker_engine::SeatIndex::get),
            small_blind_seat: table.small_blind_seat.map(poker_engine::SeatIndex::get),
            big_blind_seat: table.big_blind_seat.map(poker_engine::SeatIndex::get),
            active_seat: table.active.map(poker_engine::SeatIndex::get),
            current_high_bet: table.current_bet.get(),
            min_raise_to,
            total_pot: table.total_pot().get(),
            pots,
            seats,
            paused: table.paused,
            turn_deadline_ms: self.turn_deadline_ms,
            spectator_count: u32::try_from(spectators).unwrap_or(u32::MAX),
        }
    }
}
