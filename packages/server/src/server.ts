/**
 * Poker Credits — Authoritative Game Server
 * Fastify + Socket.io
 *
 * Phase 2 implementation starts here.
 * This file will be expanded with:
 *  - RoomManager
 *  - GameSession (with ActionQueue for RC-001)
 *  - SnapshotStore
 *  - SessionStore
 *  - All socket event handlers
 */

import Fastify from 'fastify'

const PORT = Number(process.env['PORT'] ?? 3000)
const HOST = process.env['LAN_MODE'] === 'true' ? '0.0.0.0' : '127.0.0.1'

const fastify = Fastify({ logger: true })

fastify.get('/health', async () => ({
  status: 'healthy',
  activeRooms: 0,
  timestamp: new Date().toISOString(),
}))

const start = async (): Promise<void> => {
  try {
    await fastify.listen({ port: PORT, host: HOST })
    console.info(`🃏 Poker Credits server running on http://${HOST}:${PORT}`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

void start()
