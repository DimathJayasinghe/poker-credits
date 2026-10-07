# Agent Coding Guide (Strict Instructions)

**IMPORTANT INSTRUCTION FOR AI AGENT:** You are acting as a pure implementation agent. All architectural, structural, and design decisions have already been made and are documented in the `docs/` directory. Your task is to **write code exactly as specified in this document**. Do not deviate, do not introduce new libraries without asking, and do not alter the file structure or naming conventions.

## 1. Git Workflow & Version Control

- **Branch Naming:**
  - `feature/<package>-<short-description>` (e.g., `feature/shared-game-types`)
  - `fix/<package>-<short-description>` (e.g., `fix/server-action-queue`)
  - `chore/<short-description>` (e.g., `chore/eslint-setup`)
- **Commit Messages:**
  - Use Conventional Commits: `<type>(<scope>): <subject>`
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
  - Scopes: `shared`, `server`, `client`, `repo`.
  - Example: `feat(shared): add calculatePotSplit logic`
- **Workflow:** For every discrete task assigned to you, create a new branch off `main`, implement the feature, and prepare it for review. Do not merge directly to `main` without approval.

## 2. Naming Conventions

Strictly adhere to the following naming conventions across the entire monorepo:

- **Files and Folders:**
  - React Components (Client): `PascalCase.tsx` (e.g., `PlayerCard.tsx`, `TableView.tsx`).
  - React Hooks (Client): `camelCase.ts` prefixed with `use` (e.g., `useGameState.ts`).
  - Non-Component TypeScript files (Server, Shared, Client Utils): `camelCase.ts` (e.g., `gameLogic.ts`, `actionQueue.ts`).
  - Type/Interface Definitions: `camelCase.ts` (e.g., `types.ts`, `gameEvents.ts`).
  - Folders: `kebab-case` (e.g., `components`, `store`, `socket-handlers`).
- **Code Entities:**
  - Interfaces and Types: `PascalCase` (e.g., `GameState`, `PlayerAction`). Do NOT prefix with `I`.
  - Classes: `PascalCase` (e.g., `RoomManager`, `ActionQueue`).
  - Variables, Functions, Methods: `camelCase` (e.g., `handlePlayerJoin`, `calculateBlinds`).
  - Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_PLAYERS`, `DEFAULT_STARTING_CHIPS`).

## 3. Strict File Structure & Implementation Phases

You will implement the system in the following order. Create files exactly as named here. Do not create additional files without explicit permission.

### Phase 1: Shared Package (`packages/shared/`)
This package contains pure TypeScript types and business logic shared by both client and server.

**Directory Structure:**
```text
packages/shared/
├── src/
│   ├── types/
│   │   ├── game.ts        # GameState, Player, Card, Suit, Rank
│   │   ├── actions.ts     # PlayerAction type, ActionPayloads
│   │   └── events.ts      # ClientToServerEvents, ServerToClientEvents
│   ├── logic/
│   │   ├── pokerHand.ts   # Hand evaluation logic (pure functions)
│   │   ├── pot.ts         # Pot splitting, side pots logic
│   │   └── validation.ts  # Zod schemas for validating payloads
│   ├── constants/
│   │   └── rules.ts       # Max players, blind increments, etc.
│   └── index.ts           # Export all
```
*Agent Task:* Implement the types based on `docs/API_AND_EVENTS.md` and logic based on `docs/GAME_LOGIC_AND_RULES.md`. Ensure zero dependencies on Node.js core modules or React. Use `zod` for validation schemas.

### Phase 2: Server Package (`packages/server/`)
The authoritative backend managing the state.

**Directory Structure:**
```text
packages/server/
├── src/
│   ├── core/
│   │   ├── GameRoom.ts        # Class managing a single room's state
│   │   ├── RoomManager.ts     # Singleton/Class managing all active rooms
│   │   └── ActionQueue.ts     # FIFO queue for processing actions per room
│   ├── socket/
│   │   ├── connection.ts      # Main socket.io connection handler
│   │   ├── roomHandlers.ts    # Join, leave, reconnect handlers
│   │   └── gameHandlers.ts    # Action submissions (fold, call, raise)
│   ├── storage/
│   │   └── snapshot.ts        # Logic for writing/reading room state to disk (JSON)
│   ├── utils/
│   │   └── logger.ts          # Simple logging utility
│   └── server.ts              # Fastify & Socket.io initialization entry point
```
*Agent Task:* Implement the Action Queue to ensure idempotency (`actionSequenceId`) and atomic state updates as detailed in `docs/ARCHITECTURE.md`. Use Fastify and Socket.io.

### Phase 3: Client Package (`packages/client/`)
The Next.js 15 UI using shadcn/ui and Tailwind.

**Directory Structure:**
```text
packages/client/
├── src/
│   ├── app/
│   │   ├── page.tsx               # Landing page (Create/Join Room)
│   │   ├── [roomId]/
│   │   │   ├── table/page.tsx     # Central table view (big screen)
│   │   │   └── player/page.tsx    # Mobile controller view
│   ├── components/
│   │   ├── ui/                    # shadcn/ui components (Agent: generate these using shadcn CLI)
│   │   ├── game/
│   │   │   ├── TableCards.tsx
│   │   │   ├── PotDisplay.tsx
│   │   │   ├── PlayerAvatar.tsx
│   │   │   └── ActionControls.tsx
│   │   └── layout/
│   │       └── Header.tsx
│   ├── hooks/
│   │   ├── useSocket.ts           # Socket.io connection hook
│   │   ├── useGameState.ts        # Zustand store hook bound to socket updates
│   │   └── usePlayerActions.ts    # Functions to emit actions to server
│   ├── store/
│   │   └── gameStore.ts           # Zustand store definition
│   └── lib/
│       └── utils.ts               # Tailwind cn() utility
```
*Agent Task:* Implement the UI ensuring strict separation between the "Table View" (read-only state display) and "Player View" (action buttons, private cards). Bind Zustand state strictly to Server socket events.

## 4. Coding Principles for the Agent

1. **No Local State for Game Logic:** The React client must treat the game state as read-only. Do not calculate "next turns" or "pot splits" on the client. The client strictly renders `GameState` from the server and sends `PlayerAction` requests.
2. **Idempotency:** Every client action payload MUST include an `actionSequenceId`. The server MUST check this against the last processed action for that player.
3. **Pure Functions:** Put all complex calculation logic (hand ranking, side pots) in `packages/shared/src/logic/` as pure functions (`(state, action) => newState` or similar).
4. **Error Handling:** Use a standardized error response format for socket events. If an action is invalid, emit an `action_error` back to the specific client, do not crash the room.
5. **Types First:** Always define the TypeScript interfaces in `shared` before writing the implementation in `server` or `client`.

## 5. Instructions for the Agent Starting Out

When you are invoked by the user to begin coding a phase, you MUST:
1. Read `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, and this `docs/AGENT_CODING_GUIDE.md` document.
2. Ensure you are on the `main` branch.
3. Create a branch for your assigned Phase (e.g., `git checkout -b feature/phase-1-shared-logic`).
4. Implement the files listed exactly under the Phase directory structure.
5. Do NOT proceed to the next phase. Stop, commit your work, push the branch, and inform the user that the phase is ready for review.
