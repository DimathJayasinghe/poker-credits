//! `RoomState` to `RoomView`: the public table state sent in `STATE_UPDATE` and `SNAPSHOT`.
//! It never contains tokens, hashes or anything private.

use poker_engine::{HandStatus, Phase};

use super::state::RoomState;
use crate::protocol::{
    FinishView, HandResultView, PendingRebuyView, PotResultView, PotView, RevealView, RoomView,
    SeatView, ShareView, WirePhase,
};

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
                    has_cards: self.holds_cards(id, seat.status),
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
            pending_rebuys: self
                .pending_rebuys
                .iter()
                .map(|r| PendingRebuyView {
                    player_id: r.player_id.clone(),
                    amount: r.amount,
                    approved: r.approved,
                })
                .collect(),
            board: table
                .deal
                .as_ref()
                .map_or_else(Vec::new, |deal| deal.visible_board().to_vec()),
            reveals: self.reveal_views(),
            result: self.result_view(),
            finish_order: self
                .finish_order
                .iter()
                .map(|entry| FinishView {
                    player_id: entry.player_id.clone(),
                    name: entry.name.clone(),
                    place: entry.place,
                })
                .collect(),
        }
    }

    /// Whether this seat still holds face-down cards in the hand being played. It says nothing
    /// about which cards.
    fn holds_cards(&self, id: &str, status: HandStatus) -> bool {
        let table = &self.game.table;
        let playing =
            table.phase.is_betting() || matches!(table.phase, Phase::AllInRunout | Phase::Showdown);
        playing
            && matches!(status, HandStatus::Live | HandStatus::AllIn)
            && table
                .deal
                .as_ref()
                .is_some_and(|deal| deal.hole_of(&super::state::engine_id(id)).is_some())
    }

    fn hand_name(&self, id: &str) -> String {
        self.hand_names
            .get(id)
            .or_else(|| self.players.get(id).map(|p| &p.name))
            .cloned()
            .unwrap_or_default()
    }

    /// Hands every contender has had to show, in seat order of the deal.
    fn reveal_views(&self) -> Vec<RevealView> {
        poker_engine::showdown::reveals(&self.game.table)
            .into_iter()
            .map(|reveal| RevealView {
                name: self.hand_name(reveal.player_id.as_str()),
                player_id: reveal.player_id.to_string(),
                cards: reveal.cards,
                category: reveal.category,
                best_five: reveal.best_five,
            })
            .collect()
    }

    /// How the last hand was paid, main pot first.
    fn result_view(&self) -> Option<HandResultView> {
        let result = self.game.table.deal.as_ref()?.result.as_ref()?;
        let mut pots: Vec<PotResultView> = result
            .pots
            .iter()
            .map(|pot| PotResultView {
                pot_index: pot.pot_index,
                amount: pot.amount.get(),
                winner_player_ids: pot.winners.iter().map(ToString::to_string).collect(),
                shares: pot
                    .shares
                    .iter()
                    .map(|(id, amount)| ShareView {
                        name: self.hand_name(id.as_str()),
                        player_id: id.to_string(),
                        amount: amount.get(),
                    })
                    .collect(),
            })
            .collect();
        pots.sort_by_key(|pot| pot.pot_index);
        Some(HandResultView {
            uncontested: result.uncontested,
            pots,
        })
    }
}
