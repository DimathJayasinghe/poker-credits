# Single Player Mode with Bots: Design

Status: **APPROVED by the owner 2026-11-07 (suggestions in section 10 accepted; bounties, daily challenges, chat and achievements are out for this stage). Nothing is built yet; next is the plan.** Date: 2026-11-07. Author: assistant, from the owner's conversation. Owner decisions (2026-11-07): **no rebuy, losing ends the game with an end screen** (rebuys would make the game boring because the player never gets defeated); **bots look exactly like real players, no bot tag**; **1 to 9 bots**. The owner asked for suggestions to keep play interesting: section 10. Calls marked **(my call)** were made by the assistant; the owner can change any of them. Building starts only when the owner approves this document, then comes the plan (`superpowers:writing-plans`). Target release: **1.3.0** (the unreleased 1.2.1 rolls into it; the owner has said no release until the bigger feature is done).

## 1. Intent

The owner wants to open the app alone, choose how many computer players to sit with and a skill level, and play a full game of Texas Hold'em. In the owner's words: it must **feel like playing real players**, it must be **fair**, the bots must **account for each other's and the human's behaviour and adapt**, they must **not feel like clones**, the UI may need changes, and the app must stay **efficient: not resource hungry, no battery drain**.

Why: the app is useless without friends in the room. A solo mode makes it a game people open on their own, teaches new players (the Learn poker lesson ends at a real table), and tests the whole stack on every device without a second phone.

## 2. Goals, non-goals, anti-goals

**Goals**
- Pick 1 to 9 bots (owner decision; the engine allows 10 seats) and a skill level (Easy, Normal, Hard) on a setup screen, then play.
- Bots play legal, believable poker with their own style, and change how they play against each opponent as they learn that opponent's habits.
- Fairness a reader can verify in code and tests (section 5).
- Near-zero cost when idle and small cost per decision (section 8).
- A real game with stakes: a **tournament** that you can lose (section 10), with rising blinds, eliminations, a finishing place and an end screen.
- Runs fully offline, works after an app restart (the room is journaled like any other).
- All rules stay in Rust (`crates/poker_engine`); bot strategy is Rust too. Dart holds no poker rules and no bot logic.

**Non-goals**
- No money, no settlement, no leaderboards, no online play, no accounts.
- No solver, no trained model, no big lookup tables (binary size and battery). Heuristics and Monte Carlo only.
- No bots in LAN or cloud rooms in this release. (A later "fill empty seats" feature would reuse the same crate.)
- No chat, emotes, hints or coaching in this release.
- No adaptive difficulty that changes mid-game; the level is fixed when the game starts.

**Anti-goals (a failure even if it technically works)**
- A bot that ever uses information a human at its seat could not have.
- Bots that look identical, or whose play is trivially exploitable by one trick.
- A solo game that keeps the CPU, radio or GPU busy while nothing is happening.
- Bot logic that makes a hand stall (a bot must always act, at the latest by falling back to check or fold).

## 3. How it fits the existing design

Single player is a **hosted game on the player's own device** with some seats filled by bots. Nothing new is needed for the table, betting, pots, virtual cards, showdown, journal or resume. The new parts are:

| Part | Where | New or changed |
| :--- | :--- | :--- |
| Strategy, opponent notes, personalities, skill | new crate `crates/poker_bots` | new, pure Rust, no async, no I/O |
| Seating bots, scheduling their actions, exempting them from presence rules | `crates/poker_server_core` (`room/bots.rs`, `actor.rs`, `absence.rs`, `state.rs`) | new module, small hooks |
| Room config: bots count, skill, solo flag | `protocol.rs` `RoomConfig` | new optional fields |
| Starting a solo game over the bridge | `packages/poker_bridge` (FRB) | one new API call |
| Setup screen, table layout, pause on background, end screens | `app/lib` | new screen and small changes |

### 3.1 Where bots run (my call)
**Inside the room actor.** A bot is a seated player with no connection. It is not a fake WebSocket client: sockets would cost threads, wakeups and the per-connection rate limit. In `actor.rs` the bot's "think deadline" is one more candidate in `next_wake_ms`, and `run_due` submits the bot's action as an ordinary `Op::Action`, the same way it submits `Op::Timeout`. When no bot is due, the actor sleeps exactly as it does today. If the strategy returns an error or an illegal action, the actor submits check (when free) or fold, and logs a warning; a hand never stalls.

### 3.2 Bots and absence (must not be missed)
`Absence::new` marks every seated player as absent because nobody is connected after a restart, and `due_op` then plays `DisconnectTimeout` for them after the grace period and `SetSittingOut` after ten minutes. A bot never connects, so unless exempted it would be folded and sat out. Rules:
- Bots are **never** in the absence map; `Absence::new`, `gone`, `present` and `prune` skip any player whose `is_bot` is set.
- Bots are not eligible for vote-kick and cannot vote.
- A bot never needs a turn timeout: the human's turn timer applies only to humans.
- Tests: a restored solo room with bots at the head of a hand still has the bots act; a ten-minute pause never sits a bot out.

### 3.3 Identity of bots
A bot is a `Player` with `is_bot: true` (internal only, never sent to clients), a generated id (`bot-1`, ...), a name from a pool of 40 plain first names (**my call**, no jokes, so they read as people), a seat and a stack. It has no token and no session. It is journaled in with a new op `Op::AddBot { id, name, seat, chips, personality }`; the personality is stored in the journal so a restored room has the same bots.

## 4. Strategy design (`crates/poker_bots`)

### 4.1 Inputs and outputs
```
decide(view: &BotView, mind: &mut BotMind, rng: &mut BotRng) -> Decision
Decision { action: PlayerAction, think_ms: u32 }
```
`BotView` is everything one seat may know (section 5.1). `BotMind` is that bot's private state: personality, skill, opponent notes, a little mood. `BotRng` is a small PRNG (section 4.6).

### 4.2 Hand strength
- **Preflop:** a 169-entry table (pairs, suited and offsuit combinations) giving a strength 0 to 1, built into the code as a `const` array of `u8` (169 bytes). Position (seats from the button) and the number of players shift the playable range.
- **Postflop:** Monte Carlo equity against the number of live opponents: deal random hands to the opponents and random remaining board cards from the cards the bot cannot see, count wins and ties using the engine's existing 7-card ranker. The sample count depends on skill (Easy 0: uses made-hand tier only; Normal 120; Hard 400). A hard cap of 400 samples and a time check make the cost bounded (section 8).
- The unseen-card set is computed from the view (52 minus own cards minus board), never from the real deck, so equity cannot be contaminated by hidden information.

### 4.3 Decision
From equity, pot odds, stack-to-pot ratio, position and street, compute a base action (fold, check, call, raise to X) with these personality-weighted adjustments:
- **Bluff:** with low equity and a good spot (few opponents, opponent folds often to this bot, scary board) the bot bets or raises at a rate set by its bluff parameter.
- **Slow-play and trap:** strong hands sometimes check or just call, at a rate set by a trap parameter.
- **Bet sizing:** each bot has a size habit (small, pot-ish, large) with jitter; sizes are rounded to the table's chip unit and clamped to legal min and max.
- **Errors:** skill sets an error rate. Easy sometimes calls too much and rarely folds a mid hand to a big bet; Hard errors rarely and mostly by mixing actions.

### 4.4 Skill levels (what the owner picks at the start)

| | Easy | Normal | Hard |
| :--- | :--- | :--- | :--- |
| Hand strength | preflop table plus made-hand tier | 120 samples postflop | 400 samples postflop |
| Opponent reads | none (plays its personality) | slow: needs about 25 observations of a player to lean on a stat, small shifts | fast: about 10 observations, larger shifts, exploits fold and call tendencies |
| Mistakes | frequent (calls too wide, misses value, rare bluffs) | occasional | rare, mostly deliberate mixing |
| Pot-odds discipline | loose | sound | tight |

The same information is available at every level; the levels differ only in how well the bot uses it. Hard never gets extra information (section 5). The three levels are tuned by simulation (section 11), not by hand-waving.

### 4.5 Opponent notes and adaptation
Each `BotMind` keeps, **for every other player, including the human and the other bots**, a small struct of counters updated once per public action:
- hands seen, voluntarily put chips in preflop (VPIP), raised preflop (PFR);
- postflop bets/raises versus calls versus checks (aggression), continuation bet and fold-to-bet counts, fold-to-raise count;
- showdown evidence: how often hands shown were weak after aggressive play (bluff frequency), average bet size relative to the pot.

Stats are smoothed (a prior from a typical player, weight grows with observations) so one hand never swings a read. The bot uses them like this: widen bluffs against opponents who fold too much, value-bet thinner against calling stations, respect raises from tight-aggressive opponents, tighten against a wild player who is already in the pot, and trap players who bet on any weak signal. The strength of every shift is set by the skill level (section 4.4). Notes are **not** shared between bots: each bot's reads come only from its own seat's view, and no bot learns anything another bot saw privately (there is nothing private to share, section 5).

Cost: a few `u16` counters per opponent, updated once per action; no history list is kept (O(1) memory per opponent).

**After a restore (my call):** notes are reset and the bots rebuild reads from new hands. Rebuilding by replaying the public journal would work but costs restore time and code for a small gain; a restored game is rare and the reset is invisible (reads need a few hands anyway). Personality and skill are restored (they are in the journal).

### 4.6 Randomness (no new dependency)
`rand` is not on the approved list (`AGENT_CODING_GUIDE.md` section 6) and is not added. `BotRng` is a hand-written 64-bit generator (splitmix64 seeding xoshiro256**-style or just splitmix64, about 15 lines), seeded per bot from the existing `getrandom` entropy at creation, and held in memory. The seed is **not** journaled: bot actions are journaled as normal player actions, so replay never reruns bot logic or randomness. Tests inject a fixed seed.

### 4.7 Personalities: bots must not feel like clones
Each bot samples a personality at creation from one of six archetypes plus per-parameter jitter, so even two "tight-aggressive" bots differ:

| Archetype | Feel |
| :--- | :--- |
| Rock | very tight, rarely bluffs, big value bets |
| Tight-aggressive (TAG) | solid, raises or folds, few calls |
| Loose-aggressive (LAG) | many pots, lots of raises and bluffs |
| Calling station | loose, calls too much, rarely raises |
| Maniac | extreme aggression, wild sizing |
| Nit-trapper | tight, slow-plays strong hands, hides strength |

Parameters: `looseness` (range width), `aggression` (raise versus call), `bluff`, `trap`, `size_habit`, `tilt` (how much a big loss loosens it for a few hands: a mood value that decays; **my call: included**, it is cheap and the largest "feels human" gain), `think_speed`, `read_weight` (how much it trusts its reads, capped by skill). The table is built so the bots seated together differ: when sampling, the archetype of each new bot is chosen to avoid duplicating one already seated (until all six are used).

### 4.8 Thinking time (feels real)
`think_ms` is a base plus noise: instant for a clear fold or check (400 to 900 ms), longer for close decisions (1.2 to 3.5 s) and for big bets, with each bot's `think_speed` shifting it, and a small chance of a quick snap decision. It is only a timer in the actor's wake logic, never a busy wait. For tests and the CPU-only mode `Timings` has `bot_think_scale` (default 1.0, tests set 0).

## 5. Fairness (owner requirement, enforced by types and tests)

### 5.1 What a bot may see (`BotView`)
Only: its own two cards; the board; pot and side pots; every stack and bet this street; who has folded; seat positions, the button and blinds; legal actions and the minimum raise; the public action history of the current hand; and **hands revealed at showdown** (for notes). It is a struct built for one seat by a function in `room/bots.rs`.

### 5.2 What it never sees
`RoomState`, the deck, the undealt cards, other players' hole cards (except as revealed at showdown), other bots' personality or notes, or the human's session. `poker_bots` does not depend on `poker_server_core`; it depends on `poker_engine` for card and action types only. So a bot **cannot** reach hidden data: the type of its input does not contain it.

### 5.3 Fair dealing
Bots are dealt from the same unbiased shuffle (`cards::shuffled_deck`, ADR-016) as in a human game. There is no rigging, no "catch-up", no hand-strength tuning toward or away from the human. Hard is stronger because it plays better, never because it knows more.

### 5.4 Tests that pin it
- **`bot_view_invariance` (property):** for random hands, change the other players' hole cards and the undealt deck while keeping the bot's view equal, and assert the same `Decision` for the same seed. (Cousin of `cards_leak`.)
- **`bot_view_has_no_foreign_cards`:** the view builder, for each seat, contains none of the other seats' cards before showdown.
- **`no_seat_advantage`:** over several thousand headless hands, identically configured bots at different seats have equal expected result within a statistical tolerance (fixed seeds).
- **`hard_beats_easy` and `normal_between`:** over the same headless run, average winnings are ordered by skill (fixed seeds, margin chosen after the first run and recorded).
- The existing secrecy tests (`cards_secrecy`, `cards_leak`) must still pass with bots in the room.

## 6. Journal, restore and replay
- Bot creation is `Op::AddBot`; each bot decision is journaled as the normal `Op::Action` it produces, with its time. Replay applies ops and never calls `decide`.
- Restore rebuilds seats, personalities and stacks from the journal; `BotMind` notes restart empty (section 4.5); the actor schedules the next bot action if a bot is to act (the same as a restored human turn clock).
- `RESILIENCE_AND_CRASH_HANDLING.md` section 7 records this.

## 7. Room config, protocol and session

- `RoomConfig` gains optional fields with serde defaults, so old clients and fixtures keep working: `solo: bool` (default false), `bots: u8` (default 0), `bot_skill: Easy|Normal|Hard` (default Normal), `blind_ladder_hands: u32` (hands per blind level in a solo game, default 8; see 10.2). Server validation: `solo` requires `card_mode = virtual`, `bots` between 1 and `MAX_SEATS - 1`, and is accepted only on the host path (`create_room_detached`), never from the network.
- **Forced settings (my call):** solo forces cards in the app; the setup screen offers no real-card choice. The human's turn timer defaults to **off** (`turn_time_limit_seconds = 0`), because pausing to think is normal against computers; the setup advanced section can turn it on (30 s).
- **Wire (owner decision):** bots look exactly like real players. `is_bot` stays inside the server and is **never** sent to clients; there is no bot tag anywhere in the table UI, so no wire change is needed for it. The setup screen and the Guide say plainly that every opponent is a computer player (honesty is in the framing, not on the plates).
- **Wire version:** the new `RoomConfig` fields are additive and optional. `API_AND_EVENTS.md` section 10 records them; protocol fixtures get a solo `CREATE_ROOM` example.
- **Solo server binding (my call):** a solo game starts the embedded server on **`127.0.0.1` only**, not `0.0.0.0`. No LAN listener, no address discovery, no lobby listing, no host keep-alive; nothing outside the device can reach the game. This is both the security and the battery default.
- **Session storage (my call):** `StoredSession` is a single slot, and a solo game would overwrite a saved hosted game. A second named slot is added to `TokenStore` (`solo`); the Home screen shows "Resume solo game" next to "Resume game" when each exists. Starting a new solo game replaces only the solo slot.

## 8. Efficiency budget (owner requirement)

| Area | Rule |
| :--- | :--- |
| Idle | The actor sleeps until the next timer; no polling for bots. Between a bot's turns the CPU does nothing. |
| Decision cost | Preflop table lookup: microseconds. Postflop: at most 400 equity samples (Hard) with a time cap of 8 ms; under 5 ms median on a mid-range phone. A bench test records the median and fails above 10 ms on the CI machine. Run inline on the actor; no extra threads. |
| Memory | Per bot a few hundred bytes plus counters per opponent. No history buffers. |
| Network | None. Loopback only; the radio is untouched. |
| Background | When the app goes to the background the solo game **pauses** (the existing `table.paused` mechanism, driven by the Flutter lifecycle) and resumes on return. Bots do not play while the screen is off. The wake lock follows the existing keep-awake setting and is released on pause. |
| GPU / UI | No continuously animated "thinking" spinner: a static "thinking" marker on the acting seat and the existing one-shot animations only. Bot-heavy rounds do not rebuild the whole tree (the existing `RoomState` selectors keep rebuilds to the changed seat). Reduced-motion settings are honoured. |
| Journal I/O | Unchanged: one append per action, snapshots only at hand boundaries (existing rule). |

## 9. UI design (details in `UI_DESIGN.md` section 10; matches the neo-brutalist system)

- **Home:** a third large action, "Play alone" (caption "Against computer players, no network"), between Host and Join; "Resume solo game" row when a saved solo game exists.
- **Setup screen (`SoloSetupPage`):** one screen of dense `BrutalRow`s and cells, no scrolling on a phone at 1.0 text:
  - **Opponents:** a stepper cell, 1 to 9, default 4.
  - **Skill:** three equal cells (Easy / Normal / Hard) with a one-line caption under the chosen one ("Plays by instinct", "Reads the table", "Reads you and adapts").
  - **Game length:** three cells Quick / Standard / Long (starting stack 1000, blinds start 10 and 20, blinds rise every 6 / 8 / 12 hands, section 10.2) with the chosen one's caption ("about 20 minutes", about 35, about 60 against 5 bots; estimates to be measured).
  - **Your record** (one caption line under the cells, shown after the first game): best finish and wins at this level and count of bots, stored on the device.
  - **Start** (primary cell). Name defaults to the saved default name.
- **Table:** the Player screen layout (hole cards, action buttons, raise slider) with the felt showing all seats, because the human is a player, not the host display. The host-only controls (undo, seat order, kick, add player) are hidden in solo; the menu keeps Pause, Rules/Guide and Leave game. (The plan confirms by reading `player_page.dart` and `host_controls.dart` whether to reuse `TablePage` or `PlayerPage`.)
- **Bots at the table:** seat plates show name and stack like any player. The acting bot's plate has the standard turn marker. A short, low-key action line ("Maya raises to 60") appears in the existing action feed. Reveals at showdown use the existing virtual-cards showdown view.
- **Pause banner** appears after returning from the background.
- **End states:** you are out, or you win: section 10.4.
- **Walkthrough and Guide:** the app tour gets a new step "Play alone"; the Guide gets a "Play alone" section (levels, fairness, battery). Strings in `util/strings.dart`.

## 10. Making it interesting: a tournament you can lose (owner decision plus suggestions)

The owner decided that rebuys would make solo boring, since the player would never be defeated. So solo is a **freeze-out tournament**: everyone starts with the same stack, nobody can rebuy, busted players are out, and the game ends when you are out or when you hold every chip. Suggestions to make that fun (my calls, all cheap):

### 10.1 Elimination, final table, finishing place
- A busted bot stands up after the hand and is **not** replaced; the table gets smaller and the play changes (shorter-handed means wider ranges and more aggression, which the strategy already reads from the player count). A brief line in the action feed says "Maya is out" and gives her place ("finished 6th").
- Every elimination fixes a **finishing place** (last in is 1st). With bots 1 to 9 the player's result reads "You finished 3rd of 6".
- When two players remain the table announces **heads-up**; the strategy shifts to heads-up ranges.
- Bots that bust other bots keep a visible reason to exist: a bot that knocked someone out gets a small mood boost (a very light "confidence" in 4.7).

### 10.2 Rising blinds by hands, not by clock (my call)
The tension of a tournament comes from blinds that rise. The engine's `Tournament` strategy rises by elapsed time (`BlindsStrategy::blinds(hand_number, elapsed_ms)`), which is wrong for solo: the clock keeps running while the app is paused, and a clock-driven change needs a timer. Solo adds a **hand-driven ladder**: an optional `hands_per_level` on the existing `Tournament` in `crates/poker_engine/src/blinds.rs` (it already holds the 1x, 1.5x, 2x, 3x ladder) that, when set, ignores `elapsed_ms` and uses `hand_number`, so it is deterministic, replay-safe, needs no timer, and pauses naturally. Levels grow about 1.5x (10/20, 15/30, 25/50, 40/80, 60/120, ...) and the last level repeats. The room shows "Blinds 25/50, rise in 3 hands" in the top bar. A bot's strategy reads the blinds relative to its stack (it gets short-stacked and pushes), which creates natural drama.

### 10.3 A rival
At creation one or two bots are marked internally as **rivals** (a higher `read_weight`, and a more distinctive archetype such as LAG or Nit-trapper). Nothing is shown to the player; rivals simply play more memorably against the human, so each game has a character the player remembers.

### 10.4 End screens (no rebuy)
- **You are out:** a full-screen result, in the same brutal style: big place ("3RD OF 6"), the hand that knocked you out (your two cards and the board as mini cards, from the last hand's events), a short stats block (hands played, hands won, biggest pot, best hand shown) counted from events in Dart and kept in memory only, and two cells: **Play again** (same settings, new bots) and **Home**. No rebuy, no continue.
- **You win:** the same screen with "YOU WON" and the knocked-out bots listed in order.
- The result updates **your record** (10.5) before the screen shows.
- Quit mid-game: the room is saved; Home offers "Resume solo game" (the game continues, nothing is lost).
- All results are on the device only; nothing is uploaded.

### 10.5 Personal record (local, tiny)
`AppSettings` gains a small map of results keyed by (level, bot count bucket): games played, wins, best finish. It shows as one caption line on the setup screen. This gives the player a reason to try Hard and 9 bots without any online system (leaderboards remain a non-goal).

### 10.6 Considered and left out for now
Bounties, side game modes, daily challenges, table chat and achievements: each adds surface and review cost for little gain before the core is proven. They fit this design later (the tournament structure and the result screen are the hooks).

## 11. Testing and gates
- Unit: strength table values, pot odds, bet sizing rounding and legality, stat smoothing, personality sampling (all parameters within range, distinct neighbours).
- Property: every `decide` returns a legal action for random legal views (use the engine validator); never panics; `bot_view_invariance`.
- Headless simulation test harness in `poker_server_core/tests/bots_sim.rs`: runs N hands with bots only using the real actor with `bot_think_scale = 0`: no stalls, chips conserved, hands finish, the skill ordering and no-seat-advantage tests, and archetype distinctness (VPIP and PFR differ measurably between archetypes over about 10,000 hands).
- Integration: solo room over the bridge; eliminated bots stay out and places are right; the game ends on the human's bust and on a full win; absence exemption; restore with bots; pause and resume; solo rejected from the network.
- Flutter: setup screen layout sweep (the existing sweeps add it), text scale 3.0, widget tests for the stepper, the skill cells, the rebuy/leave state, the Home rows; goldens for setup and a solo table with five bots.
- Gates as always: `fvm flutter analyze`, tests, protocol tests, `tool/check_web_safe.sh` (solo uses the existing platform seams; the web build is deferred and stubs host features), `tool/check_no_state_logging.sh` (bot logs carry no cards), cargo fmt, clippy, test.

## 12. Delivery order (for the plan)
0. **Engine:** `Tournament.hands_per_level` (hand-driven levels) with unit and property tests; validate and serialise it; replay-safe.
1. **Core:** `poker_bots` crate with `BotView`, strength, decision, RNG, personalities; headless harness; fairness tests. Green on its own.
2. **Room integration:** `Op::AddBot`, `room/bots.rs`, scheduling in the actor, absence exemption, config validation, journal and restore, loopback binding. Sim tests with the real actor.
3. **Adaptation and skill:** notes, reads, skill tuning, mood; simulation assertions tuned.
4. **Bridge and Dart:** `RoomConfig` models, `startSoloGame` API, session slot, lifecycle pause.
5. **UI:** Home rows, setup screen, solo table, elimination lines, end screens, personal record, strings.
6. **Docs, Guide, tour, goldens, version 1.3.0 bump.** Release only when the owner says.
Each step is committed on its own on a feature branch (`feature/solo-bots`); steps 1 to 3 are the Rust-heavy, high-risk parts and are planned and reviewed with the strongest model, the UI and string work can go to a cheaper tier (`MODEL_STRATEGY.md`).

## 13. Risks
- **Bots feel robotic or exploitable:** mitigated by archetypes, jitter, mood, thinking time and notes; the simulation tests catch uniform play; the owner will playtest and tune numbers (they are constants in one file).
- **Stall or wrong action:** every decision is validated against the engine's legal actions; fallback is check or fold.
- **Battery:** budget in section 8, measured by a bench test; pause on background.
- **Restore:** a bot whose turn it is when the app was killed acts again after the think delay; notes reset (documented).
- **Scope:** large, so the delivery order is incremental and each step ships green.

## 14. Calls the assistant made (check these while reading)
Bots live in the room actor, not as socket clients; bots exempt from absence and votes; new crate `poker_bots` with no server dependency; hand-written PRNG instead of `rand`; 169-entry preflop table plus capped Monte Carlo; three skill levels as in 4.4; six archetypes plus tilt; notes reset on restore; solo forces cards in the app and turns the human timer off; solo binds `127.0.0.1` only; no bot badge (owner decision); second storage slot for the solo session; no replacement of busted bots (freeze-out tournament with a hand-driven blind ladder, owner asked for a game you can lose); 1 to 9 opponents (owner decision); pause on background; name pool of 40; release 1.3.0 after the owner agrees.

## 15. Owner answers (2026-11-07)
1. Busting: **no rebuy, show an end screen**; the owner asked for suggestions to keep it interesting (section 10).
2. Bots: **look exactly like real players, no tag.**
3. Count: **1 to 9 bots.**
Approved. The owner accepted the section 10 suggestions and ruled out bounties, daily challenges, chat and achievements for now.

## 16. Builder check
Subagents are disallowed in this project, so the document was reread as the builder: the gaps found were the hand-driven blind ladder (10.2; the engine's tournament mode is clock-driven), the absence exemption (3.2), restore of notes (4.5), PRNG without a new dependency (4.6), the single storage slot (7), loopback binding (7), and the missing sim harness (11); each is now decided above. What is still left to the builder: exact constants (sample counts, thresholds, think times, archetype parameter ranges), which are tuned by the simulation tests and recorded in `docs/GAME_LOGIC_AND_RULES.md` section 11 once built; and the choice between reusing `TablePage` or `PlayerPage` for the solo table (section 9).
