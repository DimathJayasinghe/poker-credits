# Virtual Cards Mode: Design

Status: **Proposed. Nothing is built.** Date: 2026-11-07. Author: assistant, from the owner's request. The owner delegated the open decisions ("answer these questions by yourself"), so every call in section 14 is the assistant's, made with the reasoning given there; the owner can still change any of them. Building starts only when the owner says go.

## 1. Intent

Today Poker Credits runs the table, the chips and the pots while the **cards are physical**. The owner wants a second way to play: **virtual cards**, for friends who have no deck at hand or do not want one. The app shuffles, deals each player two private cards, shows the board, ranks the hands at showdown and pays the pots. One person hosts a lobby, everyone on the same network joins it from a phone. Later the same lobby must work over the internet from a cloud server with no change to the game code.

Physical mode stays exactly as it is and stays the default.

## 2. Goals, non-goals, anti-goals

**Goals**
1. A room is created in `PHYSICAL` or `VIRTUAL` card mode. Virtual rooms need no deck, no host taps at showdown and no trust in other players' honesty about their hand.
2. Hole cards are private. Only the owner of a hand ever receives it, until the engine reveals it at showdown.
3. Fair shuffle: OS entropy, unbiased algorithm, recorded as an input (never re-derived).
4. Correct hand ranking and pot splitting, proven by exhaustive tests.
5. Same quality bar as the rest of the app: editorial-brutalist look, light and dark themes, reduced motion, text scale, accessibility, goldens.
6. Cloud-ready: nothing in the design assumes a shared Wi-Fi, a shared screen or a physically present host.
7. Zero behaviour change in physical rooms, and old journals and snapshots still load.

**Non-goals (v1)**
- Showing or mucking choice, run-it-twice, straddles, bomb pots, chat, emojis, hand history screens, auto-deal of the next hand, hand-strength hints, bots, deck-commitment audit (hooks are left, see 12).
- Accounts, matchmaking, public lobby browser on the internet.
- Protecting against a host who modifies the app and reads the embedded server's memory (section 9.4: accepted and documented).

**Anti-goals** (would be a failure even if it technically works)
- Any leak of a hole card to anyone but its owner before the reveal.
- Poker rules in Dart. The app only renders what the server sends.
- A card mode that makes physical games worse (extra taps, new bugs).
- A look that does not belong to the app (stock card art, Material widgets, runtime-downloaded assets).

## 3. What the player sees

### 3.1 Player screen (every guest)
The Player screen must stand alone: in cloud play there is no shared table screen. **The host does not use this screen**: a host, on a phone or a tablet, stays on the Table screen (3.2), which already carries the host controls and the host's own action buttons.

```
+----------------------------------+
| <  ROOM KQ7M | HAND 4 | RIVER  ? |  top bar cells
+----------------------------------+
| BOARD   [K♠][7♦][2♣][J♥][ ]      |  public cards, empty slots as hairline boxes
| POT 340    SIDE 120              |
+----------------------------------+
| ALICE 1.2k | BOB 800 ▮ | CY FOLD |  opponent strip (scrolls sideways)
+----------------------------------+
|        YOUR CARDS                |
|    [ A♠ ]      [ K♦ ]            |  face-down until you tap; flips with a short scale animation
|    tap to look  (hides again)    |
+----------------------------------+
| YOUR TURN        0:24  (accent)  |
| FOLD   |  CALL 40  |  RAISE      |
+----------------------------------+
```
- Cards are face-down by default and flip on tap (people sit shoulder to shoulder). Setting "Cards face up" turns that off. They hide again when the app goes to the background and when a new hand starts.
- The raise sheet covers the lower part of the screen, so cards and board stay above the action buttons.
- **Showdown (owner request: everyone can see everyone's cards and who won).** See 3.4. The Player screen never hides the result behind the host.
- Text scales to 3.0: the page scrolls as a whole as today.

### 3.2 Table / Spectator screen
Same felt as today plus: the **board** under the pot (5 slots, filled by street), a **mini card back pair** on each dealt seat plate, and at showdown the mini faces of revealed hands with the hand name (STRAIGHT, FULL HOUSE...). The winner plate gets the existing accent treatment.
- Host controls in virtual mode: START HAND stays. **BEGIN SHOWDOWN and RESOLVE disappear** (the server does both). Undo stays, limited to the current street (7.4). START HAND stays disabled until the client-side runout animation has finished, so nobody misses the result.
- **A seated host's own cards** appear in the same `HoleCardsDock` the guests use, docked at the bottom of the Table screen above the host controls (this is the common setup: the host plays from a phone). Phone width (under 840 px): face-down, tap to look, exactly like a guest. Wide screen (840 px and up, probably a shared display): the dock is collapsed to a single cell and shows the cards only **while pressed**, never automatically. The Host screen explains once that a TV is best run by a host who also joins from a phone.
- On a phone the Table screen therefore carries: top bar, board and pot, the stacked seat list, the dock, the host's own action buttons when on turn, and the host controls. It scrolls as a whole when that does not fit, as it does today.

### 3.4 Showdown result (Player, Table and Spectator, same component)
When two or more players reach showdown the server reveals all of their hands (7.3) and the screens show a **ShowdownPanel** that stays until the next hand starts:
```
+----------------------------------------+
| SHOWDOWN     BOARD [K♠][7♦][2♣][J♥][9♣] |
+----------------------------------------+
| ALICE  [A♠][K♦]  PAIR OF KINGS    | WINS 340  (accent, best five lifted)
| BOB    [Q♥][Q♣]  PAIR OF QUEENS   |  dimmed
| CY     [7♠][2♦]  PAIR OF SEVENS   |  dimmed
+----------------------------------------+
| MAIN POT 340  -> ALICE                  |
| SIDE POT 120  -> BOB, CY (split 60/60)  |
+----------------------------------------+
```
- One row per revealed hand: name, two cards, hand name (category from the server, label from `strings.dart`). Tapping a row shows that player's hand large with their best five highlighted on the board (this is the "way to see others' cards"). Winners carry a WINS +amount cell and the accent; losers are dimmed.
- A **pot list** under the rows shows each pot, its winners and the amount each receives, so side pots and splits are readable ("who won the bet").
- If the hand ended because everyone else folded there is no card row: one cell says `ALICE WINS 340, everyone else folded`. Folded and unreached hands are never shown (v1; a later "show my cards" option is a hook, not built).
- The result is part of the public view (`RoomView.result`), not a ticker event, so a phone that reconnects, a late joiner and a spectator all see it, and it stays until the next `START HAND`.
- The runout still plays on the client first (cards flip one by one), then the panel appears; reduced motion shows it at once. The host's START HAND button stays disabled until the panel is up.
- On a phone the panel is a full-width sheet that scrolls; on wide screens it sits beside the felt. Text scale 3.0 must not clip it.

### 3.3 Host setup
A new cell "CARDS" with a segmented control **Real cards / Virtual cards** between "You" and "Game settings", with one plain line under each choice. The choice cannot change after the room exists (7.2).

### 3.4 Join
The Join page and the "Games on this Wi-Fi" list show a tag `VIRTUAL` on virtual rooms. An old app that cannot play them is told to update (8.4).

## 4. Card look (Editorial Brutalism)
- Drawn, not imported: `CustomPaint` card with paper-white face, hairline border, zero radius, rank in Anton, suits as drawn paths (no suit glyph from a font, which varies per platform). "10" is written `10`, not `T`.
- Back: ink fill with a fine diagonal hairline grid and one vermilion mark. Night theme: the card face stays light (cards are objects, not UI).
- Colours: red/black suits by default; setting "Four-colour deck" (clubs green, diamonds blue) for colour-blind players. Suit shape always carries the meaning, colour never alone. New tokens go in `tokens.dart` only and pass `contrast_test`.
- Sizes: `hero` (Player), `board` (Table, Player), `mini` (seat plates). Fixed logical sizes with a minimum so text scale does not break them; rank text uses `FittedBox`.
- Motion (all via `BrutalTheme.duration`, honours reduced motion): deal = cards slide from the pot/deck spot, 90 ms stagger; flip = X-scale squash (no 3D); runout = flop, turn, river revealed one by one 700 ms apart on the client; showdown = losing cards dim, winning five lift by 4 px. Haptic: light tap on deal and on flip.
- Semantics: every card says "Ace of spades" or "Face-down card".

## 5. Architecture

### 5.1 Where things live (rule: all game rules live in `crates/poker_engine`)
| Concern | Home | Notes |
| :--- | :--- | :--- |
| `Rank`, `Suit`, `Card`, `Deck` (validated 52 unique) | `poker_engine::card`, `deck` | Value objects, invalid states unrepresentable. `Card` wire form is the 2-char string `As`, `Td`, `2c`. |
| Hand ranking (best 5 of 7) | `poker_engine::hand_rank` | Pure. `HandRank` = category + ordered tiebreak, total order, `Ord`. |
| Dealing order, board, reveals | `poker_engine::deal` | `Deal { holes, board, board_shown, revealed }`. Pure data plus pure functions. |
| Showdown allocations | `poker_engine::showdown` | `allocations(&Table) -> Vec<Allocation>` from ranks and pot eligibility. Ties produce several winners; the existing odd-chip split pays them. |
| **Randomness** | `poker_server_core::cards` | `trait Entropy` (Strategy), `OsEntropy` (getrandom), `FixedEntropy` for tests, unbiased Fisher-Yates with rejection sampling. The engine stays RNG-free. |
| Per-recipient projection | `poker_server_core::room::view` + actor | public `RoomView` (board, reveals, `hasCards`) and private `HOLE_CARDS`. |
| Dart | `poker_protocol` models, `app/lib/widget/cards/`, `RoomState.holeCards` | Rendering only. |

No new crate and no new dependency: `getrandom` and `sha2` are already approved. If a dependency is later wanted (`rand`), it needs approval.

### 5.2 Engine changes
- `Table` gets `#[serde(default)] deal: Option<Deal>`. `None` = physical (and every existing snapshot).
- `Command::StartHand { elapsed_ms, #[serde(default)] deck: Option<Deck> }`. Virtual rooms always pass `Some`; the engine validates it (52 unique cards) and deals: 2 cards per dealt seat in seat order from the button, then 5 board cards. Only the cards actually used are stored (at most 25), not the whole deck. **The deck is an input that the journal records; replay never re-shuffles.** Old journal lines have no `deck` and replay unchanged.
- `Deal.board_shown` is 0 at preflop and set to 3, 4, 5 by `next_street`, and to 5 by `enter_runout` / `enter_showdown`. It is stored, not derived from `Phase`, because `AllInRunout` and `NextHandPrep` do not say how far the hand got (a hand won on the flop keeps showing 3).
- `Deal.result: Option<HandResult>` is set when the hand is paid (`resolve_showdown`, `finish_uncontested`): `HandResult { uncontested: bool, pots: Vec<PotResult { pot_index, amount, winners: Vec<PlayerId>, shares: Vec<(PlayerId, Chips)> }> }`. **Everything in `Deal` is keyed by `PlayerId`, never by seat**: between hands the host can move seats, guests can take freed seats and busted players leave, all while the deal and result are still on screen. A seat-keyed lookup would send one player another player's folded cards and name the wrong winner. It is what the ShowdownPanel renders and it survives reconnects because it lives in the table state.
- `Deal.holes` is `Vec<(PlayerId, [Card; 2])>` and `Deal.revealed` (a `Vec<PlayerId>`) is filled when betting ends with 2 or more contenders (`enter_runout`, `enter_showdown`): all contenders show. An uncontested win reveals nothing. The deal stays on the table after the hand ends so late joiners and reconnecting clients still see the result; **only the next `start_hand` replaces it, whatever the phase** (including `Lobby`: when one player wins every chip the hand ends in `Lobby` in the same op and that last result must stay visible). `hole_cards_for(player)` additionally returns nothing once the hand is no longer the current one or the player has no entry. The server copies the display names of everyone in the result into `RoomState.hand_names` when the hand is paid (cleared at the next start), so a winner who has since left still has a name; the panel falls back to "left the table"
- Because `deal` is inside `Table`, undo restores it consistently with the phase. It is at most about 150 bytes per history entry; this was chosen over a separate field because it removes a whole class of "deal and phase disagree after undo" bugs.
- Manual showdown commands stay in the engine (physical mode needs them). The **server** refuses them in virtual rooms (7.3).

### 5.3 Server changes
- `RoomConfig.card_mode: CardMode` (`PHYSICAL` default via `serde(default)`), fixed for the life of the room.
- Actor dependencies become `Deps { clock, entropy }`. Starting a hand in a virtual room draws the shuffle from `entropy` **in the actor, outside the reducer**, and puts the `Deck` into the journaled `HostCommand::StartHand`. The reducer stays pure and replayable.
- **Auto showdown.** After any op that leaves a virtual room in `AllInRunout` or `Showdown`, the actor issues `Op::AutoShowdown { allocations, at_ms }` with `showdown::allocations` already computed, journaled like every other op. The reducer accepts it only for `Origin::Server`, only in virtual rooms, and applies `BeginShowdown` (if needed) then `ResolveShowdown(allocations)`; the engine re-validates the allocations as it does for a host. Replay therefore never needs the evaluator. If the process dies between the two ops, `Op::Recover` finds the room still in a showdown phase and issues the missing `AutoShowdown`. There is no reveal timer: the client paces the animation (4).
- **Manual showdown lock.** `HostCommand::BeginShowdown` and `ResolveShowdown` in a virtual room return `ILLEGAL_STATE`. A modified host client cannot award pots.
- **Undo rule (virtual only):** allowed when the previous table is in the same betting phase as the current one. That blocks undo across a street (everyone would re-bet knowing the flop), across `StartHand`, and anything after betting ended.
- **Private message.** `HOLE_CARDS` is modelled on `TURN_PROMPT`: built by `RoomState::hole_cards_for(player_id)`, sent to the owning connections only. Triggers: right after the deal, after every `SNAPSHOT` on join/resume/supersede (same place the turn prompt is re-sent in `send_snapshot`), never to spectators, never inside `STATE_UPDATE`.
- **Old-client gate.** `JOIN_ROOM` and `RESUME` gain `features: []` (default empty). A virtual room refuses a client without `"VIRTUAL_CARDS"` with the new error `UPDATE_REQUIRED`. `/v1/room/{code}` and `/v1/lobbies` expose `cardMode`.

### 5.4 Protocol (all additive, `v` stays 1)
| Item | Shape |
| :--- | :--- |
| `RoomConfig.cardMode` | `"PHYSICAL"` (default) or `"VIRTUAL"` |
| `RoomView.board` | revealed board cards, `[]` in physical rooms |
| `RoomView.result` | `{ uncontested, pots:[{ potIndex, amount, winnerPlayerIds, shares:[{playerId, amount}] }] }`, absent until a hand is paid |
| `RoomView.reveals` | `[{ seatIndex, playerId, cards:[c,c], category, bestFive:[c*5] }]`, empty until a reveal |
| `SeatView.hasCards` | bool: seat holds a dealt hand (draw a card back) |
| `HOLE_CARDS` (server, private) | `{ handNumber, cards:[c,c] }` |
| `JOIN_ROOM` / `RESUME` | `features: ["VIRTUAL_CARDS"]` |
| Error | `UPDATE_REQUIRED` |
| HTTP | `cardMode` on `/v1/room/{code}` and each `/v1/lobbies` entry |
Fixtures: one per new message and a virtual `RoomView`, on both sides (the suite enforces one per message type).

### 5.5 Dart
- `poker_protocol`: `Card` (parse/format of `As`), `CardMode`, `HoleCards` message, `RoomView` and `SeatView` fields; regenerate mappers.
- `RoomState.holeCards` is `{handNumber, cards}`, **kept across `Snapshot`** (like the ticker), replaced by a higher `handNumber`, cleared when the view shows lobby or a seat without `hasCards` for the current hand. Duplicate `HOLE_CARDS` are idempotent.
- `widget/cards/`: `PlayingCard`, `CardRow`, `BoardView`, `HoleCardsDock` (face-down, tap to look, auto-hide), `ShowdownPanel`, plus `util/strings.dart` names for hand categories. No ranking logic: the server sends `category` and `bestFive`.
- Settings: "Four-colour deck", "Cards face up". Both live in `AppSettings`.
- Platform seam untouched; all card code is web-safe.

## 6. Cloud readiness (how this migrates later)
1. Everything is server-authoritative and per-recipient already; the cloud binary runs the same `poker_server_core`. No LAN assumption appears in the new code.
2. The Player screen carries board, pot and opponents, so a room works with nobody looking at a shared display.
3. `Entropy` is injected: the cloud binary uses the same `OsEntropy`; a later audited or hardware source is a swap.
4. `cardMode` and `features` are negotiated in the protocol and the info endpoints, so mixed-version fleets fail clearly (`UPDATE_REQUIRED`).
5. Trust model improves in the cloud: the server operator is not a player, so the "host reads memory" limit (9.4) disappears.
6. Hooks left for later: deck commitment (publish `SHA-256(deck || salt)` at deal, reveal after the hand), `muck`/`show`, auto-deal, spectators-with-delay for streaming. None changes the data model above.
7. Cloud-only hardening already scheduled in `docs/DEPLOY.md` (TLS, proxy IP, room code length) matters more once cards are private; revisit before exposing virtual rooms publicly.

## 7. Behaviour rules

### 7.1 Dealing
Only seats that start the hand `Live` are dealt. Sitting-out, empty and busted seats get nothing. Players who join mid-hand are spectators of that hand.

### 7.2 Immutability
`cardMode` cannot be changed by `CONFIGURE` or any message. Switching modes means a new room.

### 7.3 Showdown
- Betting ends with one contender: pot paid, nothing revealed.
- Two or more: all contenders reveal (my call, section 14), pots are awarded by hand rank, ties split (the engine's odd-chip rule applies), `PotAwarded` events feed the ticker as today.
- Reveals, board and the pot-by-pot result stay in the view until the next hand starts, so every player can look at everyone's cards and at who won each pot for as long as they like.

### 7.4 Undo
See 5.3. The host's Undo button is disabled with the reason when not allowed.

### 7.5 Presence, timeouts, leaving
Unchanged. A folded, kicked or timed-out player's cards are never revealed and are discarded with the hand.

## 8. Edge cases
| Case | Behaviour |
| :--- | :--- |
| Reconnect mid-hand | `SNAPSHOT`, then `TURN_PROMPT` if due, then `HOLE_CARDS` again |
| Two devices, one player | newer wins, older gets `SUPERSEDED`; only the live connection receives cards |
| Server restarts mid-hand | snapshot plus journal restore the deal; players resume and get cards again |
| Crash between the street-ending op and `AutoShowdown` | `Op::Recover` completes it |
| Journal from before this feature | no `deck` field, `deal` is `None`, plays as physical |
| Joins mid-hand, or spectator | board and reveals only, never hole cards |
| Late spectator after showdown | sees board, reveals and the pot-by-pot result of the last hand |
| Seats swapped, player added or removed between hands | cards and result follow the player id; a newcomer in a freed seat gets nothing from the last hand; a departed winner keeps the stored name |
| Last hand of the game (one player has every chip, phase `Lobby`) | result and reveals stay until the next `START HAND` |
| Phone reconnects after the hand was paid | `SNAPSHOT` carries `result`, `reveals`, `board`; the panel is shown |
| Pot split three ways | `shares` lists each amount; odd chip per the engine rule |
| Host kicked player is mid-hand | engine folds them; cards discarded |
| All but one fold | no reveal |
| Everyone all-in preflop | reveal and full board at once; client paces the runout |
| Split pot with odd chip | engine rule, unchanged |
| Wheel (A-2-3-4-5), steel wheel, board plays, kicker ties | covered by evaluator tests |
| Two players with identical best five | split |
| 10 players | 20 hole plus 5 board of 52, always fits |
| Duplicate/replayed `HOLE_CARDS` | idempotent by `handNumber` |
| Old app joins virtual room | `UPDATE_REQUIRED`, clear text on the Join page |
| Hacked host sends `RESOLVE_SHOWDOWN` | `ILLEGAL_STATE` |
| Pause during betting | unchanged; cards stay hidden |
| App backgrounded | cards hide; wake lock unchanged |
| Screenshots / task switcher | stretch goal: Android `FLAG_SECURE` on the Player page in virtual rooms (platform seam) |
| Tournament blinds, rebuys, removals | untouched |

## 9. Security

### 9.1 Recipient matrix
| Data | Owner | Other players | Spectators | Host (not owner) |
| :--- | :--- | :--- | :--- | :--- |
| Own hole cards | `HOLE_CARDS` | never | never | never |
| Board | view | view | view | view |
| Hole cards of a contender at showdown | view | view | view | view |
| Hole cards of a folder or mucked hand | owner only | never | never | never |

### 9.2 Leak surfaces and controls
- **Broadcast views:** `view.rs` never reads `deal.holes`; it reads `board[..board_shown]` and `revealed` only. Test below.
- **Engine events** that feed the ticker carry no cards.
- **Logs:** `Deal`, `Card` and `Op::StartHand` implement `Debug` as redacted; no `tracing` of whole `Op`/`RoomState`. A test formats `RoomState` and fails if a card string appears; a lint grep for `?op` / `?state` stays in `tool/`.
- **Disk:** `snapshot.json` and `journal.jsonl` hold the deal for the current hand (needed for exact restore). Files are created `0600` and the folder `0700` on Unix. Documented in the security doc.
- **FRB events:** the bridge forwards `ServerEvent` kinds only (listening, stopped, errors); it never carries room data. Kept that way, with a test.
- **Panic/crash output:** the panic hook logs a backtrace, not state.
- **Fuzz:** the existing hostile-input fuzz test is extended with virtual rooms.

### 9.3 Fair shuffle
OS entropy through `getrandom`; Fisher-Yates over 52 with rejection sampling (no modulo bias); one shuffle per hand; the order is journaled as an input. Tests: it is always a permutation, positional distribution is flat within tolerance over many draws using a seeded `Entropy`, rejection sampling is covered with a degenerate entropy source.

### 9.4 Accepted limit
In host (LAN) mode the host's phone runs the server. The host's own UI only receives its own cards through the protocol, but someone running a modified build could read the process memory or the data folder. This is the same trust as dealing cards at a kitchen table among friends and is stated in the Host screen and docs. Cloud mode removes it.

### 9.5 Abuse
No new client request affects cards, so no new rate-limit surface. `GAME_ACTION` and the existing buckets are unchanged.

## 10. Testing strategy (quality gates)
**Engine**
- `HandResult`: pots, winners and per-player shares match the chips actually moved (shares sum to the pot amount; an uncontested hand yields one pot and no cards).
- Exhaustive 5-card enumeration: all 2,598,960 hands counted per category match the known table (40 straight flushes, 624 quads, 3,744 full houses, 5,108 flushes, 10,200 straights, 54,912 trips, 123,552 two pair, 1,098,240 pairs, 1,302,540 high card).
- 7-card: best-of equals the maximum over all 21 five-card subsets for random hands (property), wheel, steel wheel, kicker ties, board plays, symmetric suit permutations give equal rank.
- Showdown allocations: ties, multiple side pots with different eligible sets, short stacks, odd chip, conservation of chips (existing property test extended with virtual hands and all-in runouts).
- Deal: right number of cards, no duplicates across holes and board, `board_shown` per street and runout, undo restores `deal` with the phase.
**Server**
- Replay equality: extend `replay_property.rs` with virtual rooms (snapshot plus journal equals live state, including `AutoShowdown`, which the existing random play rarely reaches; add a generator that forces all-in runouts).
- **No-leak oracle:** run many random hands with several players and spectators over the actor, capture every outbound frame per connection, and fail if any other player's card string appears before its reveal.
- Reconnect resends cards; supersede; restore after kill between ops; `UPDATE_REQUIRED`; manual showdown refused; undo rule; cardMode immutable; physical rooms byte-identical behaviour (existing suite untouched).
- Fixtures round-trip in Rust and Dart.
**App**
- Goldens: ShowdownPanel (winner, split pot, side pots, uncontested, text scale 3.0), card faces, backs, hero/board/mini, both themes, four-colour deck; Player virtual (waiting, my turn, face-down, face-up, raise sheet, showdown) at 390x844, 1280x800, 1920x1080; Table with board and reveals.
- `text_scale_test` and `table_layout_test` extended (board present, 10 seats with mini cards, no overlap at 7 sizes, scales 1/2/3).
- `room_state_test`: `HOLE_CARDS` survives `Snapshot`, replaced by a higher hand, cleared in lobby.
- Reduced-motion test for the flip and deal.
- Emulator run against a scripted bot: host virtual room, deal, fold, raise, runout, showdown, kill and resume.

## 11. Performance
Evaluator: 21 combinations of 5 per player, at most 10 players per hand, once per hand: microseconds. Memory: about 25 cards per room. Wire: `HOLE_CARDS` is about 60 bytes. No new timers. The card widgets are `CustomPaint` with cached `Path`s and `RepaintBoundary`s; goldens guard shape regressions.

## 12. Design patterns used
Value objects (`Card`, `Rank`, `Suit`, `Deck`), pure reducer plus **recorded inputs** (event-sourcing: randomness is data), Strategy (`Entropy`, card mode behaviour behind one `CardMode` check in the reducer entry), projection per recipient (`view` and `hole_cards_for`), dependency injection (`Deps`), state kept in one place (`Table.deal`) so undo and snapshot stay coherent.

## 13. Out of scope but prepared
Deck commitment audit, show/muck, auto-deal, hand hints, spectator delay, `FLAG_SECURE`. Each is an additive change on top of 5.

## 14. Calls the assistant made (please confirm or change)
1. Cards and ranking live in `poker_engine`; ADR-005 is amended by a new ADR-016. No new crate, no new dependency.
2. `deal` is stored inside `Table` (undo-coherent, about 150 B per history entry) rather than beside it.
3. All contenders reveal at showdown, and everyone can open any revealed hand and see who won each pot (owner request 2026-11-07). Reason: it matches online poker's all-in showdown, removes disputes, and costs no extra protocol. There is no muck or show choice in v1; hands that folded or were never reached stay private.
4. No reveal timer: the server resolves at once and the client paces the animation.
5. Undo in virtual rooms is limited to the current street.
6. Cards are face-down on the Player screen until tapped, and a seated host's cards are hidden on the Table screen until pressed.
7. Four-colour deck is a setting, off by default.
8. The card mode is fixed per room; physical stays the default.
9. No auto-deal of the next hand in v1 (the host taps START HAND as today).
10. The shuffle order is journaled, so a bug fix in the shuffle never changes a replayed hand.
11. Evaluator and shuffle run on the server only; the Dart app has no ranking code.
12. Ship as app version 1.1.0 once all eight steps in the plan pass.
13. A seated host stays on the Table screen with the same face-down card dock as guests (phone width), and the dock is press-and-hold only on wide screens; hosts never use the guest Player screen.
14. The showdown result is stored in the table state (not sent as a transient event) so late joiners and reconnects see it, and it stays until the next hand replaces it because the owner wants players to be able to inspect it.
15. `START HAND` is not delayed on the server; only the host's button waits for the client animation. Reason: the server stays free of presentation timers.
