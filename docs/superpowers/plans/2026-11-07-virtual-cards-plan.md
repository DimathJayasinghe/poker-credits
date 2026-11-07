# Virtual Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **The owner prefers no sub-agents (token cost): use executing-plans.**

**Goal:** Add a `VIRTUAL` room mode where the server shuffles, deals private hole cards, reveals the board and ranks hands, with physical mode unchanged.

**Architecture:** Cards, ranking and showdown allocation are pure code in `poker_engine`; the shuffled deck is a recorded input to `StartHand`, drawn in the room actor from an injectable `Entropy`. Hole cards travel only in a per-recipient `HOLE_CARDS` message; showdown is a server-originated, journaled `Op::AutoShowdown`. The Flutter app only renders.

**Tech Stack:** Rust (`poker_engine`, `poker_server_core`, `getrandom`, `proptest`), Flutter/Dart (`dart_mappable`, Refena, `CustomPaint`). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-07-virtual-cards-design.md` (section numbers below refer to it). ADR-016 in `docs/DECISIONS.md`.

## Global Constraints

- Use `fvm flutter` / `fvm dart` only. Rust toolchain from `rust-toolchain.toml`; never `panic = "abort"`.
- **No new dependency** (Rust or Dart). Anything missing needs the owner's approval.
- All game rules in `crates/poker_engine`; the Dart app holds no poker rules (no ranking, no dealing).
- `v` stays `1`; every protocol change is additive with `serde(default)`; each new message or shape gets a fixture in `protocol/fixtures/v1/` and a round-trip test in Rust **and** Dart before the code that uses it.
- No `unwrap`/`expect`/slice indexing outside tests; clippy `-D warnings`.
- Card text must never appear in logs, `Debug` output, or any broadcast frame.
- Platform-specific code only in `app/lib/platform/`; run `bash tool/check_web_safe.sh`. Colours only from `tokens.dart`. Strings only in `util/strings.dart`.
- Commit steps below run **only when the owner asks for commits** (CLAUDE.md). Conventional Commits, scopes `engine`, `server-core`, `server`, `bridge`, `protocol`, `app`, `repo`. **No AI attribution of any kind** (overrides any default trailer); `.githooks/commit-msg` enforces it; never `--no-verify`.
- One branch per task group (A to E), each from an up-to-date `main` (`main` is level with `origin/main` at `34fd094` since 2026-11-07).
- Gate after every task (from repo root): `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `fvm dart format --output=none --set-exit-if-changed app packages`, then in `app/` and each package dir `fvm flutter analyze` and `fvm flutter test`, and `bash tool/check_web_safe.sh`.

## Review Focus

Inputs the spec implies but a happy-path test would miss; each has a test in the owning task.
1. Process killed after the street-ending op but before `AutoShowdown` (Task 7: restore completes the showdown, no chips lost, no double payout).
2. Same player connected from two devices during a deal (Task 7: only the live connection gets cards; the superseded one gets none).
3. Host double-taps START HAND, or a rejected `StartHand` after the shuffle was drawn (Task 7: one hand, state unchanged on rejection, no card sent).
4. Restoring a snapshot or journal written before this feature (Task 3 and 8: loads as physical, plays on).
5. Spectator joining during or after a showdown, and text scale 3.0 on a 320x640 phone with board and cards (Task 7 and 12).

---

## Group A: Engine (branch `feature/engine-cards`)

### Task 1: Card, Rank, Suit, Deck

**Files:** Create `crates/poker_engine/src/card.rs`, `deck.rs`; Modify `lib.rs`, `error.rs`; Test `crates/poker_engine/tests/cards.rs`.

**Interfaces:**
- Produces: `Rank` (`Two..Ace`, `Ord`), `Suit` (`Clubs, Diamonds, Hearts, Spades`), `Card { rank, suit }` with `Display`/`FromStr`/serde as the 2-char string (`"As"`, `"Td"`, `"2c"`), `Copy + Ord`. `Deck::new(order: Vec<Card>) -> Result<Deck, PokerError>` (exactly 52 unique), `Deck::cards(&self) -> &[Card]`, `Deck::standard() -> Deck` (sorted, for tests). New `PokerError::InvalidDeck`.
- `Debug` of `Card` stays normal (it is used in engine tests); redaction is done on the containers in Task 3 and 8.

- [ ] **Step 1: Write failing tests** `card_round_trips_all_52_strings`, `from_str_rejects("1s","Ax","a","Asx","")`, `deck_rejects_51_cards`, `deck_rejects_duplicate`, `deck_accepts_standard`, `serde_json_of_card_is_a_plain_string`.
- [ ] **Step 2: Run** `cargo test -p poker_engine --test cards`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** the types in `card.rs` and `deck.rs` as above; `InvalidDeck` added to `PokerError` and the exhaustive `From<&PokerError> for ErrorCode` in `poker_server_core/src/protocol.rs` (map to `BAD_REQUEST`).
- [ ] **Step 4: Run** the engine and server-core tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(engine): playing cards and a validated deck`.

### Task 2: Hand ranking

**Files:** Create `crates/poker_engine/src/hand_rank.rs`; Modify `lib.rs`; Test `crates/poker_engine/tests/hand_rank.rs`.

**Interfaces:**
- Produces: `HandCategory` (`HighCard, Pair, TwoPair, ThreeOfAKind, Straight, Flush, FullHouse, FourOfAKind, StraightFlush`, `Ord`, serde `SCREAMING_SNAKE_CASE`), `HandRank` (`Ord`, `Eq`; compares category then ordered tie-breaks), `fn best_of(cards: &[Card]) -> Result<HandRank, PokerError>` for 5 to 7 distinct cards, `HandRank::category(&self) -> HandCategory`, `HandRank::best_five(&self) -> [Card; 5]`.

- [ ] **Step 1: Write failing tests:**
  - `five_card_category_counts_match_the_known_table`: enumerate all C(52,5) = 2,598,960 hands; counts equal 40 / 624 / 3,744 / 5,108 / 10,200 / 54,912 / 123,552 / 1,098,240 / 1,302,540 (straight flush incl. royal, quads, full house, flush, straight, trips, two pair, pair, high card). It must run in a plain debug `cargo test --workspace` (no `#[ignore]`, so CI executes it); keep the 5-card scorer allocation-free and, if debug time exceeds 30 s, split the enumeration across `std::thread::scope` workers.
  - `wheel_is_the_lowest_straight_and_loses_to_six_high`; `steel_wheel_is_a_straight_flush`; `royal_flush_beats_king_high_straight_flush`.
  - `kicker_decides_pair_vs_pair`; `board_plays_gives_equal_ranks` (two hands tie when the best five is the board); `suits_never_break_ties`.
  - `seven_card_best_equals_max_over_all_21_subsets` (proptest over random 7-card hands); `suit_permutation_does_not_change_rank` (proptest); `best_five_is_a_subset_of_the_input`.
  - `rejects_fewer_than_five_and_duplicates`.
- [ ] **Step 2: Run** `cargo test -p poker_engine --test hand_rank`. Expected: FAIL.
- [ ] **Step 3: Implement** `best_of` by scoring all 5-card subsets and keeping the max (a packed `u32`: category in the top bits, five 4-bit tie-break ranks below; ace low only inside a straight).
- [ ] **Step 4: Run** `cargo test -p poker_engine --test hand_rank` in debug and note the time. Expected: PASS.
- [ ] **Step 5: Commit** `feat(engine): hand ranking with exhaustive category counts`.

### Task 3: Deal state, StartHand deck, board and reveals

**Files:** Create `crates/poker_engine/src/deal.rs`; Modify `state.rs`, `command.rs`, `machine.rs`, `event.rs`, `lib.rs`; Test `crates/poker_engine/tests/deal.rs`, extend `tests/properties.rs`.

**Interfaces:**
- Consumes: `Card`, `Deck` (Task 1), `Table::seats_after`.
- Produces: `Deal { hand_number: u32, holes: Vec<(PlayerId, [Card; 2])>, board: [Card; 5], board_shown: u8, revealed: Vec<PlayerId>, result: Option<HandResult> }` (keyed by `PlayerId`, never by seat), `HandResult { uncontested: bool, pots: Vec<PotResult> }`, `PotResult { pot_index: u32, amount: Chips, winners: Vec<PlayerId>, shares: Vec<(PlayerId, Chips)> }` (serde camelCase, manual redacted `Debug`); `Table.deal: Option<Deal>` with `#[serde(default)]`; `Command::StartHand { elapsed_ms: u64, #[serde(default)] deck: Option<Deck> }`; `Deal::deal(deck: &Deck, dealt_from_dealer: &[PlayerId], hand_number: u32) -> Deal`; `Deal::visible_board(&self) -> &[Card]`; `Deal::hole_of(&self, &PlayerId) -> Option<[Card; 2]>`. `Event::BoardRevealed { cards: Vec<Card> }` and `Event::HandsRevealed { players: Vec<PlayerId> }` (no hole cards in events beyond what is revealed publicly).

- [ ] **Step 1: Write failing tests:** `deal_gives_two_cards_per_live_seat_in_order_from_the_button`; `no_card_is_dealt_twice`; `physical_start_hand_leaves_deal_none`; `board_shown_is_0_3_4_5_by_street`; `runout_shows_all_five_and_reveals_all_contenders`; `hand_won_on_the_flop_keeps_three_board_cards_and_reveals_nobody`; `deal_survives_a_json_round_trip`; `undo_restores_deal_with_the_phase`; `result_lists_each_pot_winner_and_shares_summing_to_the_pot`; `uncontested_result_pays_every_pot_to_the_single_contender_and_reveals_nobody` (several pot tiers are possible); `hole_cards_follow_the_player_after_move_seat`; `new_player_in_a_freed_seat_gets_no_cards_from_the_last_hand`; `result_names_stay_right_after_a_seat_swap_or_removal`; `game_winning_hand_keeps_its_result_in_lobby`; `split_pot_result_shows_the_odd_chip_holder`; `start_hand_with_a_bad_deck_is_rejected_and_state_unchanged`; `old_start_hand_json_without_deck_deserializes`; `old_table_json_without_deal_deserializes`; `debug_output_of_deal_contains_no_card`.
- [ ] **Step 2: Run** `cargo test -p poker_engine`. Expected: FAIL.
- [ ] **Step 3: Implement** in `machine.rs`: `start_hand` creates the deal when `deck` is `Some` (seats `Live` after blinds setup, dealing order from `seats_after(dealer)`); `next_street` sets `board_shown` 3/4/5; `enter_runout` and `enter_showdown` set it to 5 and fill `revealed` with contesting seats when two or more contest; `finish_uncontested` reveals nothing; the deal is kept after `end_hand` and replaced **only** by the next `start_hand`, whatever the phase (including `Lobby`).
- [ ] **Step 4: Extend** the existing proptests so random command sequences include virtual hands: chips conserved, rejected commands never mutate, accept-and-replay through a JSON snapshot gives the identical state. Run `cargo test -p poker_engine` (PROPTEST_CASES=2000 once). Expected: PASS.
- [ ] **Step 5: Commit** `feat(engine): deal, board reveal and showdown reveals for virtual hands`.

### Task 4: Showdown allocations

**Files:** Create `crates/poker_engine/src/showdown.rs`; Modify `lib.rs`; Test `crates/poker_engine/tests/showdown.rs`.

**Interfaces:**
- Consumes: `best_of`, `Table.deal`, `PotTier`.
- Produces: `fn allocations(table: &Table) -> Result<Vec<Allocation>, PokerError>` (one per pot, winners = best rank among `eligible` contenders; ties list all); `fn reveals(table: &Table) -> Vec<Reveal>` with `Reveal { player_id: PlayerId, cards: [Card; 2], category: HandCategory, best_five: [Card; 5] }` for `deal.revealed`.

- [ ] **Step 1: Write failing tests:** `best_hand_wins_the_main_pot`; `tie_splits_and_odd_chip_goes_clockwise_from_the_button` (feed the result to `apply(ResolveShowdown)` and assert stacks); `side_pot_can_have_a_different_winner_than_the_main_pot`; `short_stack_wins_only_the_pot_it_is_eligible_for`; `three_way_tie_on_board`; `allocations_are_accepted_by_resolve_showdown_for_random_virtual_hands` (proptest: always `Ok`, chips conserved); `errors_when_deal_is_none`.
- [ ] **Step 2: Run** `cargo test -p poker_engine --test showdown`. Expected: FAIL.
- [ ] **Step 3: Implement** both functions, no I/O, sorted deterministic output.
- [ ] **Step 4: Run** the full engine suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat(engine): showdown winners from hand ranks`.

---

## Group B: Server core (branch `feature/server-cards`, after A)

### Task 5: Entropy and shuffle

**Files:** Create `crates/poker_server_core/src/cards.rs`; Modify `lib.rs`; Test `crates/poker_server_core/tests/cards_shuffle.rs`.

**Interfaces:**
- Produces: `trait Entropy: Send { fn fill(&mut self, buf: &mut [u8]); }`, `struct OsEntropy` (`getrandom`; on failure return an error to the caller instead of panicking, so `fill` returns `Result<(), EntropyError>`), `struct FixedEntropy` (cycles a byte script), `fn shuffled_deck(entropy: &mut dyn Entropy) -> Result<Deck, EntropyError>` (Fisher-Yates with rejection sampling, no modulo bias).

- [ ] **Step 1: Write failing tests:** `shuffle_is_always_a_valid_deck`; `same_script_gives_same_order`; `rejection_sampling_skips_biased_values` (script that first yields out-of-range bytes); `position_distribution_is_flat` (seeded, 52k shuffles, each card in each of 52 positions within 6 sigma); `entropy_failure_is_an_error_not_a_panic`.
- [ ] **Step 2: Run** `cargo test -p poker_server_core --test cards_shuffle`. Expected: FAIL.
- [ ] **Step 3: Implement** as above.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(server-core): injectable entropy and unbiased shuffle`.

### Task 6: Protocol, config, fixtures

**Files:** Modify `protocol.rs`, `config.rs`, `room/state.rs` (`RoomConfig.card_mode`), `net/http.rs`; Create fixtures `protocol/fixtures/v1/` for `HOLE_CARDS`, a virtual `RoomView` (board, reveals, hasCards), `JOIN_ROOM` and `RESUME` with `features`, `ERROR` `UPDATE_REQUIRED`; Modify the API doc error table (section 6); Test `crates/poker_server_core/tests/protocol_fixtures.rs`.

**Interfaces:**
- Produces: `CardMode { Physical, Virtual }` (default Physical), `RoomConfig.card_mode`, `ServerMessage::HoleCards { hand_number: u32, cards: [Card; 2] }`, `RoomView.board: Vec<Card>`, `RoomView.reveals: Vec<RevealView>`, `RoomView.result: Option<HandResultView>` (`HandResultView { uncontested, pots: Vec<PotResultView { pot_index, amount, winner_player_ids, shares: Vec<ShareView { player_id, amount }> }> }`), `SeatView.has_cards: bool` (all `serde(default)`), `ClientMessage::JoinRoom/Resume.features: Vec<String>` (default empty), `ErrorCode::UpdateRequired`, `cardMode` on `/v1/room/{code}` and each `/v1/lobbies` entry.

- [ ] **Step 1: Write failing tests:** every new fixture round-trips; `a_message_without_the_new_fields_still_parses`; `every_message_type_has_a_fixture` (existing check) stays green; docs error list equals `ErrorCode` (existing check) includes `UPDATE_REQUIRED`.
- [ ] **Step 2: Run** `cargo test -p poker_server_core --test protocol_fixtures`. Expected: FAIL.
- [ ] **Step 3: Implement** types and endpoints; `card_mode` is rejected by `CONFIGURE`.
- [ ] **Step 4: Run** the crate tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(server-core): card mode, hole cards message and view fields`.

### Task 7: Reducer and actor behaviour

**Files:** Modify `room/state.rs`, `room/ops.rs`, `room/view.rs`, `room/actor.rs`, `room/handle.rs`, `registry.rs`, `lib.rs`; Test `crates/poker_server_core/tests/cards_flow.rs`.

**Interfaces:**
- Consumes: `shuffled_deck`, `Entropy`, `showdown::allocations/reveals`, `Command::StartHand.deck`.
- Produces: actor `Deps { clock, entropy: Box<dyn Entropy> }` (default `OsEntropy`; tests inject `FixedEntropy` through `ServerConfig` behind the existing `test-hooks` pattern); `HostCommand::StartHand { deck: Option<Deck> }` (journaled); `Op::AutoShowdown { allocations: Vec<Allocation>, at_ms: u64 }` (origin server only, virtual rooms only); `RoomState::hole_cards_for(&self, player_id: &str) -> Option<ServerMessage>` (looks up by player id), `RoomState.hand_names: BTreeMap<String, String>` (display names captured when the hand is paid, cleared at the next start); `RoomState::needs_auto_showdown(&self) -> bool`.

- [ ] **Step 1: Write failing tests** (actor-level with plain channels, paused clock, `FixedEntropy`):
  - `start_hand_sends_hole_cards_only_to_each_owner`; `spectator_never_receives_hole_cards`; `state_update_never_contains_hole_cards`.
  - `resume_resends_hole_cards_after_the_snapshot`; `superseded_connection_gets_no_cards` (Review Focus 2).
  - `all_in_runout_resolves_automatically_and_pays_by_rank`; `uncontested_hand_reveals_nothing`; `split_pot_with_odd_chip_over_the_actor`.
  - `host_begin_showdown_and_resolve_are_illegal_state_in_virtual_rooms`; `physical_room_manual_showdown_still_works`.
  - `undo_is_allowed_within_a_street_and_refused_across_streets_and_after_showdown`.
  - `double_start_hand_deals_once` and `rejected_start_hand_changes_nothing_and_sends_no_cards` (Review Focus 3).
  - `restore_between_street_end_and_auto_showdown_completes_the_hand` (Review Focus 1: kill the actor after the ending op, restore, assert phase `NextHandPrep`, chips conserved, paid once).
  - `card_mode_cannot_be_changed_by_configure`; `virtual_room_refuses_client_without_feature_with_update_required`.
  - `late_spectator_sees_board_and_reveals_of_the_last_hand` (Review Focus 5); `snapshot_after_the_hand_carries_result_reveals_and_board`; `result_stays_until_the_next_start_hand`.
  - `client_sent_start_hand_with_deck_field_is_ignored`: a wire `START_HAND` carrying a `deck` field is parsed without it and the actor always draws its own deck, so a host cannot stack the deck.
- [ ] **Step 2: Run** `cargo test -p poker_server_core --test cards_flow`. Expected: FAIL.
- [ ] **Step 3: Implement.** Shuffle in the actor before building the `Op`; `view()` reads only `deal.visible_board()` and `reveals`; `send_snapshot` re-sends `HOLE_CARDS` after the turn prompt; after each applied op the actor checks `needs_auto_showdown` and submits `Op::AutoShowdown`; `Op::Recover` does the same; manual showdown host commands return `ILLEGAL_STATE` when `card_mode == Virtual`; the undo rule compares the previous table's phase to the current one.
- [ ] **Step 4: Run** the whole crate. Expected: PASS, existing suites unchanged.
- [ ] **Step 5: Commit** `feat(server-core): virtual rooms deal, reveal and resolve showdown`.

### Task 8: Secrecy hardening and system tests

**Files:** Modify `store/snapshot.rs`, `store/journal.rs`, `room/state.rs` (redacted `Debug` for the deal-carrying `Op`), `tool/` (grep lint); Test `tests/cards_leak.rs`, `tests/cards_replay.rs`, extend the hostile-input fuzz test and `tests/replay_property.rs`.

**Interfaces:** Consumes everything from Task 7. Produces nothing new for later tasks except the test helpers `record_frames(conn) -> Vec<String>`.

- [ ] **Step 1: Write failing tests:**
  - `no_leak_oracle`: run many random virtual hands (4 to 10 players, spectators, reconnects, folds, all-ins, **seat moves, new joins into freed seats and removals between hands**), capture every outbound frame per connection, fail if any card string of another player's hole cards appears before that seat is in `reveals`.
  - `debug_of_room_state_and_ops_contains_no_card`.
  - `snapshot_and_journal_files_are_0600_and_folder_0700` (unix only).
  - `replay_equals_live_for_virtual_rooms_with_forced_all_in_runouts`.
  - `old_snapshot_and_journal_from_before_cards_restore_as_physical` (Review Focus 4; use a committed pre-feature fixture file).
  - `fuzz_virtual_room_hostile_frames_never_panic_or_leak`.
  - `bridge_events_carry_no_room_data` (in `poker_bridge`).
- [ ] **Step 2: Run** `cargo test --workspace`. Expected: FAIL.
- [ ] **Step 3: Implement** redactions, permissions (`OpenOptions` with `mode(0o600)` under `cfg(unix)`; `create_dir_all` then set `0o700`), and a `tool/check_no_state_logging.sh` grep for `?op`, `?state`, `{:?}` of `RoomState` in `tracing` calls, wired into `.githooks/pre-commit` and CI.
- [ ] **Step 4: Run** the full gate with `PROPTEST_CASES=1000`. Expected: PASS.
- [ ] **Step 5: Commit** `test(server-core): no-leak oracle, replay and secrecy checks for virtual rooms`.

---

## Group C: Dart protocol and bridge (branch `feature/protocol-cards`)

### Task 9: Models and bridge config

**Files:** Create `packages/poker_protocol/lib/src/card.dart`; Modify `room_config.dart`, `room_view.dart`, `server_message.dart`, `client_message.dart`, `error_code.dart`, `packages/poker_bridge/rust/src/api/server.rs` and the generated bridge files, `app/lib/platform/host_server_io.dart` (`_toBridge`), `app/lib/model/hosting.dart` (`defaultRoomConfig`), `app/test/support/fakes.dart`; Test `packages/poker_protocol/test/fixtures_test.dart`, `card_test.dart`.

**Interfaces:**
- Produces: `Card` (`rank`, `suit`; `Card.parse(String)`, `toString()` = wire form), `CardMode { physical, virtual }`, `HoleCards(handNumber, cards)` server message, `RoomView.board`, `RoomView.reveals` (`Reveal(seatIndex, playerId, cards, category, bestFive)`), `RoomView.result` (`HandResult`, `PotResult`, `Share`), `SeatView.hasCards`, `JoinRoom/Resume.features`, `ErrorCode.updateRequired`, `RoomConfig.cardMode`.

- [ ] **Step 1: Write failing tests:** all new fixtures decode and re-encode to identical JSON; `unknown_card_strings_are_rejected_safely`; `card_parse_round_trips_52`; `room_config_without_card_mode_defaults_to_physical`.
- [ ] **Step 2: Run** in `packages/poker_protocol`: `fvm flutter test`. Expected: FAIL.
- [ ] **Step 3: Implement** models; run `dart run build_runner build` in the package; add `cardMode` to the bridge config and regenerate with `flutter_rust_bridge_codegen generate` (then `git checkout .fvmrc .gitignore`, `cargo fmt --all`, per `STATUS.md`).
- [ ] **Step 4: Run** all package tests and `cargo test -p poker_bridge`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(protocol): card models, hole cards message and card mode`.

---

## Group D: App (branch `feature/app-cards`, after C)

### Task 10: Card widgets, tokens, settings, state

**Files:** Create `app/lib/widget/cards/{playing_card,card_row,board_view,hole_cards_dock,showdown_panel}.dart`; Modify `theme/tokens.dart`, `util/strings.dart`, `model/app_settings.dart`, `model/room_state.dart`; Test `app/test/widget/cards_gallery_golden_test.dart`, `app/test/model/room_state_test.dart`, `app/test/theme/contrast_test.dart`.

**Interfaces:**
- Produces: `PlayingCard({Card? card, CardSize size, bool dim, bool lifted})` (`null` card = back), `CardSize { hero, board, mini }`, `CardRow`, `BoardView(List<Card> shown, int slots = 5)`, `HoleCardsDock({HoleCards? cards, bool faceUp, bool pressToPeek = false, VoidCallback onToggle})`, `ShowdownPanel({List<Reveal> reveals, HandResult? result, List<Card> board, Map<String,String> names, ValueChanged<String>? onOpen})`; `RoomState.holeCards: HoleCards?`; `AppSettings.fourColourDeck`, `AppSettings.cardsFaceUp` (default false); token names `cardFace`, `cardBack`, `suitRed`, `suitBlack`, `suitGreen`, `suitBlue`; strings for the nine hand categories and card names ("Ace of spades").

- [ ] **Step 1: Write failing tests:** `hole_cards_survive_a_snapshot`; `a_higher_hand_number_replaces_hole_cards`; `lobby_view_clears_hole_cards`; `duplicate_hole_cards_are_a_no_op`; `stale_hole_cards_are_not_shown_after_a_new_deal` (cards render only when `holeCards.handNumber == view.handNumber`, except during `NextHandPrep` of that same hand; between the hand-N `STATE_UPDATE` and its `HOLE_CARDS` the dock shows backs); `card_semantics_label_reads_ace_of_spades`; `back_has_semantics_face_down_card`; gallery goldens (faces, backs, three sizes, both themes, four-colour deck, dimmed and lifted); contrast test covers the new tokens in both themes; `reduced_motion_flip_has_zero_duration`.
- [ ] **Step 2: Run** in `app/`: `fvm flutter test test/model test/widget test/theme`. Expected: FAIL.
- [ ] **Step 3: Implement** widgets as `CustomPaint` with cached suit `Path`s and a `RepaintBoundary`; rank in Anton; flip is an X-scale squash through `BrutalTheme.duration`; `BrutalPressable` for the dock tap; hide on `AppLifecycleState.paused` and on a new hand number.
- [ ] **Step 4: Run** analyze, tests, `check_web_safe.sh`; regenerate goldens with `--update-goldens`, inspect them visually. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): playing card widgets, tokens and hole card state`.

### Task 11: Host setup and Join

**Files:** Modify `app/lib/pages/host_page.dart`, `join_page.dart`, `widget/...` lobby list tile, `net/` join request (`features: ['VIRTUAL_CARDS']`), `util/strings.dart`; Test `app/test/pages/host_page_test.dart`, `join_page_test.dart`.

**Interfaces:** Consumes `CardMode`, `RoomConfig.cardMode`. Produces: `features: ['VIRTUAL_CARDS']` on **every** `JOIN_ROOM` and `RESUME` the shared `RoomClient` sends (guest join, guest resume, and the host's own loopback `RESUME`); host form field `cardMode` in the `RoomConfig` it builds; a `VIRTUAL` `BrutalTag` on lobby entries and the found-room card; error text for `ErrorCode.updateRequired`.

- [ ] **Step 1: Write failing tests:** `host_form_defaults_to_real_cards`; `choosing_virtual_sends_card_mode_virtual`; `join_sends_virtual_cards_feature`; `host_loopback_resume_carries_virtual_cards_feature` (the host must never get `UPDATE_REQUIRED` from its own room); `join_page_tags_virtual_games`; `update_required_shows_update_message_and_allows_retry`; text-scale 3.0 and 320x640 no-overflow for the new cell.
- [ ] **Step 2: Run** `fvm flutter test test/pages`. Expected: FAIL.
- [ ] **Step 3: Implement** the "CARDS" cell with `BrutalSegmented` and a plain line per option, including the trust note for host mode (spec 9.4).
- [ ] **Step 4: Run** the gate; update goldens. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): choose card mode when hosting and show it when joining`.

### Task 12: Player screen for virtual rooms (guests)

**Files:** Modify `app/lib/pages/player_page.dart`, create `widget/player/opponent_strip.dart`; Test `app/test/pages/player_virtual_test.dart`, goldens, extend `text_scale_test.dart`.

**Interfaces:** Consumes Task 10 widgets and `RoomState`. Produces `OpponentStrip(List<SeatView>, {String? mePlayerId, List<Reveal> reveals})`.

- [ ] **Step 1: Write failing tests:** `virtual_player_shows_board_pot_strip_and_face_down_cards`; `tapping_the_dock_flips_the_cards_and_tapping_again_hides_them`; `cards_hide_when_the_app_pauses`; `cards_hide_on_a_new_hand`; `raise_sheet_does_not_cover_board_or_cards`; `physical_player_page_is_unchanged` (existing goldens untouched); `showdown_panel_lists_every_revealed_hand_and_tapping_a_row_shows_that_hand_large`; `showdown_panel_marks_winners_and_lists_each_pot_with_shares`; `uncontested_result_shows_winner_and_everyone_else_folded_without_cards`; `showdown_highlights_best_five_and_dims_losers`; `showdown_panel_scrolls_at_text_scale_3`; `no_overflow_at_text_scale_3_on_320x640` (Review Focus 5); goldens for waiting, my turn, face-up, raise sheet, showdown at 390x844, 1280x800, 1920x1080.
- [ ] **Step 2: Run** `fvm flutter test test/pages`. Expected: FAIL.
- [ ] **Step 3: Implement** the layout of spec 3.1; the page scrolls as a whole at large text; haptic light tap on deal and flip via `util/haptics.dart`.
- [ ] **Step 4: Run** the gate; inspect goldens. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): player screen for virtual cards`.

### Task 13: Table, Spectator, seated host and host controls

**Files:** Modify `widget/table/{felt_layout,seat_plate,host_controls}.dart`, `pages/table_page.dart`; Test extend `table_layout_test.dart`, `table_golden_test.dart`, `text_scale_test.dart`.

**Interfaces:** Consumes `BoardView`, `PlayingCard(mini)`, `ShowdownPanel`, `HoleCardsDock` (new `pressToPeek` mode for wide screens, added to Task 10's widget). Produces `FeltLayout.board` slot, `SeatPlate.cards` parameter, and the dock slot above the host controls on `TablePage`.

- [ ] **Step 1: Write failing tests:** `table_shows_board_under_the_pot_by_street`; `dealt_seats_show_a_mini_card_back_pair`; `showdown_shows_hand_names_and_winner`; `spectator_sees_showdown_panel_with_all_revealed_hands`; `reconnecting_client_shows_the_panel_from_the_snapshot`; `virtual_host_controls_hide_begin_showdown_and_resolve`; `undo_cell_explains_when_disabled`; `seated_host_on_a_phone_sees_the_dock_face_down_and_can_tap_to_look`; `seated_host_on_a_wide_screen_sees_cards_only_while_pressed`; `host_start_hand_is_disabled_until_the_runout_animation_ends`; `host_phone_table_scrolls_as_a_whole_at_text_scale_3_on_320x640`; `layout_never_overlaps_with_board_and_ten_mini_pairs_at_7_sizes_text_1_and_2`; `spectator_never_shows_hole_cards`; goldens for lobby, preflop, flop, showdown in virtual mode.
- [ ] **Step 2: Run** `fvm flutter test test/pages`. Expected: FAIL.
- [ ] **Step 3: Implement**, keeping the oval/grid choice driven by the space actually available (`ovalFits` accounts for the taller plate).
- [ ] **Step 4: Run** the gate; inspect goldens. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): table board, mini cards and automatic showdown`.

---

## Group E: Finish (branch `feature/cards-release`)

### Task 14: Polish, device run, docs, release prep

**Files:** Modify `app/lib/pages/settings_page.dart` (two switches), `pages/guide_page.dart` (virtual mode note), `app/pubspec.yaml` version, `docs/STATUS.md`, `docs/GAME_LOGIC_AND_RULES.md`, `docs/API_AND_EVENTS.md`, `docs/UI_DESIGN.md`, `README.md`; Create `docs/RELEASE_CHECKLIST.md` if the owner wants it.

- [ ] **Step 1: Write failing tests:** `settings_has_four_colour_and_face_up_switches_persisted`; `runout_reveals_cards_one_at_a_time_on_the_client` (fake async); `reduced_motion_shows_all_cards_instantly`.
- [ ] **Step 2: Implement** settings, runout pacing (700 ms apart, client side only), winner lift, deal slide; Android `FLAG_SECURE` on the Player page in virtual rooms **only if the owner approves the stretch** (spec 8).
- [ ] **Step 3: Device run.** Emulator (headless, per `STATUS.md`): scripted bot host in a virtual room; join by room code; deal; fold; raise; all-in runout; showdown; kill the app mid-hand and resume; confirm cards return. Real two-phone Wi-Fi test is the owner's.
- [ ] **Step 4: Docs.** Turn the "planned" sections into present tense (GAME_LOGIC 10, API 9, ARCHITECTURE 10, UI_DESIGN 8, RESILIENCE 6, SECURITY 6.5.1, ADR-016 status to Accepted if the owner agreed), update `STATUS.md`, bump the app to 1.1.0.
- [ ] **Step 5: Full gate** (section 5 of the agent guide, plus `cargo test --release` for the exhaustive hand counts). Report real output. Commit `chore(repo): virtual cards 1.1.0` only when the owner asks.

---

## Self-review notes
- Spec coverage: 3.1 Task 12; 3.2 Task 13; 3.3/3.4 Task 11; 4 Task 10 and 14; 5.1/5.2 Tasks 1 to 4; 5.3 Tasks 5 to 7; 5.4 Task 6 and 9; 5.5 Tasks 9, 10; 6 (cloud readiness) is satisfied by design and has no code task, covered by the entropy injection (Task 5) and `features`/`cardMode` negotiation (Tasks 6, 11); 7 Tasks 3, 7; 8 Review Focus plus Tasks 7, 8, 12; 9 Tasks 7, 8; 10 spread over all tasks; 11 no task needed (benchmarks are not required); 13 nothing built by design.
- Names checked: `Deal`, `HoleCards`, `Reveal`, `CardMode`, `Entropy`, `Op::AutoShowdown`, `needs_auto_showdown`, `hole_cards_for` are used with the same spelling in every task.
