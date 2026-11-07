# Resilience & Crash Handling

How Poker Credits survives crashes, OS suspension, network loss and bad input. The strategy is modelled on LocalSend (`~/Documents/dev_projects/localsend`). Each item is marked:

- **[LS]** copied from LocalSend, with the file to read.
- **[NEW]** not present in LocalSend, designed here.

Rule for implementers: a failure in one room, one connection or one screen must never take down the process, other rooms, or the chip balances.

---

## 1. Failure map

| Failure | Where | Response |
| :--- | :--- | :--- |
| Exception during startup (storage, native lib load, permissions) | Dart `preInit` | Show the init error app with copyable details **[LS]** |
| Uncaught Dart error after startup | Dart | Log to file, keep app alive, show non-blocking error banner **[NEW]** |
| Rust panic inside a room | Server core | Log backtrace, restart that room from its journal, tell clients **[NEW]** |
| Rust panic crossing the FRB boundary | Bridge | FRB converts it to a Dart `PanicException` with a Rust backtrace (verified in the Phase 0 spike, `docs/SPIKE_BRIDGE_FINDINGS.md`); the bridge layer catches it and reports a typed error. Panics in background tokio tasks are NOT reported by FRB; the room supervisor reports them as events **[NEW]** |
| Listening socket dies (iOS suspension, interface change) | Host mode | Event from Rust triggers restart **[LS]**; probe on resume **[LS]** |
| Host app killed by the OS | Host mode | On next launch, restore rooms from snapshot + journal **[NEW]** |
| Client loses connection (screen lock, Wi-Fi blip) | Client | Backoff reconnect, resume handshake, full snapshot **[NEW]** |
| Client sends garbage / floods | Server | Reject, rate limit, disconnect repeat offenders **[LS]** pattern |
| Slow client cannot drain messages | Server | Drop that connection; client resumes **[NEW]** |
| Second app instance on desktop | Desktop | Hand over to the running one and exit **[LS]** |

---

## 2. Dart side

### 2.1 Startup guard **[LS]**
`app/lib/main.dart`:

```dart
Future<void> main(List<String> args) async {
  final RefenaContainer container;
  try {
    container = await preInit(args);
  } catch (e, st) {
    showInitErrorApp(error: e, stackTrace: st); // copyable error + app version
    return;
  }
  runApp(...);
}
```

Reference: `localsend/app/lib/main.dart`, `app/lib/config/init_error.dart`. `preInit` order to copy from `app/lib/config/init.dart`: bind the Flutter binding, init logger, init the Rust library, init persistence, desktop single-instance check, window and tray setup, build the container, start the server layer last.

### 2.2 Global error hooks **[NEW]**
LocalSend only uses `runZonedGuarded` inside child isolates (`packages/localsend_isolates/lib/src/isolate/child/main.dart`: "Uncaught async errors are fatal to the isolate by default, which would silently kill the server/upload loop; log them instead."). We apply the same idea to the main isolate:

- `FlutterError.onError` logs framework errors.
- `PlatformDispatcher.instance.onError` logs uncaught async and platform errors and returns `true` so the app keeps running.
- `runZonedGuarded` wraps `runApp` as the last net.
- Logs go to a rotating file in the app support directory (3 files x 1 MB) and to the console. The Settings screen has "Copy diagnostics" which includes version, platform and the last 200 log lines.
- Never swallow silently: every handler logs with stack trace.

### 2.3 Lifecycle recovery **[LS]**
Copy `LifeCycleWatcher` handling from `localsend/app/lib/main.dart`:

| State | Action |
| :--- | :--- |
| `resumed` (iOS, Android) | If hosting, run `ensureRunning()`: loopback `Socket.connect` with 1 s timeout, restart server on failure (`server_provider.dart`). If playing, trigger an immediate client reconnect. Re-request wake-lock. |
| `inactive` / `paused` | Do nothing destructive. Hosting on Android relies on the foreground service. |
| `detached` | Dispose server handle and sockets cleanly. |

Server restart keeps the room alive: it restores from journal (section 3.4), so players reconnect into the same hand.

### 2.4 Server-layer errors as events **[LS]**
The Rust server emits a single typed `ServerEvent` enum over a channel exposed to Dart by FRB as one stream (LocalSend: `ServerEventV2` → `RsServerEvent`). New server-to-app interactions extend the enum. No side channels. Error variants include `ListenerFailed { error }` and `RoomRecovered { room, reason }`. Dart routes events to providers; the providers are event handlers, not route handlers.

### 2.5 Android, iOS, desktop specifics
- **Android** host mode: foreground service with a persistent notification while a room is hosted (LocalSend has `foreground_service.dart` in `packages/localsend_isolates/lib/util/`). Take a multicast lock only when discovery is on. No cleartext exception is expected to be needed for `dart:io` and Rust sockets (verify on a device in Phase 5).
- **iOS**: sockets silently die while suspended; this is why probe-on-resume exists. Add `NSLocalNetworkUsageDescription`. Keep hosting on iOS best-effort: documented as "keep the app in the foreground" because iOS does not allow a general background server.
- **Windows**: first bind triggers the firewall prompt; the host screen explains it. Single instance via the handover pattern.
- **Linux/macOS**: same as Windows without the prompt.

---

## 3. Rust side

### 3.1 Process rules
- `panic = "unwind"` (default). Never set `panic = "abort"` in any profile.
- Install a panic hook at startup (`std::panic::set_hook`) that logs message, location and backtrace through `tracing`, then chains to the previous hook. **[NEW]**
- No `unwrap()` / `expect()` / indexing that can panic in request paths. Allowed only on provably-infallible constants and in tests. Enforce with `#![deny(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing)]` in `poker_server_core` (engine too, with tests exempt).
- Logging: `tracing`. On Android route to logcat with `tracing_android` **[LS]** (`localsend_isolates/rust/src/api/logging.rs`), because Android discards native stdout/stderr.

### 3.2 Room actor model **[NEW]**
Replaces the old Promise-chain queue.

```mermaid
flowchart LR
    C1[Connection task A] -->|RoomMsg| Q[(mpsc inbox, bounded)]
    C2[Connection task B] -->|RoomMsg| Q
    H[Host admin] -->|RoomMsg| Q
    Q --> A[Room actor task]
    T[turn deadline: Instant] --> A
    A -->|Outbound| O1[per-connection bounded queue A]
    A -->|Outbound| O2[per-connection bounded queue B]
    S[Supervisor] -. watches JoinHandle .-> A
```

- One tokio task per room owns `RoomState` exclusively. No locks around game state.
- The actor loop is `loop { select! { msg = inbox.recv() => handle(msg), _ = sleep_until(deadline) => on_timeout() } }`. Actions and timer expiry are processed one at a time in arrival order, so a late action and a timer expiry can never interleave (fixes RC-001 and RC-003 by construction).
- `handle` calls the pure engine: `engine::apply(&state, cmd) -> Result<Transition, PokerError>`. State is replaced only on `Ok`.
- Each `Connection` has a bounded outbound queue (default 64 messages). If a push fails because the queue is full, the actor marks that connection dead and closes it. The client reconnects and gets a snapshot. The room never waits on a slow phone.

### 3.3 Supervision and panic policy **[NEW]**
- A `Supervisor` owns `HashMap<RoomCode, RoomEntry { handle, join: JoinHandle<()> }>`.
- When a room task finishes with `JoinError::is_panic()`:
  1. log room code, panic payload, backtrace;
  2. rebuild state from the last snapshot plus journal (3.4);
  3. spawn a fresh actor, re-attach live connections (they are held by the connection tasks, which keep their `RoomHandle` behind a swappable `watch` channel), send everyone a `SNAPSHOT` plus a `ROOM_RECOVERED` notice;
  4. if the same room panics 3 times within 60 s, freeze it: state `Frozen`, send `ROOM_CRASHED`, keep snapshot on disk for support, other rooms unaffected.
- A panic in a connection task only closes that connection.
- The engine is pure, so a deterministic bug would replay into the same panic. The "3 strikes then freeze" rule stops a restart loop; the journal entry that triggers the panic is recorded as `poisoned` and skipped on the next replay, with a visible "last action discarded" notice to the host.

### 3.4 Snapshot + write-ahead journal **[NEW]** (amends ADR-006)
Because the engine is deterministic (no RNG, no clock inside it), state = `snapshot ⊕ ordered commands`.

- **Snapshot**: full `RoomState` JSON, written atomically (write temp file, `fsync`, rename) at: room creation, end of every hand (`PAYOUT`), config change, rebuy applied.
- **Journal**: append-only file per room, one JSON line per accepted command (`seq`, `playerId`, command, `at` timestamp supplied by the actor, not the engine). Appended **before** the new state is broadcast. `fsync` per line is affordable at poker action rates.
- **Restore**: load snapshot, replay journal lines in order through `engine::apply`. Truncated final line (power loss mid-write) is ignored and logged.
- **Compaction**: a new snapshot truncates the journal.
- Undo is a journal operation: an `UNDO` entry removes the last accepted command from the replay set (engine keeps its own 5-deep stack for live play; replay must give the same result, covered by a property test).
- Location: host mode `<app_support_dir>/rooms/<ROOM>/`; cloud mode `$POKER_DATA_DIR/rooms/<ROOM>/`.
- Retention: delete a room's directory when the room expires (60 min idle) or the host ends the game.

### 3.5 Cancellation safety with drop guards **[LS]**
LocalSend uses guards such as `PendingSessionGuard` and `UploadGuard` (`packages/core/src/http/server/v2.rs`) so that if a request future is dropped mid-flight, shared state is cleaned up. We use the same idiom for:
- `SeatReservationGuard`: a join in progress holds a seat; dropping the connection task before the join completes releases it.
- `ConnectionGuard`: on drop, decrements the per-IP counter and notifies the room actor `Disconnected(conn_id)`.
- Any `.await` between "reserve" and "commit" in the server must be covered by a guard.

### 3.6 Connection hygiene **[LS]**
From `localsend/server/src/controller/ws_controller.rs` and `config/scheduler.rs`:

| Control | Value (default, configurable) |
| :--- | :--- |
| Client ping when no outgoing message | every 15 s (LocalSend: 120 s; poker needs faster dead-link detection) |
| Server idle timeout (no frame received) | 45 s then close |
| Max connections per IP | 40 (LocalSend limits per IP; a full home table of 10 players, 20 spectators and the table screen can all sit behind one NAT address, plus reconnect overlap; also bounded by total rooms) |
| Max message size | 16 KiB |
| Per-connection rate limit | 10 messages/s sustained, burst 20; violation closes after 3 strikes **[NEW]** |
| Request/connection counters | cleared hourly by a `tokio::time::interval` task |
| Room TTL | 60 min of no activity |

### 3.7 Embedded server API shape **[LS]**
Mirror `packages/core/src/http/server` and `localsend_isolates/rust/src/api/server.rs`:

```rust
pub struct ServerConfig { pub bind: SocketAddr, pub data_dir: PathBuf, pub limits: Limits, pub event_tx: mpsc::Sender<ServerEvent> }
pub async fn start(cfg: ServerConfig) -> Result<ServerHandle, StartError>;
impl ServerHandle { pub async fn stop(self); pub fn local_addr(&self) -> SocketAddr; }
```

FRB exposes an opaque `RsServerHandle` plus one `Stream<RsServerEvent>`. The cloud binary calls the same `start` with a different config.

---

## 3.8 Inactive and departed players **[NEW]** (owner-approved 2026-11-02)
Three layers, from automatic to social. Layer 1 lives in the engine; layers 2 and 3 are server (Phase 2) with wire messages added to `API_AND_EVENTS.md` at that time.

1. **Auto sit-out (engine, done).** The turn timer sends `Timeout`; the engine checks if free, else folds, and counts a missed turn. Two missed turns in a row (`AWAY_AFTER_MISSED_TURNS`) sit the player out when the hand ends (`Event::PlayerAway`). Any real action or sitting back in resets the count. A player who quits, or whose connection is gone for good, is sent `LeaveHand`: they fold at once and sit out, and play again from the next hand (no missed-blind catch-up).
2. **Presence check (server).** Starts when a player has been sitting out for **5 minutes or 5 hands**, whichever comes first (a player who sat out on purpose gets the same check). The other seated players get "Is NAME still playing?" with Yes / No, and the clock is **90 seconds**.
   - The **host's answer is final** and ends the check at once.
   - Without a host answer: a strict majority of the *other* seated players who replied decides; players who do not reply abstain. No replies at all means nothing happens and the check may repeat after another 5 minutes.
   - If only one other player is seated, that player decides alone.
   - The subject of the check cannot vote, and answering "Yes, still playing" on their own device (a `PRESENCE_ACK`) cancels the check immediately.
   - "No" wins: server sends `LeaveHand` (if needed), then `RemovePlayer`, and **credits the returned chips to the room ledger** so nothing vanishes. The player can rejoin as a spectator or with a fresh buy-in.
3. **Busted players (server).** At zero chips a player is offered a rebuy between hands. With no answer after **2 minutes** they become a spectator and keep their seat reserved until the host removes them. The server decides when `RemovePlayer` is sent for busted seats; see `GAME_LOGIC_AND_RULES.md` section 9 item 19.

All timings are server config with these defaults. Voting results and kicks are written to the action journal so a restarted room reaches the same table.

## 4. Client reconnect and resume

### 4.1 Reconnect loop **[NEW]**
- Backoff: 0.5 s, 1 s, 2 s, 4 s, 8 s, then cap 10 s, each with ±20% jitter. Reset to 0.5 s after a connection stays up 10 s.
- Triggered by: socket close/error, missed pong (45 s), app `resumed`.
- UI during reconnect: non-blocking banner "Reconnecting…", action buttons disabled. After 30 s show "Still trying" with a manual retry and "Leave room".

### 4.2 Resume handshake **[NEW]**
Detailed in `API_AND_EVENTS.md` section 5. Essence: client sends `RESUME { roomCode, sessionToken, lastStateVersion }`. Server answers `SNAPSHOT` (always full, never a delta) containing `stateVersion`. Client replaces its entire view state. Idempotency of in-flight actions is protected by `actionSeq`.

### 4.3 Server grace behaviour
- On disconnect the seat stays reserved; `isConnected=false` is broadcast.
- If it is that player's turn: 30 s grace (counted from the later of the disconnect and the start of the turn), then auto-check if free else auto-fold (rule unchanged from `SECURITY_AND_EDGE_CASES.md`). Implemented in `room/absence.rs`; the action is journaled as `DISCONNECT_TIMEOUT`.
- A seat with no connection for 10 minutes is flagged `sitting_out` automatically; it is still reclaimable with the token.
- After a server restart nobody is connected, so every seat starts its 30 s / 10 min clocks at restart time. Downtime is never held against the player on turn: when a room is loaded from disk the supervisor applies `Op::Recover`, which restarts the turn clock (and a running presence-check clock) to a full period from the restart time. A clock only ever moves later. The op is journaled like any other, so replay agrees.

---

## 5. Test obligations

| Behaviour | Test |
| :--- | :--- |
| Engine deterministic | Property test: same command list gives same state |
| Chip conservation | Property test: sum of stacks + pots is constant across any legal action sequence |
| Journal replay equals live state | Property test over random legal hands, including undo |
| Truncated journal tail | Unit test with cut file |
| Room panic isolated | Integration test: inject panic via test-only command; other room keeps working; room restored |
| Freeze after 3 panics | Integration test |
| Slow consumer dropped | Integration test with a client that never reads |
| Resume gives full snapshot | Integration test: disconnect mid-hand, resume, state equals broadcast state |
| Reconnect backoff | Dart unit test with fake clock |
| Init failure shows error app | Dart widget test |
| Protocol fixtures | Rust and Dart tests read `protocol/fixtures/*.json` |
| Listener death restart | Integration test: close listener, expect `ListenerFailed` then restart |

---

## 6. Virtual cards and recovery (ADR-016)

- **Randomness is journaled.** The actor shuffles outside the reducer (`Deps { clock, entropy }`) and the resulting deck rides inside the journaled `HostCommand::StartHand { deck }`. Restore replays recorded inputs; it never draws new randomness, so a restored hand has the same cards (RC-007 extended). A journal line written before this feature has no `deck` and restores as a physical room.
- **Showdown is two ops.** The street-ending op, then `Op::AutoShowdown { allocations, at_ms }` carrying engine-computed winners; only the actor creates it, so no client can inject one. A kill between them is repaired when the room starts: `spawn` settles a virtual room found in `AllInRunout` or `Showdown` before it serves anyone, and if a settle ever fails the actor retries on a 2 s floor rather than leaving the hand stuck. Replay needs no evaluator.
- **Reconnect.** After `SNAPSHOT` (and `TURN_PROMPT` if due) the server re-sends `HOLE_CARDS` to that connection alone. The client keeps its cards across snapshots and treats duplicates as no-ops. A stale hand number never replaces a newer one.
- **Supervisor.** A room restored after a panic keeps its deal; a frozen room keeps it on disk. Snapshot and journal files are created `0600` and their directory `0700` (`store/private.rs`), because from this feature on they hold the deck.
- **Tests:** `cards_flow` (22 flows), `replay_property` (virtual proptest with forced all-in runouts and snapshots taken at arbitrary points, a payout deliberately left for later), `cards_secrecy` (permissions, the pre-feature fixture, `Debug` output has no card), `cards_leak` (an oracle audits every view and every message of 40 seeded games, and a planted leak must be caught), `fuzz` (a hostile client against a virtual victim learns none of the victim's cards).
