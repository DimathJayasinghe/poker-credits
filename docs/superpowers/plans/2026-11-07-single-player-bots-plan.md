# Single Player with Bots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline; this project bans subagents unless the owner asks, `CLAUDE.md`). Steps use checkbox (`- [ ]`) syntax. Tasks 0 to 5 are high risk (Rust, fairness, restore): run them on the strongest model or have it review each commit; Tasks 7 to 9 are UI and strings and fit a mid-tier model with this plan as the brief (`docs/MODEL_STRATEGY.md`).

**Goal:** A solo mode: the player picks 1 to 9 bots and a skill level and plays a freeze-out tournament against fair, adaptive, distinct computer players, with no network and negligible battery cost.

**Architecture:** A new pure-Rust crate `poker_bots` decides from a per-seat view. The room actor seats bots, schedules their actions as timers and journals them as normal player actions. The Flutter app starts a loopback-only hosted room with `solo` config and shows a solo setup screen, a player-style table and end screens.

**Tech Stack:** Rust (engine, `poker_bots`, `poker_server_core`, FRB bridge), Flutter + Refena. No new dependencies (`rand` is not added; PRNG is hand-written over `getrandom`).

**Spec:** `docs/superpowers/specs/2026-11-07-single-player-bots-design.md` (approved 2026-11-07). Read it whole first.

## Global Constraints

- Branch `feature/solo-bots` from `feature/engine-cards` (= `main`). One commit per task (more if a task says so), Conventional Commits, scope per `AGENT_CODING_GUIDE.md`. **No AI attribution** anywhere. Never push `main` or tag without the owner's say.
- Always `fvm flutter` / `fvm dart`. Rust lints: `unwrap_used`, `expect_used`, `indexing_slicing`, `panic` are denied workspace-wide; `missing_docs` warns; never `panic = "abort"`.
- All rules and bot strategy in Rust. Dart holds no poker rules and no bot logic.
- Fairness: `poker_bots::decide` receives only a `BotView`. Bots never see `RoomState`, the deck, or others' hole cards.
- No dependency outside `AGENT_CODING_GUIDE.md` section 6. `poker_bots` depends on `poker_engine` only (plus dev: `proptest`).
- Bots look exactly like real players: `is_bot` is internal and never serialised to clients. No bot tag in the UI.
- Solo = cards in the app only, human timer off by default, server bound to `127.0.0.1`, no lobby entry, no host keep-alive, game pauses when the app is backgrounded.
- UI: `widget/brutal/` and tokens only (`docs/UI_DESIGN.md`), type scale `BrutalType`, dense rows, 44 px taps, text scale 3.0 safe. Web-safe: platform code only in `app/lib/platform/`; `bash tool/check_web_safe.sh`.
- Gates before each commit that touches code: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`; for app work `fvm flutter analyze` and `fvm flutter test` in `app`, `bash tool/check_no_state_logging.sh`. Never `--no-verify`.
- Goldens: regenerate only the intended ones with `--update-goldens` and look at the images.

## Rulings (deviations from the spec, found while reading the code)

1. **Blind ladder (spec 10.2):** not a new `BlindsMode::Ladder` variant. The existing `Tournament` struct already carries the ladder levels (`LADDER_HALVES`, `state.rs`); Task 0 adds an optional `hands_per_level: Option<u32>` to it (serde default `None`, so old journals and snapshots load). When set, the level comes from `hand_number`, not `elapsed_ms`. Cost if wrong: none, same behaviour with a smaller change.
2. **View builder location (spec 3.1, 5.1):** `BotView::from_table(&Table, SeatIndex)` lives in `poker_bots::observe` (depends on engine types only), not in `room/bots.rs`, so the crate-level fairness tests and the simulation use the very function the server uses. It is the single audited place that reads the table; `decide` never sees a `Table`.
3. **Finishing places on the wire:** the client needs "Maya is out (6th)" and the end screen. Not derivable safely in Dart. The room state gains an additive, serde-default `finish_order: Vec<{playerId, place}>` in the room view for solo rooms only (spec 7 said no new wire; this is additive and does not reveal bots). Update `API_AND_EVENTS.md` section 10 in Task 5.
4. **Auto-start of the next hand:** a solo human never taps "Start hand". The actor schedules `Op::Host { command: StartHand }` after a 3 s result pause when two or more players have chips, and stops when one is left.

## Review Focus (inputs the tasks' tests must pin)

1. A restored solo room where it is a bot's turn: the bot still acts (absence exemption) and no `DisconnectTimeout` or `SetSittingOut` is ever produced for a bot.
2. Two or more players bust in the same hand: places are assigned by stack at the start of the hand (smaller loses first); the same hand never gives two players the same place.
3. A bot with a short stack: every decision is a legal action (raise amounts within `min_raise_to..=max_raise_to`, all-in when needed); never an illegal fold-when-check or a raise below the minimum.
4. Heads-up and a 1-bot table: blinds, button and position logic work with two players; `decide` handles one opponent.
5. Pause while a bot is thinking: no action is submitted while `table.paused`; on resume the bot acts after its remaining delay, not instantly, and never twice.

---

## File Structure

- Create `crates/poker_bots/` (`Cargo.toml`, `src/lib.rs`, `view.rs`, `observe.rs`, `rng.rs`, `strength.rs`, `equity.rs`, `personality.rs`, `notes.rs`, `skill.rs`, `decide.rs`, `names.rs`; `tests/`).
- Modify `Cargo.toml` (workspace member), `crates/poker_engine/src/blinds.rs`.
- Create `crates/poker_server_core/src/room/bots.rs`, `tests/bots_sim.rs`, `tests/bots_room.rs`; modify `room/{actor,absence,state,ops,view}.rs`, `protocol.rs`, `config.rs` (think scale), `lib.rs` if needed.
- Modify `packages/poker_bridge/rust/src/api/server.rs`; `packages/poker_protocol` models and `app/lib/**` as listed per task.
- Docs per Task 10.

---

### Task 0: Hand-driven blind levels (engine)

**Files:** Modify `crates/poker_engine/src/blinds.rs`; tests in the same file's `tests` module or `crates/poker_engine/tests/`.

**Interfaces:**
- Produces: `Tournament { levels: Vec<Blinds>, level_ms: u64, hands_per_level: Option<u32> }` with `#[serde(default, skip_serializing_if = "Option::is_none")]` on the new field. `blinds(hand_number, elapsed_ms)`: if `hands_per_level = Some(n)` with `n > 0`, level index = `(hand_number - 1) / n` (clamped to the last level); else unchanged. `validate`: `levels` non-empty and (`level_ms > 0` or `hands_per_level > Some(0)`), plus each level valid.

- [ ] **Step 1: tests (write first).** `hand_ladder_rises_every_n_hands` (n = 3: hands 1 to 3 level 0, hand 4 level 1, hand 100 clamps to last), `hand_ladder_ignores_elapsed_time` (same hand, `elapsed_ms` 0 and 10^9 give equal blinds), `old_tournament_json_loads_without_the_field` (JSON without `handsPerLevel` parses to `None`), `hand_ladder_validates` (n = 0 with `level_ms = 0` is `InvalidAmount`).
- [ ] **Step 2:** `cargo test -p poker_engine blinds` fails (field missing). **Step 3:** implement. **Step 4:** passes; `cargo test -p poker_engine` fully green. **Step 5:** commit `feat(engine): blind levels that rise by hand count`.

### Task 1: `poker_bots` crate: view, observation, RNG, hand strength

**Files:** Create the crate files above (this task: `lib.rs`, `view.rs`, `observe.rs`, `rng.rs`, `strength.rs`, `equity.rs`); modify root `Cargo.toml` members; `crates/poker_bots/Cargo.toml` copies `poker_engine`'s fields, `[lints] workspace = true`, deps `poker_engine = { path = "../poker_engine" }`, dev `proptest`.

**Interfaces:**
- Produces `view.rs`: `pub struct BotView { pub me: SeatIndex, pub hole: [Card; 2], pub board: Vec<Card>, pub phase: Phase, pub pot_total: Chips, pub seats: Vec<SeatView>, pub button: Option<SeatIndex>, pub to_call: Chips, pub legal: LegalActions, pub blinds: Blinds, pub hand_number: u32, pub history: Vec<PublicAction> }`; `SeatView { index, player_id, chips, street_bet, hand_contrib, status, sitting_out }`; `PublicAction { seat: SeatIndex, street: Phase, kind: ActionKind, amount: Chips }`; `Reveal { seat: SeatIndex, hole: [Card; 2] }` (delivered separately after showdown, see Task 3).
- Produces `observe.rs`: `pub fn view_for_seat(table: &Table, seat: SeatIndex, history: &[PublicAction]) -> Option<BotView>`: reads only this seat's hole cards from `table.deal`, the visible board, and public seat data. Returns `None` when the seat has no hole cards.
- Produces `rng.rs`: `pub struct BotRng`; `BotRng::from_seed(u64)` (the crate has no `getrandom` dependency; the server seeds each bot from `getrandom`), `next_u64`, `below(n: u32) -> u32` (unbiased), `chance(p: f32) -> bool`, `jitter(base: f32, spread: f32) -> f32`. Algorithm: splitmix64.
- Produces `strength.rs`: `pub fn preflop_strength(hole: [Card; 2]) -> f32` (0..=1) from a `const [u8; 169]` table indexed by (high rank, low rank, suited); `pub fn preflop_adjust(strength, position, players) -> f32`.
- Produces `equity.rs`: `pub fn equity(hole: [Card; 2], board: &[Card], opponents: usize, samples: u32, rng: &mut BotRng, budget: Option<std::time::Duration>) -> f32`. Unknown cards come from 52 minus hole minus board only; ranks with `poker_engine::hand_rank::best_of`; stops early when `budget` is exceeded after at least 20 samples.

- [ ] **Step 1: tests (first, RED).** `view_has_no_foreign_cards` (for random dealt tables, each seat's `BotView` contains only its own hole cards and none of the others'; property), `view_for_seat_none_without_cards`, `rng_below_is_uniform` (chi-square over 60k draws for bound 7 within a fixed tolerance), `rng_same_seed_same_stream`, `preflop_table_orders_hands` (AA > KK > AKs > 72o; every entry within 0..=255), `equity_known_cases` (AA vs 1 random opponent preflop within 0.82 to 0.88 at 4000 samples; a made nut flush on the river vs 3 opponents above 0.97), `equity_never_uses_hidden_cards` (equity is identical for the same seed when the real opponents' cards are changed, because the function never receives them), `equity_respects_budget` (a 1 ms budget stops early).
- [ ] **Step 2:** run `cargo test -p poker_bots` (compile fail). **Step 3:** implement the modules. **Step 4:** green; clippy clean. **Step 5:** commit `feat(bots): per-seat view, rng, hand strength and equity`.

### Task 2: Personalities, skill, decision, thinking time

**Files:** Create `personality.rs`, `skill.rs`, `decide.rs`, `names.rs`, extend `lib.rs`.

**Interfaces:**
- `skill.rs`: `pub enum Skill { Easy, Normal, Hard }` (serde, `SCREAMING_SNAKE_CASE`) with `samples(self) -> u32` (0, 120, 400), `error_rate(self) -> f32`, `read_threshold(self) -> u32` (observations needed: Easy `u32::MAX`, Normal 25, Hard 10), `read_gain(self) -> f32`.
- `personality.rs`: `pub enum Archetype { Rock, Tag, Lag, CallingStation, Maniac, NitTrapper }`; `pub struct Personality { pub archetype: Archetype, pub looseness: f32, pub aggression: f32, pub bluff: f32, pub trap: f32, pub size_habit: f32, pub tilt: f32, pub think_speed: f32, pub read_weight: f32 }` (serde, all parameters in 0..=1 except size_habit 0.3..=1.2); `Personality::sample(archetype: Archetype, rng: &mut BotRng) -> Personality`; `pub fn pick_archetypes(count: usize, rng: &mut BotRng) -> Vec<Archetype>` (distinct until all six are used, then repeats); `pub fn rival(p: &Personality) -> Personality` (raises `read_weight`, keeps archetype).
- `names.rs`: `pub const NAMES: [&str; 40]` plain first names (letters only, 2 to 10 chars, each valid under `validate_name`); `pub fn pick_names(count, rng) -> Vec<&'static str>` distinct.
- `decide.rs`: `pub struct BotMind { pub personality: Personality, pub skill: Skill, pub mood: f32, pub notes: Notes }` (`Notes` stub with `Default` until Task 4); `pub struct Decision { pub action: PlayerAction, pub think_ms: u32 }`; `pub fn decide(view: &BotView, mind: &mut BotMind, rng: &mut BotRng) -> Decision`. Rules: preflop uses `preflop_adjust(preflop_strength(..))`; postflop uses `equity` with `skill.samples()` (Easy: a made-hand tier from `best_of`); then pot odds, stack-to-pot ratio, bluff and trap rolls, bet sizing from `size_habit` rounded to the big blind unit and clamped into `legal.min_raise_to..=legal.max_raise_to`; `error_rate` mixes in a worse action. Always returns an action allowed by `view.legal` (fall back to check when `can_check`, else fold). `think_ms` 400 to 900 for clear spots, 1200 to 3500 for close ones, scaled by `think_speed`, 10 percent snap decisions.
- Cost bound: `decide` passes an 8 ms budget to `equity`.

- [ ] **Step 1: tests (RED).** `decide_is_always_legal` (proptest: random legal views including short stacks, heads-up, all-in only; the returned action passes `poker_engine::validator` for that seat), `decide_never_panics_on_odd_views`, `raise_amount_within_bounds`, `personality_params_in_range`, `pick_archetypes_distinct_until_six`, `names_are_valid_and_distinct` (all 40 pass the room's name rules: 1 to 20 chars of `[A-Za-z0-9 _-]`), `think_time_ranges` (clear fold within 400 to 900 ms when `think_speed` is neutral), `decide_cost_budget` (Hard postflop 200 decisions: median under 10 ms in debug-or-release equivalent; mark `#[ignore]` only if the CI box is too slow, record the number in the commit message).
- [ ] **Step 2-4:** fail, implement, pass, clippy. **Step 5:** commit `feat(bots): personalities, skill levels and the decision function`.

### Task 3: Fairness tests and headless simulation (crate level)

**Files:** Create `crates/poker_bots/tests/fairness.rs`, `tests/sim.rs`, `tests/support/table.rs` (a tiny driver that runs `poker_engine::GameState` with bots at every seat, shuffles with a seeded `BotRng`, builds each view with `observe::view_for_seat`, applies `Command::Action`, ends hands and records chips). Add `Reveal` handling: after a showdown the driver passes revealed hands to `BotMind::observe_showdown` (stub until Task 4).

**Interfaces:** Consumes `view_for_seat`, `decide`, `BotMind`. Produces helper `play_hands(config, seeds, hands) -> Vec<SeatStats>` with `SeatStats { net_chips, hands_won, vpip, pfr, hands }`.

- [ ] **Step 1: tests (first).** `bot_view_invariance` (proptest: for the same seed and view, change every other player's hole cards and the undealt deck in the underlying table; `decide` returns an identical `Decision`; also assert two bots with equal personality, skill and seed decide identically from identical views); `no_seat_advantage` (6 identical Normal bots, 6000 hands, rotating seeds: each seat's average net within 3 standard errors of 0); `hands_complete_and_chips_conserved` (10000 hands, sum of stacks constant, no stalls); `archetypes_are_distinct` (one bot of each archetype, 10000 hands: VPIP and PFR ordered as expected, for example Rock VPIP below Lag VPIP below Maniac VPIP, with margins recorded after the first run); `hard_beats_easy` (3 Hard vs 3 Easy, 6000 hands: Hard group's mean net is above Easy's; record the margin) and `normal_between` (Normal sits between in a 2/2/2 table at the margin recorded).
- [ ] **Step 2:** run (RED where behaviour is missing); tune only the constants in `decide.rs`/`skill.rs`/`personality.rs` until the tests pass, never loosen the fairness tests. **Step 3:** green, clippy. **Step 4:** commit `test(bots): fairness and headless simulation`.

### Task 4: Opponent notes, adaptation, mood

**Files:** Create `crates/poker_bots/src/notes.rs`; modify `decide.rs`, `skill.rs`.

**Interfaces:**
- `Notes`: per opponent `OppStats { hands, vpip, pfr, bets, calls, checks, folds_to_bet, folds_to_raise, cbets, cbet_opps, showdowns, weak_showdowns, avg_bet_pct }` (small ints); smoothing `fn rate(count, opps, prior, weight)`.
- `BotMind::observe_action(&mut self, a: &PublicAction, view: &BotView)` (once per public action, O(1)); `observe_showdown(&mut self, reveals: &[Reveal], view: &BotView)`; `observe_hand_end(&mut self, my_net: i64, big_blind: Chips)` updates `mood` (tilt decays 0.85 per hand; a knockout gives a small confidence lift).
- `decide` uses reads when an opponent has at least `skill.read_threshold()` observations: widen bluffs against high `fold_to_bet`, thin value against calling stations, respect raises from tight-aggressive opponents, tighten vs a wild opponent, trap players who bet weak signals; shift strength scaled by `skill.read_gain() * personality.read_weight`; Easy ignores notes.

- [ ] **Step 1: tests (RED).** `smoothing_resists_one_hand` (one observation moves a read by less than 5 percent), `bot_bluffs_more_against_folder` (sim: same bot vs an always-fold-to-bet puppet vs a never-fold puppet over 3000 hands: bluff-bet frequency higher against the folder for Hard, flat for Easy), `reads_need_threshold` (Normal needs 25 observations before shifting; Hard 10), `notes_are_per_bot` (two bots at one table end with different notes), `notes_do_not_leak` (notes contain no card fields; a type-level assertion that `OppStats` has only counters; decisions still invariant under hidden-card changes, re-run `bot_view_invariance` with adaptation on), `mood_decays`, plus the Task 3 simulation tests still pass.
- [ ] **Step 2-4:** RED, implement, GREEN, re-tune constants only. **Step 5:** commit `feat(bots): opponent notes, adaptation and mood`.

### Task 5: Room integration: bots as seated players

**Files:** Create `room/bots.rs`; modify `room/state.rs` (`Player.is_bot` with `#[serde(default, skip_serializing)]`, `Op::AddBot`, `RoomState::finish_order`), `room/ops.rs` (apply `AddBot`, solo rules, eliminations), `room/absence.rs`, `room/actor.rs`, `room/view.rs`, `protocol.rs` (`RoomConfig` fields, validation; `finish_order` in the view), `crates/poker_server_core/Cargo.toml` (`poker_bots` dependency), `config.rs` (`Timings::bot_think_scale: f32`, `bot_next_hand_ms: u64`).

**Interfaces:**
- `RoomConfig` adds `solo: bool`, `bots: u8`, `bot_skill: Skill`, `blind_ladder_hands: u32` (all `#[serde(default)]`; defaults false, 0, Normal, 8). `validate_solo(&RoomConfig)`: requires `card_mode` virtual, `1 <= bots <= 9`, `is_tournament = true` with the ladder (`blinds_mode` builds `Tournament { hands_per_level: Some(blind_ladder_hands), .. }` when `solo`), human timer default 0.
- `Op::AddBot { player_id: String, name: String, seat: u8, chips: u64, personality: Personality, skill: Skill, at_ms: u64 }`: journaled, creates a seated `Player { is_bot: true, token_hash: String::new(), .. }`; rejected unless `config.solo`.
- `room/bots.rs`: `pub(super) struct BotDriver { minds: BTreeMap<String, BotMind>, rngs: BTreeMap<String, BotRng>, history: Vec<PublicAction>, due_ms: Option<u64>, pending: Option<Decision> }` with `fn on_event(&mut self, events: &[Event])`, `fn next_due_ms(&self, state: &RoomState) -> Option<u64>`, `fn due_op(&mut self, state: &RoomState, now: u64, scale: f32) -> Option<Op>` returning `Op::Act { player_id, action_seq: player.next_action_seq, action, at_ms }`, `fn next_hand_op(...) -> Option<Op>` (the auto-start, ruling 4), `fn restore(state: &RoomState) -> BotDriver` (empty notes, same personalities from the journal's `AddBot` ops via `Player` data kept in `RoomState`: add `bot_profiles: BTreeMap<String, (Personality, Skill)>` to `RoomState`, journal-derived).
- `actor.rs`: `next_wake_ms` includes `driver.next_due_ms`; `run_due` submits the due bot op, with `internal_floor_ms` guard like timeouts; failed or illegal submission falls back to check or fold and logs a warning; nothing is submitted while `table.paused`; no action when the driver's decision was made for an earlier turn (re-check `legal_actions()` seat equals the bot's seat).
- `absence.rs`: `Absence::new`, `gone`, `present`, `prune` skip players with `is_bot`; vote-kick and `Presence` skip bots (they are neither subject nor voter).
- Eliminations: after a hand ends in a solo room, a player with zero chips is removed (bots) or marked out (the human; no `RequestRebuy` accepted in solo: `RoomError` `BAD_REQUEST`); places go to `finish_order` (last in = 1st); several busts in one hand rank by stack at the start of the hand (store `hand_start_chips` in `RoomState` for solo). When one funded player remains, no more hands start and that player is appended with place 1.
- `ServerConfig.bind` is set by the caller; add a helper `ServerConfig::loopback_only(port)` used by the bridge in Task 7.

- [ ] **Step 1: tests (RED), `crates/poker_server_core/tests/bots_room.rs`.** `solo_config_rejected_from_network_create_room`, `solo_requires_virtual_cards_and_bot_range`, `bot_acts_after_think_delay` (think scale 0; the room reaches showdown with only bots and a scripted human who always checks or folds), `bots_never_get_disconnect_timeout_or_sit_out` (advance 11 virtual minutes; no `DisconnectTimeout` or `SetSittingOut` op is produced for a bot), `restored_room_bot_still_acts` (kill the actor mid-hand with a bot to act, `restore`, the bot acts), `paused_room_bot_waits` (no op while paused; one action after resume, never two), `bot_never_in_wire_view` (the serialised room view and every message for a client contain no `isBot` / `is_bot`), `same_name_pool_never_collides_with_human_name`, `places_two_busts_same_hand`, `game_ends_when_human_out_and_when_human_wins`, `rebuy_refused_in_solo`, `next_hand_starts_by_itself`, `illegal_bot_decision_falls_back` (inject a test strategy hook returning an illegal raise: the actor checks or folds and the hand continues), `existing_cards_secrecy_and_leak_tests_still_pass_with_bots_seated` (run `cards_secrecy` and `cards_leak` scenarios with bots added).
- [ ] **Step 2-4:** RED, implement, `cargo test -p poker_server_core` GREEN, whole workspace gates. **Step 5:** commit in two parts: `feat(server-core): seat bots and run their turns from the room actor` and `feat(server-core): solo eliminations, places and loopback-only server`; update `docs/API_AND_EVENTS.md` section 10 (add `finishOrder`).

### Task 6: Simulation with the real actor, battery and soak

**Files:** Create `crates/poker_server_core/tests/bots_sim.rs`.

- [ ] **Step 1: tests (first).** `nine_bot_game_runs_to_a_winner` (human is a scripted caller; think scale 0; the room ends with one player left, chips conserved, `finish_order` complete), `no_polling_when_idle` (with the human to act, the actor's next wake is the human-timer or expiry value, not a bot tick: assert via `next_wake_ms`-visible test hook that no wake sooner than the expiry is scheduled), `soak_one_hundred_games_no_stall` (100 short games with random bots counts and levels; every game finishes; a hard cap on wall time), `decision_time_budget` (median bot decision time on Hard under 5 ms in release, under 20 ms in debug; recorded).
- [ ] **Step 2-4:** RED, fix anything found (real bugs go back to Tasks 2 to 5 as separate fix commits), GREEN. **Step 5:** commit `test(server-core): full solo games with the real actor`.

### Task 7: Bridge and Dart protocol models

**Files:** Modify `packages/poker_bridge/rust/src/api/server.rs` (an API `RsServerHandle::create_solo_room(host_name, config) -> RsCreatedRoom`, or reuse `create_room` with a `solo` config and a `loopback_only` start option on `RsServerConfig`), regenerate FRB files per `docs/DEV_SETUP.md`; `packages/poker_protocol` (`RoomConfig` gains `solo`, `bots`, `botSkill`, `blindLadderHands` with defaults; room view gains `finishOrder`; mappable regen); `app/lib/platform/host_server*.dart` (`hostSolo({hostName, bots, skill, ladderHands})` on the `HostServer` interface; stub throws unsupported); fixtures in `crates/poker_server_core/tests/protocol_fixtures.rs` and the Dart protocol tests.

- [ ] **Step 1: tests (first).** Dart: `room_config_solo_roundtrip`, `old_room_config_json_still_parses`, `finish_order_parses_and_defaults_empty`; Rust: protocol fixture for a solo `CREATE_ROOM` and a view with `finishOrder`; bridge test `solo_server_binds_loopback_only` (the bound address is `127.0.0.1`).
- [ ] **Step 2-4:** RED, implement, regenerate, GREEN (`fvm flutter test` in `packages/poker_protocol`, `packages/poker_bridge`, `app`; `cargo test --workspace`). **Step 5:** commit `feat(bridge): start a loopback-only solo game`.

### Task 8: Session slot, lifecycle pause, setup screen, Home

**Files:** Create `app/lib/pages/solo_setup_page.dart`, `app/lib/provider/solo_provider.dart`; modify `app/lib/platform/token_store*.dart` (`slot` parameter: `hosted` default, `solo`), `app/lib/pages/home_page.dart` ("Play alone" action and "Resume solo game" row), `app/lib/util/strings.dart`, `app/lib/model/app_settings.dart` (personal record map `soloRecords`, serde-safe defaults), `app/lib/main.dart` or the app shell lifecycle observer (pause when backgrounded: send the existing host `Pause` command through the connection, `ResumeGame` on resume, solo only).

**Interfaces:** `SoloSetup { int bots (1..9, default 4), Skill skill (default normal), SoloLength length (quick 6 / standard 8 / long 12) }`; `SoloNotifier.start(SoloSetup)`: `hostSolo`, store the session in the `solo` slot, connect loopback, same as `HostNotifier.start` (reuse its connect code, do not copy it: extract a shared private method if needed). `SoloRecord { games, wins, bestPlace }` keyed `'$skill-${botBucket}'` with buckets 1-3, 4-6, 7-9.

- [ ] **Step 1: tests (first).** widget: `solo_setup_defaults_are_four_normal_standard`, `stepper_clamps_one_to_nine`, `skill_cells_show_caption_for_the_chosen_level`, `start_calls_hostSolo_with_the_chosen_values` (fake `HostServer`), `home_shows_play_alone_and_resume_row_only_when_saved` (two slots independent), `starting_solo_does_not_overwrite_a_hosted_session`, `lifecycle_pauses_and_resumes_a_solo_room_only`; layout: add `SoloSetupPage` to `screens_layout_test` sweep (five sizes, text 1.0/2.0/3.0, both themes, 44 px taps) and `text_scale_test`; goldens `solo_setup_{phone,tablet}_{light,dark}`.
- [ ] **Step 2-4:** RED, implement, GREEN; analyze; web-safe check; look at goldens. **Step 5:** commit `feat(app): play alone setup, saved solo game and pause in the background`.

### Task 9: Solo table, tournament status, eliminations, end screens, record

**Files:** First read `app/lib/pages/player_page.dart`, `table_page.dart`, `widget/table/host_controls.dart`, `model/room_state.dart` and decide per spec 9 which page the solo table reuses (the plan expects `PlayerPage` with every seat on the felt; record the choice in the commit message). Create `app/lib/pages/solo_result_page.dart`, `app/lib/widget/table/blind_status.dart`; modify the chosen table page, `model/room_state.dart` (parse `finishOrder`), strings, `launch`/navigation so solo ends route to the result page.

**Interfaces:** `SoloResult { int place, int of, bool won, List<String> knockedOut, HandSummary? lastHand }` built from `finishOrder`, the player list and the last hand's events (cards and board from the existing virtual-cards events); stats (hands played, hands won, biggest pot, best hand) counted in memory from events. Blind status cell: "Blinds 25/50 · rise in 3 hands" from the engine's blinds and the room's `blindLadderHands` and hand number. Feed lines: "Maya is out (6th)".

- [ ] **Step 1: tests (first).** `solo_table_hides_host_only_controls`, `no_bot_marker_anywhere` (find no widget or semantics label containing "bot" for any seat), `blind_status_counts_down_hands`, `elimination_line_appears_with_place`, `result_page_out_shows_place_and_two_cells` (Play again, Home), `result_page_win`, `result_updates_record_once` (not twice on rebuild), `no_rebuy_cell_in_solo`, `play_again_reuses_settings`, layout sweep and text scale 3.0 for the result page, goldens `solo_table_five_bots_phone_light/dark`, `solo_result_out`, `solo_result_won`.
- [ ] **Step 2-4:** RED, implement, GREEN; goldens inspected. **Step 5:** commit `feat(app): solo table, tournament status and result screens`.

### Task 10: Guide, tour, docs, version, final gates

**Files:** `app/lib/util/guide_content.dart`, `strings.dart` (Guide "Play alone" section, summary line, tour step "Play alone" in `model/walkthrough.dart` / `util/tour_content` as the tours are built); docs: flip ADR-018, ARCHITECTURE 11, GAME_LOGIC 11 (record the tuned constants and measured game lengths), API 10, UI_DESIGN 10, SECURITY 7, RESILIENCE 7, AGENT_CODING_GUIDE Phase 9 and STATUS from "proposed, not built" to built, and record test counts and the measured decision time; bump to **1.3.0+7** (`app/pubspec.yaml`, workspace `Cargo.toml`, `Cargo.lock` via `cargo metadata --offline`).

- [ ] **Step 1: tests.** Guide test: the "Play alone" section exists, folds, and appears in jump chips or Open all; tour test: step count updated and the new step reads; screens layout still green.
- [ ] **Step 2:** implement, regenerate affected goldens (Guide, tour). **Step 3:** run every gate: `fvm flutter analyze && fvm flutter test` (app, `packages/poker_protocol`, `packages/poker_bridge`), `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `bash tool/check_web_safe.sh`, `bash tool/check_no_state_logging.sh`.
- [ ] **Step 4:** build the debug APK (`JAVA_HOME=/home/dimathrj/Documents/android-studio/jbr fvm flutter build apk --debug --target-platform android-x64`) and, with the emulator running, install and play a 4-bot game on Normal end to end (look for stalls, rebuilds, battery: `adb shell dumpsys batterystats` snapshot optional); record in STATUS what was and was not verified. **Step 5:** commit `feat(app): Guide and tour for play alone, version 1.3.0`. Do **not** tag, push `main` or release; offer it to the owner.
