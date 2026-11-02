//! The state machine: `apply(&GameState, Command) -> Result<Transition, PokerError>`.
//!
//! The old state is never touched. Phase changes go through [`allowed`], a table, so an illegal
//! jump is a `PokerError::IllegalTransition` and not a latent bug.

use std::collections::BTreeMap;

use crate::MAX_CHIPS;
use crate::blinds::BlindsStrategy;
use crate::button;
use crate::command::{Allocation, Command, PlayerAction};
use crate::error::{AllocationError, PokerError};
use crate::event::{ActionKind, BlindKind, Event};
use crate::pots::{self, Contribution};
use crate::state::{AWAY_AFTER_MISSED_TURNS, GameState, HandStatus, Seat, Table};
use crate::types::{Chips, MAX_SEATS, Phase, PlayerId, SeatIndex};
use crate::undo;
use crate::validator::{self, Resolved};

/// The result of one command.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Transition {
    /// State after the command.
    pub state: GameState,
    /// What happened, in order.
    pub events: Vec<Event>,
}

/// Whether the phase may change from `from` to `to`.
#[must_use]
pub fn allowed(from: Phase, to: Phase) -> bool {
    use Phase::{AllInRunout, Flop, Lobby, NextHandPrep, PreFlop, River, Showdown, Turn};
    match from {
        Lobby => matches!(to, PreFlop),
        NextHandPrep => matches!(to, PreFlop | Lobby),
        PreFlop => matches!(to, Flop | AllInRunout | NextHandPrep | Lobby),
        Flop => matches!(to, Turn | AllInRunout | NextHandPrep | Lobby),
        Turn => matches!(to, River | AllInRunout | NextHandPrep | Lobby),
        River => matches!(to, Showdown | NextHandPrep | Lobby),
        AllInRunout => matches!(to, Showdown),
        Showdown => matches!(to, NextHandPrep | Lobby),
    }
}

/// How a command affects the undo history.
enum HistoryEffect {
    /// Remember the state before the command.
    Record,
    /// Seating or money changed; older states would be inconsistent.
    Clear,
    /// Leave it alone.
    Keep,
}

fn history_effect(command: &Command) -> HistoryEffect {
    match command {
        Command::Action { .. }
        | Command::Timeout { .. }
        | Command::LeaveHand { .. }
        | Command::StartHand { .. }
        | Command::BeginShowdown
        | Command::ResolveShowdown { .. } => HistoryEffect::Record,
        Command::AddPlayer { .. }
        | Command::RemovePlayer { .. }
        | Command::Rebuy { .. }
        | Command::Configure { .. } => HistoryEffect::Clear,
        Command::SetSittingOut { .. } | Command::Pause | Command::Resume | Command::Undo => {
            HistoryEffect::Keep
        }
    }
}

/// Applies one command.
///
/// # Errors
/// A [`PokerError`] describing why the command is illegal; the input state is unchanged.
pub fn apply(state: &GameState, command: Command) -> Result<Transition, PokerError> {
    let mut next = state.clone();
    let mut events = Vec::new();
    if matches!(command, Command::Undo) {
        undo::undo(&mut next, &mut events)?;
    } else {
        let effect = history_effect(&command);
        run(&mut next.table, command, &mut events)?;
        match effect {
            HistoryEffect::Record => undo::record(&mut next, state.table.clone()),
            HistoryEffect::Clear => next.history.clear(),
            HistoryEffect::Keep => {}
        }
    }
    Ok(Transition {
        state: next,
        events,
    })
}

fn run(table: &mut Table, command: Command, events: &mut Vec<Event>) -> Result<(), PokerError> {
    match command {
        Command::Action { player_id, action } => {
            player_action(table, &player_id, action, false, events)
        }
        Command::Timeout { player_id } => timeout(table, &player_id, events),
        Command::LeaveHand { player_id } => leave_hand(table, &player_id, events),
        Command::AddPlayer {
            player_id,
            seat,
            chips,
        } => add_player(table, player_id, seat, chips, events),
        Command::RemovePlayer { player_id } => remove_player(table, &player_id, events),
        Command::SetSittingOut {
            player_id,
            sitting_out,
        } => set_sitting_out(table, &player_id, sitting_out, events),
        Command::Rebuy { player_id, amount } => rebuy(table, &player_id, amount, events),
        Command::Configure { blinds } => {
            require_between_hands(table)?;
            blinds.validate()?;
            table.blinds = blinds;
            events.push(Event::BlindsConfigured);
            Ok(())
        }
        Command::StartHand { elapsed_ms } => start_hand(table, elapsed_ms, events),
        Command::BeginShowdown => begin_showdown(table, events),
        Command::ResolveShowdown { allocations } => resolve_showdown(table, &allocations, events),
        Command::Pause => pause(table, events),
        Command::Resume => resume(table, events),
        Command::Undo => Err(PokerError::NothingToUndo),
    }
}

// ---------------------------------------------------------------------------------------------
// Table management
// ---------------------------------------------------------------------------------------------

fn require_between_hands(table: &Table) -> Result<(), PokerError> {
    if matches!(table.phase, Phase::Lobby | Phase::NextHandPrep) {
        Ok(())
    } else {
        Err(PokerError::HandInProgress)
    }
}

fn add_player(
    table: &mut Table,
    player_id: PlayerId,
    seat: SeatIndex,
    chips: Chips,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    if chips.is_zero() || chips.get() > MAX_CHIPS {
        return Err(PokerError::InvalidAmount);
    }
    if table.seat_of(&player_id).is_some() {
        return Err(PokerError::PlayerExists);
    }
    if table.seat(seat).is_some() {
        return Err(PokerError::SeatOccupied);
    }
    if table.seats.len() >= usize::from(MAX_SEATS) {
        return Err(PokerError::SeatOccupied);
    }
    table.seats.push(Seat::new(seat, player_id.clone(), chips));
    table.seats.sort_unstable_by_key(|s| s.index);
    events.push(Event::PlayerAdded { player_id, seat });
    Ok(())
}

fn remove_player(
    table: &mut Table,
    player_id: &PlayerId,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table.seat_of(player_id).ok_or(PokerError::UnknownPlayer)?;
    if seat.status != HandStatus::Out {
        return Err(PokerError::HandInProgress);
    }
    let chips = seat.chips;
    table.seats.retain(|s| &s.player_id != player_id);
    events.push(Event::PlayerRemoved {
        player_id: player_id.clone(),
        chips,
    });
    Ok(())
}

fn set_sitting_out(
    table: &mut Table,
    player_id: &PlayerId,
    sitting_out: bool,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table
        .seats
        .iter_mut()
        .find(|s| &s.player_id == player_id)
        .ok_or(PokerError::UnknownPlayer)?;
    seat.sitting_out = sitting_out;
    if !sitting_out {
        seat.missed_turns = 0;
    }
    events.push(Event::SittingOutChanged {
        player_id: player_id.clone(),
        sitting_out,
    });
    Ok(())
}

fn rebuy(
    table: &mut Table,
    player_id: &PlayerId,
    amount: Chips,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    require_between_hands(table)?;
    if amount.is_zero() {
        return Err(PokerError::InvalidAmount);
    }
    let seat = table
        .seats
        .iter_mut()
        .find(|s| &s.player_id == player_id)
        .ok_or(PokerError::UnknownPlayer)?;
    let stack = seat.chips.checked_add(amount)?;
    if stack.get() > MAX_CHIPS {
        return Err(PokerError::InvalidAmount);
    }
    seat.chips = stack;
    events.push(Event::RebuyApplied {
        player_id: player_id.clone(),
        amount,
    });
    Ok(())
}

fn pause(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    if !table.phase.is_betting() {
        return Err(PokerError::HandNotInProgress);
    }
    if table.paused {
        return Err(PokerError::GamePaused);
    }
    table.paused = true;
    events.push(Event::Paused);
    Ok(())
}

fn resume(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    if !table.paused {
        return Err(PokerError::NotPaused);
    }
    table.paused = false;
    events.push(Event::Resumed);
    Ok(())
}

fn change_phase(table: &mut Table, to: Phase, events: &mut Vec<Event>) -> Result<(), PokerError> {
    if !allowed(table.phase, to) {
        return Err(PokerError::IllegalTransition {
            from: table.phase,
            to,
        });
    }
    table.phase = to;
    events.push(Event::PhaseChanged { phase: to });
    Ok(())
}

// ---------------------------------------------------------------------------------------------
// Starting a hand
// ---------------------------------------------------------------------------------------------

fn post(seat: &mut Seat, wanted: Chips, to_street: bool) -> Result<Chips, PokerError> {
    let paid = wanted.min(seat.chips);
    seat.chips = seat.chips.checked_sub(paid)?;
    seat.hand_contrib = seat.hand_contrib.checked_add(paid)?;
    if to_street {
        seat.street_bet = seat.street_bet.checked_add(paid)?;
    }
    if seat.chips.is_zero() {
        seat.status = HandStatus::AllIn;
    }
    Ok(paid)
}

fn post_blind(
    table: &mut Table,
    at: SeatIndex,
    wanted: Chips,
    blind: BlindKind,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table.seat_mut(at).ok_or(PokerError::UnknownPlayer)?;
    let amount = post(seat, wanted, blind != BlindKind::Ante)?;
    events.push(Event::BlindPosted {
        player_id: seat.player_id.clone(),
        blind,
        amount,
    });
    Ok(())
}

fn start_hand(
    table: &mut Table,
    elapsed_ms: u64,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    require_between_hands(table)?;
    let positions = button::next_positions(table)?;
    let blinds = table
        .blinds
        .blinds(table.hand_number.saturating_add(1), elapsed_ms);

    for seat in &mut table.seats {
        seat.street_bet = Chips::ZERO;
        seat.hand_contrib = Chips::ZERO;
        seat.acted_at_raise = None;
        seat.status = if seat.is_eligible() {
            HandStatus::Live
        } else {
            HandStatus::Out
        };
    }
    table.hand_number = table.hand_number.saturating_add(1);
    table.hand_blinds = blinds;
    table.dealer = Some(positions.dealer);
    table.small_blind_seat = positions.small_blind;
    table.big_blind_seat = Some(positions.big_blind);
    table.pots.clear();
    table.paused = false;
    change_phase(table, Phase::PreFlop, events)?;
    events.push(Event::HandStarted {
        hand_number: table.hand_number,
        dealer: positions.dealer,
        small_blind: positions.small_blind,
        big_blind: positions.big_blind,
    });

    if !blinds.ante.is_zero() {
        let dealt_in: Vec<SeatIndex> = table
            .seats
            .iter()
            .filter(|s| s.status == HandStatus::Live)
            .map(|s| s.index)
            .collect();
        for index in dealt_in {
            post_blind(table, index, blinds.ante, BlindKind::Ante, events)?;
        }
    }
    if let Some(small_blind) = positions.small_blind {
        post_blind(
            table,
            small_blind,
            blinds.small_blind,
            BlindKind::SmallBlind,
            events,
        )?;
    }
    post_blind(
        table,
        positions.big_blind,
        blinds.big_blind,
        BlindKind::BigBlind,
        events,
    )?;

    table.current_bet = blinds.big_blind;
    table.last_raise_delta = blinds.big_blind;
    table.raise_count = 0;
    table.short_raise_total = Chips::ZERO;
    after_betting_change(table, positions.big_blind, events)
}

// ---------------------------------------------------------------------------------------------
// Betting
// ---------------------------------------------------------------------------------------------

fn timeout(
    table: &mut Table,
    player_id: &PlayerId,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table.seat_of(player_id).ok_or(PokerError::UnknownPlayer)?;
    let action = if table.current_bet > seat.street_bet {
        PlayerAction::Fold
    } else {
        PlayerAction::Check
    };
    let index = seat.index;
    if table.active == Some(index)
        && let Some(seat) = table.seat_mut(index)
    {
        seat.missed_turns = seat.missed_turns.saturating_add(1);
    }
    player_action(table, player_id, action, true, events)
}

fn leave_hand(
    table: &mut Table,
    player_id: &PlayerId,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table.seat_of(player_id).ok_or(PokerError::UnknownPlayer)?;
    let index = seat.index;
    let must_fold = table.phase.is_betting() && seat.status == HandStatus::Live;
    if must_fold && table.paused {
        return Err(PokerError::GamePaused);
    }
    let was_sitting_out = seat.sitting_out;
    let seat = table.seat_mut(index).ok_or(PokerError::UnknownPlayer)?;
    seat.sitting_out = true;
    if !was_sitting_out {
        events.push(Event::SittingOutChanged {
            player_id: player_id.clone(),
            sitting_out: true,
        });
    }
    if !must_fold {
        return Ok(());
    }
    let seat = table.seat(index).ok_or(PokerError::UnknownPlayer)?;
    let resolved = validator::resolve(table, seat, PlayerAction::Fold)?;
    apply_resolved(table, index, &resolved, true, events)?;
    if table.active == Some(index) {
        after_betting_change(table, index, events)
    } else if table.contesting_count() <= 1 {
        finish_uncontested(table, events)
    } else {
        Ok(())
    }
}

fn player_action(
    table: &mut Table,
    player_id: &PlayerId,
    action: PlayerAction,
    auto: bool,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    if table.paused {
        return Err(PokerError::GamePaused);
    }
    if !table.phase.is_betting() {
        return Err(PokerError::HandNotInProgress);
    }
    let seat = table.seat_of(player_id).ok_or(PokerError::UnknownPlayer)?;
    let index = seat.index;
    if table.active != Some(index) {
        return Err(PokerError::NotYourTurn);
    }
    let resolved = validator::resolve(table, seat, action)?;
    if !auto && let Some(seat) = table.seat_mut(index) {
        seat.missed_turns = 0;
    }
    apply_resolved(table, index, &resolved, auto, events)?;
    after_betting_change(table, index, events)
}

fn apply_resolved(
    table: &mut Table,
    index: SeatIndex,
    resolved: &Resolved,
    auto: bool,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let previous_bet = table.current_bet;
    if resolved.new_street_bet > previous_bet {
        let increase = resolved.new_street_bet.saturating_sub(previous_bet);
        if resolved.full_raise {
            table.last_raise_delta = increase;
            table.raise_count = table.raise_count.saturating_add(1);
            table.short_raise_total = Chips::ZERO;
        } else {
            // TDA rule 47: short all-ins that together reach a full raise reopen betting, but the
            // minimum raise increment stays that of the last full raise.
            table.short_raise_total = table.short_raise_total.saturating_add(increase);
            if table.short_raise_total >= table.last_raise_delta {
                table.raise_count = table.raise_count.saturating_add(1);
                table.short_raise_total = Chips::ZERO;
            }
        }
        table.current_bet = resolved.new_street_bet;
    }
    let raise_count = table.raise_count;
    let seat = table.seat_mut(index).ok_or(PokerError::UnknownPlayer)?;
    if resolved.kind == ActionKind::Fold {
        seat.status = HandStatus::Folded;
    } else {
        seat.chips = seat.chips.checked_sub(resolved.add)?;
        seat.street_bet = seat.street_bet.checked_add(resolved.add)?;
        seat.hand_contrib = seat.hand_contrib.checked_add(resolved.add)?;
        if seat.chips.is_zero() {
            seat.status = HandStatus::AllIn;
        }
    }
    seat.acted_at_raise = Some(raise_count);
    events.push(Event::ActionPerformed {
        player_id: seat.player_id.clone(),
        action: resolved.kind,
        amount: resolved.add,
        street_total: seat.street_bet,
        chips_remaining: seat.chips,
        all_in: resolved.all_in,
        auto,
    });
    Ok(())
}

fn round_complete(table: &Table) -> bool {
    let actors: Vec<&Seat> = table
        .seats
        .iter()
        .filter(|s| s.status == HandStatus::Live)
        .collect();
    match actors.as_slice() {
        [] => true,
        // A lone player with chips has nobody to bet against once the rest are all-in.
        [only] if only.street_bet >= table.current_bet => true,
        _ => actors
            .iter()
            .all(|s| s.acted_at_raise.is_some() && s.street_bet >= table.current_bet),
    }
}

fn after_betting_change(
    table: &mut Table,
    from: SeatIndex,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    if table.contesting_count() <= 1 {
        return finish_uncontested(table, events);
    }
    if round_complete(table) {
        return close_street(table, events);
    }
    let current_bet = table.current_bet;
    let next = table
        .seats_after(from)
        .find(|s| s.needs_action(current_bet))
        .map(|s| (s.index, s.player_id.clone()));
    match next {
        Some((seat, player_id)) => {
            table.active = Some(seat);
            events.push(Event::TurnStarted { seat, player_id });
            Ok(())
        }
        None => close_street(table, events),
    }
}

fn close_street(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    table.active = None;
    let actors = table
        .seats
        .iter()
        .filter(|s| s.status == HandStatus::Live)
        .count();
    match table.phase {
        Phase::River => enter_showdown(table, events),
        _ if actors <= 1 => enter_runout(table, events),
        Phase::PreFlop => next_street(table, Phase::Flop, events),
        Phase::Flop => next_street(table, Phase::Turn, events),
        Phase::Turn => next_street(table, Phase::River, events),
        Phase::Lobby | Phase::AllInRunout | Phase::Showdown | Phase::NextHandPrep => {
            Err(PokerError::HandNotInProgress)
        }
    }
}

fn next_street(table: &mut Table, to: Phase, events: &mut Vec<Event>) -> Result<(), PokerError> {
    change_phase(table, to, events)?;
    for seat in &mut table.seats {
        seat.street_bet = Chips::ZERO;
        seat.acted_at_raise = None;
    }
    table.current_bet = Chips::ZERO;
    table.last_raise_delta = table.hand_blinds.big_blind;
    table.raise_count = 0;
    table.short_raise_total = Chips::ZERO;
    let dealer = table.dealer.ok_or(PokerError::HandNotInProgress)?;
    let first = table
        .seats_after(dealer)
        .find(|s| s.status == HandStatus::Live)
        .map(|s| (s.index, s.player_id.clone()));
    match first {
        Some((seat, player_id)) => {
            table.active = Some(seat);
            events.push(Event::TurnStarted { seat, player_id });
            Ok(())
        }
        None => enter_runout(table, events),
    }
}

// ---------------------------------------------------------------------------------------------
// Pots, showdown and payout
// ---------------------------------------------------------------------------------------------

fn contributions(table: &Table) -> Vec<Contribution> {
    table
        .seats
        .iter()
        .filter(|s| !s.hand_contrib.is_zero())
        .map(|s| Contribution {
            seat: s.index,
            amount: s.hand_contrib,
            folded: s.status == HandStatus::Folded,
        })
        .collect()
}

/// Returns the uncalled bet and fixes the pots. Betting is over for this hand.
fn settle(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    if let Some((index, amount)) = pots::uncalled_refund(&contributions(table)) {
        let seat = table.seat_mut(index).ok_or(PokerError::UnknownPlayer)?;
        seat.hand_contrib = seat.hand_contrib.checked_sub(amount)?;
        seat.chips = seat.chips.checked_add(amount)?;
        events.push(Event::UncalledReturned {
            player_id: seat.player_id.clone(),
            amount,
        });
    }
    table.pots = pots::calculate(&contributions(table));
    table.active = None;
    Ok(())
}

fn enter_runout(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    settle(table, events)?;
    change_phase(table, Phase::AllInRunout, events)?;
    events.push(Event::RunoutStarted {
        pots: table.pots.clone(),
    });
    Ok(())
}

fn enter_showdown(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    settle(table, events)?;
    change_phase(table, Phase::Showdown, events)?;
    events.push(Event::ShowdownStarted {
        pots: table.pots.clone(),
    });
    Ok(())
}

fn begin_showdown(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    if table.phase != Phase::AllInRunout {
        return Err(PokerError::IllegalTransition {
            from: table.phase,
            to: Phase::Showdown,
        });
    }
    change_phase(table, Phase::Showdown, events)?;
    events.push(Event::ShowdownStarted {
        pots: table.pots.clone(),
    });
    Ok(())
}

fn finish_uncontested(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    settle(table, events)?;
    let winner = table
        .seats
        .iter()
        .find(|s| s.is_contesting())
        .map(|s| s.index);
    let pots = std::mem::take(&mut table.pots);
    if let Some(winner) = winner {
        for pot in &pots {
            pay(table, pot.tier_index, winner, pot.amount, events)?;
        }
    }
    end_hand(table, events)
}

fn pay(
    table: &mut Table,
    pot_index: u32,
    to: SeatIndex,
    amount: Chips,
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    let seat = table.seat_mut(to).ok_or(PokerError::UnknownPlayer)?;
    seat.chips = seat.chips.checked_add(amount)?;
    events.push(Event::PotAwarded {
        pot_index,
        player_id: seat.player_id.clone(),
        amount,
    });
    Ok(())
}

fn end_hand(table: &mut Table, events: &mut Vec<Event>) -> Result<(), PokerError> {
    for seat in &mut table.seats {
        seat.street_bet = Chips::ZERO;
        seat.hand_contrib = Chips::ZERO;
        seat.status = HandStatus::Out;
        seat.acted_at_raise = None;
        if seat.missed_turns >= AWAY_AFTER_MISSED_TURNS && !seat.sitting_out {
            seat.sitting_out = true;
            seat.missed_turns = 0;
            events.push(Event::PlayerAway {
                player_id: seat.player_id.clone(),
            });
        }
    }
    table.active = None;
    table.paused = false;
    table.current_bet = Chips::ZERO;
    table.last_raise_delta = Chips::ZERO;
    table.raise_count = 0;
    table.short_raise_total = Chips::ZERO;
    table.pots.clear();
    let with_chips = table.seats.iter().filter(|s| !s.chips.is_zero()).count();
    let next = if with_chips >= 2 {
        Phase::NextHandPrep
    } else {
        Phase::Lobby
    };
    change_phase(table, next, events)?;
    events.push(Event::HandEnded { next_phase: next });
    Ok(())
}

fn validated_winners(
    table: &Table,
    allocations: &[Allocation],
) -> Result<BTreeMap<u32, Vec<SeatIndex>>, PokerError> {
    let invalid = |error| PokerError::InvalidAllocation(error);
    let mut winners_by_pot: BTreeMap<u32, Vec<SeatIndex>> = BTreeMap::new();
    for allocation in allocations {
        let pot_index = allocation.pot_index;
        let pot = table
            .pots
            .iter()
            .find(|p| p.tier_index == pot_index)
            .ok_or_else(|| invalid(AllocationError::UnknownPot { pot_index }))?;
        if winners_by_pot.contains_key(&pot_index) {
            return Err(invalid(AllocationError::DuplicatePot { pot_index }));
        }
        if allocation.winners.is_empty() {
            return Err(invalid(AllocationError::NoWinners { pot_index }));
        }
        let mut seats = Vec::with_capacity(allocation.winners.len());
        for player_id in &allocation.winners {
            let seat = table.seat_of(player_id).ok_or(PokerError::UnknownPlayer)?;
            if !pot.eligible.contains(&seat.index) || seats.contains(&seat.index) {
                return Err(invalid(AllocationError::IneligibleWinner {
                    pot_index,
                    player_id: player_id.clone(),
                }));
            }
            seats.push(seat.index);
        }
        winners_by_pot.insert(pot_index, seats);
    }
    if let Some(missing) = table
        .pots
        .iter()
        .find(|p| !winners_by_pot.contains_key(&p.tier_index))
    {
        return Err(invalid(AllocationError::MissingPot {
            pot_index: missing.tier_index,
        }));
    }
    Ok(winners_by_pot)
}

fn resolve_showdown(
    table: &mut Table,
    allocations: &[Allocation],
    events: &mut Vec<Event>,
) -> Result<(), PokerError> {
    if table.phase != Phase::Showdown {
        return Err(PokerError::IllegalTransition {
            from: table.phase,
            to: Phase::NextHandPrep,
        });
    }
    let winners_by_pot = validated_winners(table, allocations)?;
    let pots = std::mem::take(&mut table.pots);
    // Highest side pot first, main pot last (GAME_LOGIC_AND_RULES.md 7.1).
    for pot in pots.iter().rev() {
        let winners = winners_by_pot
            .get(&pot.tier_index)
            .map_or(&[][..], Vec::as_slice);
        let ordered = pots::clockwise_from_button(winners, table.dealer);
        for (seat, amount) in pots::split(pot.amount, &ordered) {
            pay(table, pot.tier_index, seat, amount, events)?;
        }
    }
    end_hand(table, events)
}
