# Architecture Decision Records (ADRs): Poker Credits

This document formally captures all key architectural and engineering decisions, along with their context, trade-offs, and consequences.

---

## ADR-001: UI Framework Selection — Next.js 15 + shadcn/ui + Framer Motion

### Status: Accepted
### Date: 2026-10-07

### Context
The application must run smoothly across multiple platforms:
1. Central Table Display (iPad, tablet, TV, desktop).
2. Player Controllers (smartphones held in one hand).
Friends gathering for a poker game have very high resistance to downloading a 50MB native app from the App Store or Google Play just to play for an evening. A frictionless web experience where friends scan a QR code on the central screen and join within 5 seconds in Mobile Safari or Chrome is essential.

### Decision
We select **Next.js 15 (App Router)** paired with **Tailwind CSS**, **[shadcn/ui](https://ui.shadcn.com)**, and **Framer Motion**:
* **Next.js App Router**: Provides clean URL routing (`/table/[roomId]` for the table and `/play/[roomId]` for mobile controllers).
* **shadcn/ui**: Eliminates building UI primitives from scratch. Provides accessible, tactile components (`Slider` for bet sizing, `Dialog` for showdown resolutions, `Drawer` for player rebuy sheets).
* **Framer Motion**: Handles dynamic chip toss animations, pot counters, and active player glowing halos.
* **PWA**: Easily configured with `manifest.json` for full-screen "Add to Home Screen" usage.

### Consequences
* **Positive**: Instant onboarding (0 app store friction), responsive across all screen sizes, accessible UI primitives, fast development turnaround.
* **Negative**: WebSockets require client-side mounting (`'use client'`), which is standard practice for real-time multiplayer frontends.

---

## ADR-002: Networking Architecture — Authoritative Server via Socket.io over Peer-to-Peer (WebRTC)

### Status: Accepted
### Date: 2026-10-07

### Context
A poker game requires 100% strict adherence to chip accounting, turn orders, and pot limits. We evaluated two real-time topologies:
1. **Peer-to-Peer (WebRTC DataChannels)**: Devices communicate directly without a central server.
2. **Authoritative Server (Socket.io / WebSockets)**: A central node maintains true game state and validates all moves.

### Decision
We choose an **Authoritative Server model using Socket.io**:
* In-person poker games cannot afford desynchronization bugs or split-brain consensus issues common in P2P mesh topologies when a phone screen locks or drops Wi-Fi.
* WebRTC still requires a signaling server for ICE candidate exchange, meaning network infrastructure is needed regardless.
* Socket.io provides automatic reconnections, room multiplexing, and fallback to HTTP long-polling if restrictive firewalls block raw WebSockets.

### Consequences
* **Positive**: 100% deterministic state, zero risk of cheating or split-brain pot values, rock-solid reconnection handling via session tokens.
* **Negative**: Requires running a lightweight Node.js server process (easily hosted for free on Render/Fly.io, or run locally for LAN games).

---

## ADR-003: Core Game Engine Design — Pure Reducer in Shared TypeScript Package

### Status: Accepted
### Date: 2026-10-07

### Context
Poker rules involve complex math: min-raise calculations, blinds rotation, heads-up exception rules, and intricate multi-way side pots. Writing this logic in one language on the server and re-implementing it in another language for the frontend would violate DRY and cause logic discrepancies.

### Decision
We isolate all poker business logic in `@poker-credits/shared` as a **pure TypeScript library**:
* State transitions follow the pure reducer pattern: `(currentState, action) => Result<GameState, PokerError>`.
* Zero external runtime dependencies.
* Both the server (authoritative verification) and client (optimistic UI previews & validation) import the exact same package.

### Consequences
* **Positive**: 100% code reuse, zero logic drift, exhaustive unit testing with Vitest without booting network or UI layers.
* **Negative**: Requires a monorepo workspace configuration (`pnpm`).

---

## ADR-004: Dual-Mode Connectivity — Hosted Cloud + Offline Local Area Network (LAN)

### Status: Accepted
### Date: 2026-10-07

### Context
Poker games often happen in basements, rural cabins, or places with spotty cellular or internet connections. A purely cloud-dependent app would fail in these scenarios.

### Decision
Support two deployment targets using identical server code:
1. **Cloud Mode**: Hosted on a public server. Users connect using 4-letter room codes (`POKR-1234`).
2. **Offline LAN Mode**: The host laptop or tablet runs the server locally on port 3000. It queries `os.networkInterfaces()` and prints a QR code containing `http://192.168.x.x:3000`. Players connect over local Wi-Fi or phone hotspot with **zero internet required**.

### Consequences
* **Positive**: Works anywhere on earth, even without internet access.
* **Negative**: In LAN mode, players must be connected to the same Wi-Fi router or mobile hotspot.

---

## ADR-005: Physical Cards Showdown Resolution Model

### Status: Accepted
### Date: 2026-10-07

### Context
In this hybrid game, physical playing cards are dealt by hand in real life. When a hand reaches showdown, the app needs to award the chips. We considered:
1. Requiring players to enter their hole cards into their phones + typing board cards, then using an automated hand rank evaluator.
2. Allowing the table screen / dealer to simply tap the winning seat(s).

### Decision
We adopt the **Direct Showdown Tap Model**:
* Manually typing 2 hole cards and 5 board cards slows down home poker games drastically.
* In real life, players table their physical cards, look at each other's hands, and immediately know who won.
* At showdown, the Table Display shows the eligible contenders for the Main Pot and each Side Pot. The table host/dealer simply taps the winning player (or multiple players for a split pot) to trigger the chip award.
* *Note: Manual card input can be added later as an optional visual toggle, but will not be mandatory for gameplay.*

### Consequences
* **Positive**: Blazing fast home game pace; zero card-entry tedium.
* **Negative**: Relies on players/dealer accurately reading physical cards in real life (which they already do in normal games).

---

## ADR-006: State Storage Strategy — In-Memory with Periodic Crash Recovery Snapshot

### Status: Accepted
### Date: 2026-10-07

### Context
We need to decide where the authoritative game state lives. Options evaluated:
1. **Database (PostgreSQL / Redis)**: Persistent, survives restarts.
2. **Pure In-Memory (JavaScript Map)**: Fastest, zero setup, no I/O.
3. **Hybrid: In-Memory + Periodic JSON Snapshot to Disk**: Combines speed with basic crash recovery.

### Decision
**Hybrid approach**: State lives entirely in-memory for zero-latency reads/writes. Every time a hand concludes (at `PAYOUT` state), the entire `RoomState` is serialized as JSON and written to a local file (or Redis string in cloud mode). On server restart, rooms with active snapshots are restored.

### Consequences
* **Positive**: Sub-millisecond state reads; no database infrastructure needed for casual home game deployment; crash recovery prevents the entire night's chip counts from being lost on a server hiccup.
* **Negative**: State is lost if the server crashes mid-hand (between snapshots). This is acceptable for a home poker app where the dealer and all players can reconstruct the in-progress hand's chip state from memory.

---

## ADR-007: Spectator Mode — Read-Only Route `/watch/[roomId]`

### Status: Accepted
### Date: 2026-10-07

### Context
When a player busts out of a tournament, or when a friend arrives late and wants to watch without playing, there is no mechanism defined in the original architecture for them to view the game without occupying a player seat.

### Decision
Introduce a **Spectator Role** connecting via `/watch/[roomId]`:
* Spectators join the same Socket.io room but are never assigned a seat index.
* They receive all `game:state_updated` and `game:action_performed` broadcasts identically to the table screen.
* The server never sends `game:turn_prompt` to spectators.
* Spectators are listed separately from players in `RoomState` and do not affect blind rotations, pot calculations, or seat counts.

### Consequences
* **Positive**: Busted players can watch the rest of the tournament; late-arriving friends can observe and join the next game.
* **Negative**: Adds a third client role (`SPECTATOR`) to manage alongside `TABLE_HOST` and `PLAYER`.
