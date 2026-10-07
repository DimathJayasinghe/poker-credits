# Poker Credits (Poker Companion App)

> A real-time, cross-platform companion app for physical Texas Hold'em poker games that replaces physical poker chips with a seamless digital credit and pot management system.

---

## 🎯 Overview

In traditional home poker games, managing physical chips is often cumbersome—stacking, counting, calculating complex side pots for all-ins, making change, and tracking pot totals can slow down play.

**Poker Credits** bridges the physical and digital worlds:
* **Physical Cards**: Players shuffle and deal physical cards in real life.
* **Central Table Display**: A tablet, laptop, or TV sits at the center of the table showing the live community pot, side pots, radial seating, dealer button `(D)`, small/big blind badges, and live action ticker.
* **Mobile Player Controllers**: Players join on their smartphones to check, call, raise (via smooth slider), or fold with tactile haptic feedback.
* **Dual Networking**: Play online over the cloud via 4-letter room codes, or completely offline on Local Area Network (LAN) / phone hotspot.

---

## 📚 Technical Documentation

Comprehensive architectural design and engineering documentation is available in the [`docs/`](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/) directory:

| Document | Purpose |
| :--- | :--- |
| **[Game Logic & Rules Specification](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/GAME_LOGIC_AND_RULES.md)** | Complete Texas Hold'em betting rules, heads-up exception, side pot math, and showdown splits. |
| **[Security & Edge Cases Specification](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/SECURITY_AND_EDGE_CASES.md)** | Threat model, zero-trust server, session token auth, mobile backgrounding, short all-in rule, and undo stack. |
| **[Architecture & System Design](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/ARCHITECTURE.md)** | High-level topology, Texas Hold'em state machine, side-pot tier algorithm, and hardware API integrations. |
| **[Coding Standards & Design Patterns](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/CODING_STANDARDS.md)** | SOLID principles, Clean Architecture, State & Strategy design patterns, branded TypeScript types, and quality standards. |
| **[API & Real-Time Events](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/API_AND_EVENTS.md)** | Bidirectional Socket.io event schemas, Zod validation contracts, HTTP endpoints, and error handling codes. |
| **[Architecture Decision Records (ADRs)](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/docs/DECISIONS.md)** | Formal ADRs capturing decisions for Next.js, shadcn/ui, authoritative WebSockets, and side-pot resolution. |
| **[Implementation Plan](file:///home/dimathrj/Documents/dev_projects/Pocker_Credits/pocker_credit_plan.md)** | Phased development plan, tech stack breakdown, and verification strategy. |

---

## 🛠️ Tech Stack & Ecosystem

```
Frontend:       Next.js 15 (App Router) + React 19
UI & Primitives: shadcn/ui + Radix UI + Tailwind CSS
Animations:     Framer Motion (chip physics, pot animations, turn pulse)
Backend:        Node.js + Fastify + Socket.io (Authoritative Game Server)
Core Engine:    @poker-credits/shared (Pure TypeScript, 0-dependency domain logic)
Hardware APIs:  Screen Wake Lock API + Vibration API + Web Audio API
```

---

## 🏗️ Repository Structure

```
pocker-credits/
├── docs/                           # Architectural & Engineering Specifications
│   ├── GAME_LOGIC_AND_RULES.md     # Betting rules, heads-up, side pots, odd chips
│   ├── SECURITY_AND_EDGE_CASES.md  # Threat model, auth, reconnections, undo stack
│   ├── ARCHITECTURE.md             # System design, state machine, side-pots
│   ├── CODING_STANDARDS.md         # Clean code, SOLID, design patterns, testing
│   ├── API_AND_EVENTS.md           # Socket.io schemas & REST contracts
│   └── DECISIONS.md                # Architecture Decision Records (ADRs)
├── packages/
│   ├── shared/                     # Pure TypeScript Poker Domain Engine
│   │   ├── src/
│   │   │   ├── types.ts            # Branded types, Player, GameState, PotTier
│   │   │   ├── pokerEngine.ts      # State machine & action validation
│   │   │   ├── potCalculator.ts    # Main & side pot contribution tiers
│   │   │   └── constants.ts
│   │   └── test/                   # Vitest unit test suite (100% pot coverage)
│   ├── server/                     # Authoritative Socket.io Game Server
│   │   ├── src/
│   │   │   ├── server.ts           # Fastify + Socket.io server
│   │   │   ├── roomManager.ts      # Room lifecycle & session tokens
│   │   │   ├── gameSession.ts      # Active hand management & event routing
│   │   │   └── lanDiscovery.ts     # Local IP binding for offline play
│   │   └── test/
│   └── client/                     # Next.js 15 + shadcn/ui + Tailwind Frontend
│       ├── app/
│       │   ├── page.tsx            # Landing & Join room page
│       │   ├── table/[roomId]/     # Central Table / Pot Display screen
│       │   └── play/[roomId]/      # Player Mobile Controller screen
│       ├── components/             # shadcn/ui components & poker felt views
│       ├── hooks/                  # useSocket, useWakeLock, useHaptics
│       └── public/                 # Sound effects & PWA manifest
├── pocker_credit_plan.md           # Phased execution plan
└── package.json
```

---

## 🚀 Key Gameplay Features

1. **Zero-Friction Player Onboarding**:
   - The central table display generates a high-contrast QR code.
   - Players scan with their native phone camera to instantly load the mobile controller in Safari/Chrome.
2. **Automated Blinds & Dealer Button Rotation**:
   - Tracks Dealer `(D)`, Small Blind `(SB)`, and Big Blind `(BB)` positions.
   - Automatically deducts blinds and transitions to Pre-Flop Under-The-Gun (UTG).
3. **Automated Main & Side Pot Engine**:
   - When one or more players go all-in with unequal chips, the engine automatically creates and tracks multiple side pots.
4. **Showdown Tap Resolution**:
   - At showdown, eligible contenders for each pot are presented on the table screen; host or players tap the winner(s) to distribute the chips.
5. **Screen Wake Lock & Tactile Haptics**:
   - Keeps the central table screen awake throughout the game without dimming.
   - Vibrates the active player's smartphone when it is their turn to act.
