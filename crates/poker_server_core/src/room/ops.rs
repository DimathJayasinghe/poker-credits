//! Handlers for each [`Op`]. All of them run inside [`RoomState::apply`].

use std::collections::BTreeSet;

use poker_engine::deck::Deck;
use poker_engine::{
    Allocation, Chips, Command, Event, HandStatus, MAX_CHIPS, MAX_SEATS, Phase, SeatIndex,
};
use serde_json::json;

use super::state::{
    Broadcast, HostCommand, Op, Outcome, PendingRebuy, Player, Presence, RoomError, RoomState,
    blinds_mode, engine_id, validate_name,
};
use crate::config::{MAX_SPECTATORS, Timings};
use crate::protocol::{ErrorCode, Role, ServerMessage};

type Done = Result<(), RoomError>;

impl RoomState {
    pub(super) fn dispatch(&mut self, op: Op, timings: &Timings, out: &mut Outcome) -> Done {
        match op {
            Op::Join {
                player_id,
                name,
                spectator,
                seat,
                token_hash,
                at_ms,
            } => self.op_join(&player_id, &name, spectator, seat, token_hash, at_ms, out),
            Op::Act {
                player_id,
                action_seq,
                action,
                at_ms,
            } => self.op_act(&player_id, action_seq, action, at_ms, out),
            Op::Host { by, command, at_ms } => {
                if by != self.host_id {
                    return Err(RoomError::new(
                        ErrorCode::HostOnlyAction,
                        "only the host can do that",
                    ));
                }
                self.op_host(command, at_ms, out)
            }
            Op::Timeout { at_ms } => self.op_timeout(at_ms, out),
            Op::DisconnectTimeout { player_id, at_ms } => {
                self.op_disconnect_timeout(&player_id, at_ms, out)
            }
            Op::ChooseSeat {
                player_id,
                seat_index,
                at_ms,
            } => self.op_choose_seat(&player_id, seat_index, at_ms, out),
            Op::SetSittingOut {
                player_id,
                sitting_out,
                at_ms,
            } => {
                self.require_seated(&player_id)?;
                self.engine_step(
                    Command::SetSittingOut {
                        player_id: engine_id(&player_id),
                        sitting_out,
                    },
                    at_ms,
                    out,
                )?;
                self.finish(at_ms, out);
                Ok(())
            }
            Op::LeaveTable { player_id, at_ms } => {
                self.require_seated(&player_id)?;
                self.engine_step(
                    Command::LeaveHand {
                        player_id: engine_id(&player_id),
                    },
                    at_ms,
                    out,
                )?;
                self.finish(at_ms, out);
                Ok(())
            }
            Op::RequestRebuy {
                player_id,
                amount,
                at_ms: _,
            } => self.op_request_rebuy(&player_id, amount, out),
            Op::PresenceVote {
                voter,
                subject,
                still_playing,
                at_ms,
            } => self.op_presence_vote(&voter, &subject, still_playing, at_ms, out),
            Op::PresenceAck { player_id, at_ms } => self.op_presence_ack(&player_id, at_ms, out),
            Op::Recover { at_ms } => {
                self.op_recover(at_ms, timings, out);
                Ok(())
            }
            Op::Tick { at_ms } => self.op_tick(at_ms, timings, out),
            Op::AutoShowdown { allocations, at_ms } => {
                self.op_auto_showdown(allocations, at_ms, out)
            }
            Op::SoloSweep { at_ms } => self.op_solo_sweep(at_ms, out),
        }
    }

    fn require_seated(&self, id: &str) -> Done {
        if self.is_seated(id) {
            Ok(())
        } else {
            Err(RoomError::new(
                ErrorCode::UnknownPlayer,
                "not seated at this table",
            ))
        }
    }

    fn name_of(&self, id: &str) -> String {
        self.players
            .get(id)
            .map_or_else(String::new, |p| p.name.clone())
    }

    fn player_at_seat(&self, seat: SeatIndex) -> Option<&Player> {
        self.players.values().find(|p| p.seat == Some(seat.get()))
    }

    // -----------------------------------------------------------------------------------------
    // Engine bridge
    // -----------------------------------------------------------------------------------------

    /// Runs one engine command, records its events and handles room bookkeeping for them.
    pub(super) fn engine_step(&mut self, command: Command, at_ms: u64, out: &mut Outcome) -> Done {
        let transition = poker_engine::apply(&self.game, command)?;
        self.game = transition.state;
        self.process_events(&transition.events, at_ms, out);
        out.engine_events.extend(transition.events);
        out.changed = true;
        Ok(())
    }

    fn process_events(&mut self, events: &[Event], at_ms: u64, out: &mut Outcome) {
        for event in events {
            match event {
                Event::ActionPerformed {
                    player_id,
                    action,
                    street_total,
                    chips_remaining,
                    all_in,
                    auto,
                    ..
                } => out
                    .broadcasts
                    .push(Broadcast::All(ServerMessage::ActionPerformed {
                        player_id: player_id.to_string(),
                        player_name: self.name_of(player_id.as_str()),
                        kind: *action,
                        amount: street_total.get(),
                        chips_remaining: chips_remaining.get(),
                        all_in: *all_in,
                        auto: *auto,
                    })),
                Event::PlayerAway { player_id } => {
                    let seat = self.players.get(player_id.as_str()).and_then(|p| p.seat);
                    if let Some(player) = self.players.get_mut(player_id.as_str()) {
                        player.sat_out_since_ms = Some(at_ms);
                        player.hands_sat_out = 0;
                    }
                    if let Some(seat_index) = seat {
                        out.broadcasts
                            .push(Broadcast::All(ServerMessage::PlayerAway {
                                player_id: player_id.to_string(),
                                seat_index,
                            }));
                    }
                }
                Event::SittingOutChanged {
                    player_id,
                    sitting_out,
                } => {
                    self.note_sitting_out(player_id.as_str(), *sitting_out, at_ms, out);
                }
                Event::PlayerRemoved { player_id, chips } => {
                    let credit = self.ledger.entry(player_id.to_string()).or_insert(0);
                    *credit = credit.saturating_add(chips.get());
                    self.players.remove(player_id.as_str());
                    self.bots.remove(player_id.as_str());
                    self.pending_removals.retain(|id| id != player_id.as_str());
                    self.pending_rebuys
                        .retain(|r| r.player_id != player_id.as_str());
                    if self
                        .presence
                        .as_ref()
                        .is_some_and(|p| p.subject == player_id.as_str())
                    {
                        self.presence = None;
                    }
                }
                Event::HandStarted { .. } => {
                    self.deal_hole_cards(out);
                    for player in self
                        .players
                        .values_mut()
                        .filter(|p| p.sat_out_since_ms.is_some())
                    {
                        player.hands_sat_out = player.hands_sat_out.saturating_add(1);
                    }
                }
                Event::SeatMoved { player_id, to, .. } => {
                    if let Some(player) = self.players.get_mut(player_id.as_str()) {
                        player.seat = Some(to.get());
                    }
                }
                Event::PlayerAdded { .. }
                | Event::RebuyApplied { .. }
                | Event::BlindsConfigured
                | Event::BlindPosted { .. }
                | Event::TurnStarted { .. }
                | Event::PhaseChanged { .. }
                | Event::BoardRevealed { .. }
                | Event::HandsRevealed { .. }
                | Event::UncalledReturned { .. }
                | Event::RunoutStarted { .. }
                | Event::ShowdownStarted { .. }
                | Event::PotAwarded { .. }
                | Event::HandEnded { .. }
                | Event::Paused
                | Event::Resumed
                | Event::UndoApplied => {}
            }
        }
    }

    fn note_sitting_out(&mut self, id: &str, sitting_out: bool, at_ms: u64, out: &mut Outcome) {
        if let Some(player) = self.players.get_mut(id) {
            if sitting_out {
                player.sat_out_since_ms.get_or_insert(at_ms);
            } else {
                player.sat_out_since_ms = None;
                player.hands_sat_out = 0;
            }
        }
        if !sitting_out && self.presence.as_ref().is_some_and(|p| p.subject == id) {
            self.presence = None;
            out.broadcasts
                .push(Broadcast::All(ServerMessage::PresenceResolved {
                    subject_player_id: id.to_owned(),
                    removed: false,
                }));
        }
    }

    /// After the engine moved: apply queued removals and top-ups between hands, restart the turn
    /// clock when a new turn began, and prompt the player to act.
    pub(super) fn finish(&mut self, at_ms: u64, out: &mut Outcome) {
        self.settle_between_hands(at_ms, out);
        self.track_busted(at_ms);
        let turn_started = out
            .engine_events
            .iter()
            .any(|e| matches!(e, Event::TurnStarted { .. } | Event::UndoApplied));
        let table = &self.game.table;
        if table.paused {
            return;
        }
        if !table.phase.is_betting() || table.active.is_none() {
            self.turn_deadline_ms = None;
            return;
        }
        if !turn_started {
            return;
        }
        // A computer player has no clock: it acts when it has thought about it.
        let bot_turn = table
            .active
            .and_then(|seat| self.player_at_seat(seat))
            .is_some_and(|player| self.is_bot(&player.id));
        let limit_ms = u64::from(self.config.turn_time_limit_seconds) * 1000;
        self.turn_deadline_ms = (limit_ms > 0 && !bot_turn).then(|| at_ms.saturating_add(limit_ms));
        if let Some((seat, legal)) = self.game.legal_actions()
            && let Some(player) = self.player_at_seat(seat)
        {
            out.broadcasts.push(Broadcast::To(
                player.id.clone(),
                ServerMessage::TurnPrompt {
                    player_id: player.id.clone(),
                    seat_index: seat.get(),
                    turn_deadline_ms: self.turn_deadline_ms,
                    next_action_seq: player.next_action_seq,
                    legal,
                },
            ));
        }
    }

    fn settle_between_hands(&mut self, at_ms: u64, out: &mut Outcome) {
        if !matches!(self.game.table.phase, Phase::Lobby | Phase::NextHandPrep) {
            return;
        }
        for id in std::mem::take(&mut self.pending_removals) {
            let removal = Command::RemovePlayer {
                player_id: engine_id(&id),
            };
            if let Err(error) = self.engine_step(removal, at_ms, out)
                && error.code == ErrorCode::HandInProgress
            {
                self.pending_removals.push(id);
            }
        }
        for rebuy in std::mem::take(&mut self.pending_rebuys) {
            if !rebuy.approved {
                self.pending_rebuys.push(rebuy);
                continue;
            }
            let applied = Chips::new(rebuy.amount)
                .map_err(RoomError::from)
                .and_then(|amount| {
                    self.engine_step(
                        Command::Rebuy {
                            player_id: engine_id(&rebuy.player_id),
                            amount,
                        },
                        at_ms,
                        out,
                    )
                });
            if let Err(error) = applied {
                tracing::warn!(player = %rebuy.player_id, code = ?error.code, "dropping rebuy that cannot apply");
            }
        }
    }

    fn track_busted(&mut self, at_ms: u64) {
        let between = matches!(self.game.table.phase, Phase::Lobby | Phase::NextHandPrep);
        let broke: BTreeSet<String> = self
            .game
            .table
            .seats
            .iter()
            .filter(|s| s.chips.is_zero())
            .map(|s| s.player_id.to_string())
            .collect();
        for player in self.players.values_mut().filter(|p| p.seat.is_some()) {
            if between && broke.contains(&player.id) {
                player.busted_since_ms.get_or_insert(at_ms);
            } else {
                player.busted_since_ms = None;
            }
        }
    }

    // -----------------------------------------------------------------------------------------
    // Joining and seating
    // -----------------------------------------------------------------------------------------

    fn choose_seat(&self, wanted: Option<u8>) -> Result<u8, RoomError> {
        let taken: BTreeSet<u8> = self
            .game
            .table
            .seats
            .iter()
            .map(|s| s.index.get())
            .collect();
        match wanted {
            Some(seat) if seat >= MAX_SEATS => {
                Err(RoomError::new(ErrorCode::BadRequest, "seat out of range"))
            }
            Some(seat) if taken.contains(&seat) => {
                Err(RoomError::new(ErrorCode::SeatOccupied, "seat is taken"))
            }
            Some(seat) => Ok(seat),
            None => (0..MAX_SEATS)
                .find(|seat| !taken.contains(seat))
                .ok_or_else(|| RoomError::new(ErrorCode::RoomFull, "all seats are taken")),
        }
    }

    pub(super) fn seat_player(
        &mut self,
        id: &str,
        name: &str,
        role: Role,
        seat: Option<u8>,
        token_hash: String,
    ) -> Done {
        let chosen = self.choose_seat(seat)?;
        let add = Command::AddPlayer {
            player_id: engine_id(id),
            seat: SeatIndex::new(chosen)?,
            chips: Chips::new(self.config.starting_chips)?,
        };
        let mut scratch = Outcome::default();
        self.engine_step(add, 0, &mut scratch)?;
        self.players.insert(
            id.to_owned(),
            Player {
                id: id.to_owned(),
                name: name.to_owned(),
                role,
                seat: Some(chosen),
                token_hash,
                next_action_seq: 0,
                sat_out_since_ms: None,
                hands_sat_out: 0,
                busted_since_ms: None,
            },
        );
        Ok(())
    }

    /// A guest picks a seat for themselves, only before the first hand is dealt and only a free
    /// one: displacing somebody, or moving once the game is running, is the host's call. Moving
    /// freely between hands would let a guest hop out of the big blind's way.
    fn op_choose_seat(&mut self, id: &str, seat_index: u8, at_ms: u64, out: &mut Outcome) -> Done {
        self.require_seated(id)?;
        if self.game.table.phase != Phase::Lobby {
            return Err(RoomError::new(
                ErrorCode::HandInProgress,
                "guests can only choose a seat before the game starts; ask the host",
            ));
        }
        if self
            .player_at_seat(SeatIndex::new(seat_index)?)
            .is_some_and(|p| p.id != id)
        {
            return Err(RoomError::new(ErrorCode::SeatOccupied, "seat is taken"));
        }
        self.move_seat(id, seat_index, at_ms, out)
    }

    /// Moves a seated player to `seat_index` (swapping if it is taken). The engine refuses while a
    /// hand is in progress, so the turn order never changes under a running hand.
    fn move_seat(&mut self, id: &str, seat_index: u8, at_ms: u64, out: &mut Outcome) -> Done {
        self.require_seated(id)?;
        let command = Command::MoveSeat {
            player_id: engine_id(id),
            seat: SeatIndex::new(seat_index)?,
        };
        self.engine_step(command, at_ms, out)?;
        self.finish(at_ms, out);
        Ok(())
    }

    #[allow(clippy::too_many_arguments, reason = "mirrors the fields of Op::Join")]
    fn op_join(
        &mut self,
        id: &str,
        name: &str,
        spectator: bool,
        seat: Option<u8>,
        token_hash: String,
        _at_ms: u64,
        out: &mut Outcome,
    ) -> Done {
        if self.ended {
            return Err(RoomError::new(
                ErrorCode::RoomNotFound,
                "the room has been closed",
            ));
        }
        if self.is_solo() {
            return Err(RoomError::new(
                ErrorCode::RoomFull,
                "this is a private single-player game",
            ));
        }
        let name = validate_name(name)?;
        if self.players.contains_key(id)
            || self
                .players
                .values()
                .any(|p| p.name.eq_ignore_ascii_case(&name))
        {
            return Err(RoomError::new(
                ErrorCode::NameInvalid,
                "that name is already taken",
            ));
        }
        if spectator {
            let watching = self
                .players
                .values()
                .filter(|p| p.role == Role::Spectator)
                .count();
            if watching >= MAX_SPECTATORS {
                return Err(RoomError::new(
                    ErrorCode::SpectatorsFull,
                    "too many spectators",
                ));
            }
            self.players.insert(
                id.to_owned(),
                Player {
                    id: id.to_owned(),
                    name,
                    role: Role::Spectator,
                    seat: None,
                    token_hash,
                    next_action_seq: 0,
                    sat_out_since_ms: None,
                    hands_sat_out: 0,
                    busted_since_ms: None,
                },
            );
        } else {
            self.seat_player(id, &name, Role::Player, seat, token_hash)?;
        }
        self.reserve_id(id);
        out.changed = true;
        Ok(())
    }

    // -----------------------------------------------------------------------------------------
    // Player actions
    // -----------------------------------------------------------------------------------------

    fn op_act(
        &mut self,
        id: &str,
        action_seq: u64,
        action: poker_engine::PlayerAction,
        at_ms: u64,
        out: &mut Outcome,
    ) -> Done {
        self.require_seated(id)?;
        let next = self.players.get(id).map_or(0, |p| p.next_action_seq);
        if action_seq < next {
            out.duplicate = true;
            return Ok(());
        }
        if action_seq > next {
            return Err(RoomError::new(
                ErrorCode::OutOfSync,
                "actionSeq is ahead of the server; resume",
            ));
        }
        let command = Command::Action {
            player_id: engine_id(id),
            action,
        };
        if let Err(mut error) = self.engine_step(command, at_ms, out) {
            if error.code == ErrorCode::InvalidCheck
                && let Some((_, legal)) = self.game.legal_actions()
            {
                error.details = Some(json!({ "callAmount": legal.call_amount.get() }));
            }
            return Err(error);
        }
        if let Some(player) = self.players.get_mut(id) {
            player.next_action_seq = player.next_action_seq.saturating_add(1);
        }
        self.finish(at_ms, out);
        Ok(())
    }

    fn op_disconnect_timeout(&mut self, id: &str, at_ms: u64, out: &mut Outcome) -> Done {
        if self.game.table.paused {
            return Err(RoomError::new(ErrorCode::GamePaused, "the game is paused"));
        }
        let (seat, _) = self
            .game
            .legal_actions()
            .ok_or_else(|| RoomError::new(ErrorCode::HandNotInProgress, "no turn is running"))?;
        if self.player_at_seat(seat).map(|p| p.id.as_str()) != Some(id) {
            return Err(RoomError::new(
                ErrorCode::NotYourTurn,
                "it is not that player's turn",
            ));
        }
        self.engine_step(
            Command::Timeout {
                player_id: engine_id(id),
            },
            at_ms,
            out,
        )?;
        self.finish(at_ms, out);
        Ok(())
    }

    /// Restarts the clocks that were running when the room went down. A clock is only ever
    /// moved later, never earlier, and a paused game has none to restart.
    fn op_recover(&mut self, at_ms: u64, timings: &Timings, out: &mut Outcome) {
        let limit_ms = u64::from(self.config.turn_time_limit_seconds) * 1000;
        if let Some(deadline) = self.turn_deadline_ms {
            let fresh = deadline.max(at_ms.saturating_add(limit_ms));
            if fresh != deadline {
                self.turn_deadline_ms = Some(fresh);
                out.changed = true;
            }
        }
        if let Some(presence) = self.presence.as_mut() {
            let fresh = presence
                .deadline_ms
                .max(at_ms.saturating_add(timings.presence_check_ms));
            if fresh != presence.deadline_ms {
                presence.deadline_ms = fresh;
                out.changed = true;
            }
        }
    }

    fn op_timeout(&mut self, at_ms: u64, out: &mut Outcome) -> Done {
        if self.game.table.paused {
            return Err(RoomError::new(ErrorCode::GamePaused, "the game is paused"));
        }
        match self.turn_deadline_ms {
            Some(deadline) if at_ms >= deadline => {}
            _ => {
                return Err(RoomError::new(
                    ErrorCode::BadRequest,
                    "the turn has not expired",
                ));
            }
        }
        let (seat, _) = self
            .game
            .legal_actions()
            .ok_or_else(|| RoomError::new(ErrorCode::HandNotInProgress, "no turn is running"))?;
        let id = self
            .player_at_seat(seat)
            .map(|p| p.id.clone())
            .ok_or_else(|| RoomError::new(ErrorCode::UnknownPlayer, "no player on that seat"))?;
        self.engine_step(
            Command::Timeout {
                player_id: engine_id(&id),
            },
            at_ms,
            out,
        )?;
        self.finish(at_ms, out);
        Ok(())
    }

    fn refuse_in_solo(&self) -> Done {
        if self.is_solo() {
            return Err(RoomError::new(
                ErrorCode::BadRequest,
                "nobody buys back in during a single-player game",
            ));
        }
        Ok(())
    }

    fn op_request_rebuy(&mut self, id: &str, amount: u64, out: &mut Outcome) -> Done {
        self.refuse_in_solo()?;
        self.require_seated(id)?;
        if amount == 0 || amount > MAX_CHIPS {
            return Err(RoomError::new(
                ErrorCode::InvalidAmount,
                "invalid top-up amount",
            ));
        }
        self.pending_rebuys
            .retain(|r| r.player_id != id || r.approved);
        self.pending_rebuys.push(PendingRebuy {
            player_id: id.to_owned(),
            amount,
            approved: false,
        });
        out.changed = true;
        Ok(())
    }

    // -----------------------------------------------------------------------------------------
    // Host commands
    // -----------------------------------------------------------------------------------------

    fn op_host(&mut self, command: HostCommand, at_ms: u64, out: &mut Outcome) -> Done {
        match command {
            HostCommand::StartHand { deck } => {
                let deck = self.deck_for_hand(deck)?;
                self.note_hand_start();
                let elapsed_ms = if self.config.is_tournament {
                    at_ms.saturating_sub(*self.tournament_started_ms.get_or_insert(at_ms))
                } else {
                    0
                };
                self.engine_step(Command::StartHand { elapsed_ms, deck }, at_ms, out)?;
            }
            HostCommand::BeginShowdown => {
                self.require_manual_showdown()?;
                self.engine_step(Command::BeginShowdown, at_ms, out)?;
            }
            HostCommand::ResolveShowdown { allocations } => {
                self.require_manual_showdown()?;
                let allocations = allocations
                    .into_iter()
                    .map(|a| Allocation {
                        pot_index: a.pot_index,
                        winners: a.winner_player_ids.iter().map(|id| engine_id(id)).collect(),
                    })
                    .collect();
                self.engine_step(Command::ResolveShowdown { allocations }, at_ms, out)?;
            }
            HostCommand::Undo => {
                self.require_undo_keeps_cards_hidden()?;
                self.engine_step(Command::Undo, at_ms, out)?;
            }
            HostCommand::Pause { reason } => return self.op_pause(reason, at_ms, out),
            HostCommand::ResumeGame => return self.op_resume(at_ms, out),
            HostCommand::ApproveRebuy { player_id, amount } => {
                self.op_approve_rebuy(&player_id, amount, out)?;
            }
            HostCommand::Kick { player_id } => {
                self.refuse_in_solo()?;
                self.op_kick(&player_id, at_ms, out)?;
            }
            HostCommand::MoveSeat {
                player_id,
                seat_index,
            } => self.move_seat(&player_id, seat_index, at_ms, out)?,
            HostCommand::Configure { config } => {
                self.refuse_in_solo()?;
                let blinds = blinds_mode(&config)?;
                self.engine_step(Command::Configure { blinds }, at_ms, out)?;
                // Real or virtual cards is decided when the room is created, never later.
                let card_mode = self.config.card_mode;
                self.config = config;
                self.config.card_mode = card_mode;
            }
            HostCommand::EndGame => {
                self.ended = true;
                out.changed = true;
                return Ok(());
            }
        }
        self.finish(at_ms, out);
        Ok(())
    }

    /// A virtual room decides showdowns itself; the host's manual controls are for real cards.
    fn require_manual_showdown(&self) -> Done {
        if self.is_virtual() {
            return Err(RoomError::new(
                ErrorCode::IllegalState,
                "this room runs showdowns automatically",
            ));
        }
        Ok(())
    }

    /// With virtual cards, taking an action back must not un-reveal a card that every player
    /// has already seen, so it only works inside the street where the action happened.
    fn require_undo_keeps_cards_hidden(&self) -> Done {
        if !self.is_virtual() {
            return Ok(());
        }
        let table = &self.game.table;
        let same_street = table.phase.is_betting()
            && self
                .game
                .history
                .last()
                .is_some_and(|before| before.phase == table.phase);
        if same_street || self.game.history.is_empty() {
            Ok(())
        } else {
            Err(RoomError::new(
                ErrorCode::IllegalState,
                "cards were already revealed; undo only works within the same betting round",
            ))
        }
    }

    /// The deck for a new hand: a virtual room must be given one, a physical room never uses one.
    fn deck_for_hand(&self, deck: Option<Deck>) -> Result<Option<Deck>, RoomError> {
        match (self.is_virtual(), deck) {
            (true, Some(deck)) => Ok(Some(deck)),
            (true, None) => Err(RoomError::new(
                ErrorCode::InternalError,
                "a virtual hand needs a shuffled deck",
            )),
            (false, _) => Ok(None),
        }
    }

    /// Remembers who is in the hand and queues each player's private cards.
    fn deal_hole_cards(&mut self, out: &mut Outcome) {
        self.hand_names.clear();
        let Some(deal) = self.game.table.deal.as_ref() else {
            return;
        };
        let dealt: Vec<(String, poker_engine::card::Card, poker_engine::card::Card)> = deal
            .holes
            .iter()
            .map(|(id, [first, second])| (id.to_string(), *first, *second))
            .collect();
        let hand_number = deal.hand_number;
        for (id, first, second) in dealt {
            let name = self.name_of(&id);
            self.hand_names.insert(id.clone(), name);
            out.broadcasts.push(Broadcast::To(
                id,
                ServerMessage::HoleCards {
                    hand_number,
                    cards: [first, second],
                },
            ));
        }
    }

    /// The server's showdown: ranks were computed from the table when the op was made; the
    /// engine still checks that every winner is eligible for the pot they are given.
    fn op_auto_showdown(
        &mut self,
        allocations: Vec<Allocation>,
        at_ms: u64,
        out: &mut Outcome,
    ) -> Done {
        if !self.needs_auto_showdown() {
            return Err(RoomError::new(
                ErrorCode::IllegalState,
                "no showdown is waiting",
            ));
        }
        if self.game.table.phase == Phase::AllInRunout {
            self.engine_step(Command::BeginShowdown, at_ms, out)?;
        }
        self.engine_step(Command::ResolveShowdown { allocations }, at_ms, out)?;
        self.finish(at_ms, out);
        Ok(())
    }

    fn op_pause(&mut self, reason: Option<String>, at_ms: u64, out: &mut Outcome) -> Done {
        self.engine_step(Command::Pause, at_ms, out)?;
        self.paused_remaining_ms = self.turn_deadline_ms.map(|d| d.saturating_sub(at_ms));
        self.turn_deadline_ms = None;
        out.broadcasts
            .push(Broadcast::All(ServerMessage::GamePaused {
                paused_by: self.host_id.clone(),
                reason,
            }));
        Ok(())
    }

    fn op_resume(&mut self, at_ms: u64, out: &mut Outcome) -> Done {
        self.engine_step(Command::Resume, at_ms, out)?;
        // The turn clock continues where it stopped: paused time is not held against the player.
        self.turn_deadline_ms = self
            .paused_remaining_ms
            .take()
            .map(|left| at_ms.saturating_add(left));
        out.broadcasts
            .push(Broadcast::All(ServerMessage::GameResumed {
                resumed_by: self.host_id.clone(),
                turn_deadline_ms: self.turn_deadline_ms,
            }));
        Ok(())
    }

    fn op_approve_rebuy(&mut self, id: &str, amount: u64, out: &mut Outcome) -> Done {
        self.refuse_in_solo()?;
        self.require_seated(id)?;
        if amount == 0 || amount > MAX_CHIPS {
            return Err(RoomError::new(
                ErrorCode::InvalidAmount,
                "invalid top-up amount",
            ));
        }
        self.pending_rebuys.retain(|r| r.player_id != id);
        self.pending_rebuys.push(PendingRebuy {
            player_id: id.to_owned(),
            amount,
            approved: true,
        });
        out.changed = true;
        Ok(())
    }

    fn op_kick(&mut self, id: &str, at_ms: u64, out: &mut Outcome) -> Done {
        if id == self.host_id {
            return Err(RoomError::new(
                ErrorCode::BadRequest,
                "the host cannot be removed",
            ));
        }
        let Some(player) = self.players.get(id) else {
            return Err(RoomError::new(ErrorCode::UnknownPlayer, "no such player"));
        };
        if player.seat.is_none() {
            self.players.remove(id);
            out.changed = true;
            return Ok(());
        }
        self.remove_seated(id, at_ms, out)
    }

    /// Folds the player if they are in a hand and removes them as soon as no hand needs them.
    fn remove_seated(&mut self, id: &str, at_ms: u64, out: &mut Outcome) -> Done {
        let in_hand = self
            .game
            .table
            .seat_of(&engine_id(id))
            .is_some_and(|s| s.status != HandStatus::Out);
        if in_hand {
            self.engine_step(
                Command::LeaveHand {
                    player_id: engine_id(id),
                },
                at_ms,
                out,
            )?;
        }
        if !self.pending_removals.iter().any(|p| p == id) {
            self.pending_removals.push(id.to_owned());
        }
        out.changed = true;
        Ok(())
    }

    // -----------------------------------------------------------------------------------------
    // Presence check (inactive players)
    // -----------------------------------------------------------------------------------------

    fn op_tick(&mut self, at_ms: u64, timings: &Timings, out: &mut Outcome) -> Done {
        if let Some(presence) = &self.presence {
            if at_ms >= presence.deadline_ms {
                let removed = self.verdict(true).unwrap_or(false);
                return self.resolve_presence(removed, at_ms, out);
            }
            return Ok(());
        }
        let candidate = self
            .players
            .values()
            .filter(|p| p.seat.is_some() && p.id != self.host_id)
            .find(|p| {
                self.game
                    .table
                    .seat_of(&engine_id(&p.id))
                    .is_some_and(|s| s.sitting_out)
                    && p.sat_out_since_ms.is_some_and(|since| {
                        at_ms.saturating_sub(since) >= timings.away_after_ms
                            || p.hands_sat_out >= timings.away_after_hands
                    })
            })
            .map(|p| p.id.clone());
        if let Some(subject) = candidate {
            self.start_presence(subject, at_ms, timings, out);
        }
        Ok(())
    }

    fn start_presence(
        &mut self,
        subject: String,
        at_ms: u64,
        timings: &Timings,
        out: &mut Outcome,
    ) {
        let deadline_ms = at_ms.saturating_add(timings.presence_check_ms);
        let subject_name = self.name_of(&subject);
        for player in self
            .players
            .values()
            .filter(|p| p.seat.is_some() && p.id != subject)
        {
            out.broadcasts.push(Broadcast::To(
                player.id.clone(),
                ServerMessage::PresenceCheck {
                    subject_player_id: subject.clone(),
                    subject_name: subject_name.clone(),
                    deadline_ms,
                },
            ));
        }
        self.presence = Some(Presence {
            subject,
            deadline_ms,
            votes: std::collections::BTreeMap::new(),
        });
        out.changed = true;
    }

    fn op_presence_vote(
        &mut self,
        voter: &str,
        subject: &str,
        still_playing: bool,
        at_ms: u64,
        out: &mut Outcome,
    ) -> Done {
        let running = self.presence.as_ref().is_some_and(|p| p.subject == subject);
        if !running {
            return Err(RoomError::new(
                ErrorCode::NoPresenceCheck,
                "no presence check is running for that player",
            ));
        }
        if voter == subject || !self.is_seated(voter) {
            return Err(RoomError::new(
                ErrorCode::BadRequest,
                "only the other seated players can vote",
            ));
        }
        if let Some(presence) = self.presence.as_mut() {
            presence.votes.insert(voter.to_owned(), still_playing);
        }
        out.changed = true;
        match self.verdict(false) {
            Some(removed) => self.resolve_presence(removed, at_ms, out),
            None => Ok(()),
        }
    }

    fn op_presence_ack(&mut self, id: &str, at_ms: u64, out: &mut Outcome) -> Done {
        if self.presence.as_ref().is_none_or(|p| p.subject != id) {
            return Err(RoomError::new(
                ErrorCode::NoPresenceCheck,
                "no presence check is running for you",
            ));
        }
        self.engine_step(
            Command::SetSittingOut {
                player_id: engine_id(id),
                sitting_out: false,
            },
            at_ms,
            out,
        )?;
        self.finish(at_ms, out);
        Ok(())
    }

    /// The outcome of the running check: `Some(true)` remove, `Some(false)` keep, `None` undecided.
    ///
    /// The host's vote is final. Otherwise a strict majority of the *other* seated players
    /// decides early; at the deadline (`last`) the replies that came in decide and silence is an
    /// abstention, so with no replies nothing happens.
    fn verdict(&self, last: bool) -> Option<bool> {
        let presence = self.presence.as_ref()?;
        if let Some(host_vote) = presence.votes.get(&self.host_id) {
            return Some(!host_vote);
        }
        let eligible = self
            .players
            .values()
            .filter(|p| p.seat.is_some() && p.id != presence.subject)
            .count();
        let yes = presence.votes.values().filter(|v| **v).count();
        let no = presence.votes.len() - yes;
        if last {
            return Some(no > yes);
        }
        if no * 2 > eligible {
            Some(true)
        } else if yes * 2 >= eligible {
            Some(false)
        } else {
            None
        }
    }

    fn resolve_presence(&mut self, removed: bool, at_ms: u64, out: &mut Outcome) -> Done {
        let Some(presence) = self.presence.take() else {
            return Ok(());
        };
        out.broadcasts
            .push(Broadcast::All(ServerMessage::PresenceResolved {
                subject_player_id: presence.subject.clone(),
                removed,
            }));
        out.changed = true;
        if removed {
            self.remove_seated(&presence.subject, at_ms, out)?;
            self.finish(at_ms, out);
        } else if let Some(player) = self.players.get_mut(&presence.subject) {
            // Kept: ask again only after another full waiting period.
            player.sat_out_since_ms = Some(at_ms);
            player.hands_sat_out = 0;
        }
        Ok(())
    }
}
