/**
 * Branded primitive types for domain safety.
 * Prevents accidentally passing a generic number/string where a
 * ChipAmount, PlayerId, or RoomId is expected.
 */

export type Brand<K, T> = K & { readonly __brand: T }

export type ChipAmount = Brand<number, 'ChipAmount'>
export type PlayerId = Brand<string, 'PlayerId'>
export type RoomId = Brand<string, 'RoomId'>
export type SessionId = Brand<string, 'SessionId'>
export type SeatIndex = Brand<number, 'SeatIndex'>

/** Safe constructor for ChipAmount — rejects negatives and non-integers */
export const toChips = (amount: number): ChipAmount => {
  if (amount < 0 || !Number.isInteger(amount)) {
    throw new Error(`Invalid chip amount: ${amount}`)
  }
  return amount as ChipAmount
}

// ── Game State Enums ──────────────────────────────────────────────────────────

export type GameStreet =
  | 'LOBBY'
  | 'STARTING_HAND'
  | 'POSTING_BLINDS'
  | 'PRE_FLOP'
  | 'FLOP'
  | 'TURN'
  | 'RIVER'
  | 'ALL_IN_RUNOUT'
  | 'SHOWDOWN'
  | 'HAND_WON_UNCONTESTED'
  | 'PAUSED'
  | 'PAYOUT'
  | 'NEXT_HAND_PREP'

export type ClientRole = 'TABLE_HOST' | 'PLAYER' | 'SPECTATOR'

export type PlayerStatus = 'ACTIVE' | 'FOLDED' | 'ALL_IN' | 'SITTING_OUT' | 'BUSTED' | 'DISCONNECTED'

export type ActionType = 'FOLD' | 'CHECK' | 'CALL' | 'RAISE' | 'ALL_IN'

// ── Player Action (Discriminated Union) ───────────────────────────────────────

export type PlayerAction =
  | { type: 'FOLD'; playerId: PlayerId; actionSequenceId: number }
  | { type: 'CHECK'; playerId: PlayerId; actionSequenceId: number }
  | { type: 'CALL'; playerId: PlayerId; amount: ChipAmount; actionSequenceId: number }
  | { type: 'RAISE'; playerId: PlayerId; toAmount: ChipAmount; actionSequenceId: number }
  | { type: 'ALL_IN'; playerId: PlayerId; actionSequenceId: number }

// ── Pot Tier ──────────────────────────────────────────────────────────────────

export interface PotTier {
  tierIndex: number          // 0 = Main Pot, 1 = Side Pot 1, etc.
  amount: ChipAmount
  eligiblePlayerIds: PlayerId[]
}

// ── Seat & Player State ───────────────────────────────────────────────────────

export interface SeatState {
  seatIndex: SeatIndex
  playerId: PlayerId | null
  name: string | null
  chips: ChipAmount
  currentStreetBet: ChipAmount    // chips committed this street
  totalHandBet: ChipAmount        // chips committed across all streets this hand
  status: PlayerStatus
  isConnected: boolean
  lastProcessedSequenceId: number // RC-002: idempotency tracking
  missedBlinds: number            // sit-out missed blind count
}

// ── Core Game State ───────────────────────────────────────────────────────────

export interface GameState {
  roomId: RoomId
  street: GameStreet
  prePausedStreet: GameStreet | null   // restores street when unpausing
  handNumber: number
  dealerSeat: SeatIndex
  smallBlindSeat: SeatIndex
  bigBlindSeat: SeatIndex
  activeSeat: SeatIndex | null         // null during non-betting states
  currentHighBet: ChipAmount
  minRaiseDelta: ChipAmount            // size of the last full bet/raise
  pots: PotTier[]
  totalPot: ChipAmount
  seats: SeatState[]
  isTransitioning: boolean             // RC-004: double-start guard
  pendingRebuys: Array<{ playerId: PlayerId; amount: ChipAmount }>  // RC-005
}

// ── Result Type ───────────────────────────────────────────────────────────────

export type PokerErrorCode =
  | 'NOT_YOUR_TURN'
  | 'INVALID_CHECK'
  | 'BELOW_MIN_RAISE'
  | 'INSUFFICIENT_FUNDS'
  | 'ROOM_NOT_FOUND'
  | 'SEAT_OCCUPIED'
  | 'ROOM_FULL'
  | 'INVALID_SESSION'
  | 'ACTION_ALREADY_PROCESSED'
  | 'HOST_ONLY_ACTION'
  | 'HAND_NOT_IN_PROGRESS'
  | 'GAME_PAUSED'
  | 'INVALID_TRANSITION'
  | 'VERSION_MISMATCH'

export interface PokerError {
  code: PokerErrorCode
  message: string
}

export type Result<T, E = PokerError> =
  | { success: true; data: T }
  | { success: false; error: E }

export const ok = <T>(data: T): Result<T, never> => ({ success: true, data })
export const err = <E>(error: E): Result<never, E> => ({ success: false, error })
