import type { GameStreet } from './types.js'

/** Maximum players per room (seats 0–9) */
export const MAX_PLAYERS = 10

/** Maximum spectators per room */
export const MAX_SPECTATORS = 20

/** Number of undo states retained per hand */
export const UNDO_STACK_LIMIT = 5

/** Default turn time limit in seconds */
export const DEFAULT_TURN_TIME_SECONDS = 30

/** Grace period after disconnect before auto-action (seconds) */
export const DISCONNECT_GRACE_SECONDS = 30

/** Room inactivity TTL in minutes before GC */
export const ROOM_TTL_MINUTES = 60

/** Default buy-in amount */
export const DEFAULT_BUY_IN = 1000

/** Default blind structure */
export const DEFAULT_SMALL_BLIND = 10
export const DEFAULT_BIG_BLIND = 20

/** API payload version — increment on breaking schema changes */
export const PAYLOAD_VERSION = 1

/**
 * Valid state machine transitions.
 * Any transition not listed here is illegal and will return INVALID_TRANSITION.
 */
export const VALID_TRANSITIONS: Readonly<Record<GameStreet, GameStreet[]>> = {
  LOBBY:                  ['STARTING_HAND'],
  STARTING_HAND:          ['POSTING_BLINDS'],
  POSTING_BLINDS:         ['PRE_FLOP'],
  PRE_FLOP:               ['FLOP', 'ALL_IN_RUNOUT', 'HAND_WON_UNCONTESTED', 'PAUSED'],
  FLOP:                   ['TURN', 'ALL_IN_RUNOUT', 'HAND_WON_UNCONTESTED', 'PAUSED'],
  TURN:                   ['RIVER', 'ALL_IN_RUNOUT', 'HAND_WON_UNCONTESTED', 'PAUSED'],
  RIVER:                  ['SHOWDOWN', 'HAND_WON_UNCONTESTED', 'PAUSED'],
  ALL_IN_RUNOUT:          ['SHOWDOWN'],
  SHOWDOWN:               ['PAYOUT'],
  HAND_WON_UNCONTESTED:   ['PAYOUT'],
  PAUSED:                 ['PRE_FLOP', 'FLOP', 'TURN', 'RIVER'],
  PAYOUT:                 ['NEXT_HAND_PREP'],
  NEXT_HAND_PREP:         ['STARTING_HAND', 'LOBBY'],
}
