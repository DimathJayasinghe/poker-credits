# Deploying and hosting

Two ways to run a game server: inside the app on the host's device (LAN games) and the standalone cloud binary. Both run the same `poker_server_core`.

## 1. Cloud server (Docker)

```bash
docker build -t poker-credits-server .
docker run -d --name poker -p 7878:7878 -v poker-data:/data --restart unless-stopped poker-credits-server
curl http://localhost:7878/health     # {"status":"healthy","activeRooms":0,...}
```

The image is ~120 MB, runs as an unprivileged user (uid 10001) and keeps rooms in the `/data` volume: `docker stop` then `docker start` restores every room from its journal (verified 2026-11-03). `docker stop` sends SIGTERM, which the server handles by closing rooms cleanly.

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `POKER_BIND` | `0.0.0.0:7878` | Listen address. |
| `POKER_DATA_DIR` | `/data` (image), `./data` (binary) | Journal and snapshots. Must be writable and persistent. |
| `POKER_SERVER_NAME` | `Poker Credits` | Shown by `/v1/info`. |
| `POKER_ALLOWED_ORIGINS` | none | Comma-separated browser origins allowed to open a socket (for a web player on a named host, e.g. `https://play.example.com`). The native app sends no `Origin` and is always accepted. |
| `RUST_LOG` | `info` | Log filter. |

Health check for an orchestrator: `GET /health` (the slim image has no `curl`, so use the platform's HTTP probe).

### Before exposing it to the internet (open items)
These are known gaps, tracked in `docs/STATUS.md`; none blocks a LAN game.
1. **TLS.** The server speaks plain `ws://`. Cloud mode needs `wss://`: terminate TLS in a reverse proxy (Caddy, nginx, a platform load balancer) and forward `/v1/ws` with WebSocket upgrade headers.
2. **Per-IP limits behind a proxy.** Connection, create and join-failure limits are keyed by the peer address. Behind a proxy that is the proxy's address, so **all players share one budget** (default 40 connections). Reading `X-Forwarded-For` from a trusted proxy is not implemented; decide how to trust it before putting the binary behind one (`SECURITY_AND_EDGE_CASES.md` 6.6).
3. **Origin policy.** A named host must list its own web origin in `POKER_ALLOWED_ORIGINS`; "Origin equals Host" is deliberately not trusted for names (DNS rebinding), only for IP literals and `localhost`.
4. **Room codes are 4 characters.** Fine on a LAN; on the open internet a scanner can guess them slowly despite the limiters (see the open owner question on longer codes).

## 2. Hosting from the app (LAN)

The host's phone or computer runs the server; others join by room code on the same Wi-Fi (ADR-012). The host needs nothing installed besides the app.

### Android
- Hosting starts a **foreground service** with a notification ("Hosting room XXXX"), so the server keeps answering when the host opens another app or locks the screen. It ends with END GAME or when the app is closed.
- The server lives inside the app's Flutter engine, so the service is stopped together with it: swiping the app away (or the system destroying its activity) ends hosting, the notification disappears, and the next launch offers **Resume hosted game** (the room is restored from its journal). The service lowers the chance of that happening in the background; it cannot make hosting survive the app being closed. Pressing Back on the table only leaves that screen; hosting continues until END GAME.
- Android 13+ asks once to allow notifications. If refused, the service still runs; only its notification is hidden.
- Type is `specialUse` (no standard type fits; `dataSync` is time-limited on Android 15). **Play Console:** the app must declare the special-use foreground service with the subtype text from the manifest ("Hosts a local poker game for other devices on the same network") and a short video of the feature when publishing.
- Battery optimisation on some vendors (Xiaomi, Huawei, Samsung "sleeping apps") can still kill a background app; add the app to the unrestricted list if a long game drops.

### iOS
iOS suspends apps in the background and has no equivalent service. Keep the host's app **in the foreground with the screen on** (the app keeps the display awake at the table). If the host switches away, players see "Reconnecting" and are back as soon as the app returns; turn timers keep running on the server only while it runs. Hosting from a laptop or a second device that stays plugged in is the reliable setup. iOS also asks for the **Local Network** permission the first time the app scans for a host.

### Windows
The first time the app starts hosting, Windows Defender Firewall asks whether to let it communicate. Choose **Private networks**. If the prompt was dismissed or players cannot find the game:
- Settings, Privacy & security, Windows Security, Firewall & network protection, **Allow an app through firewall**, tick **Private** for Poker Credits.
- Or from an elevated PowerShell: `New-NetFirewallRule -DisplayName "Poker Credits" -Direction Inbound -Protocol TCP -LocalPort 7878,7879 -Profile Private -Action Allow`
- The Wi-Fi must be marked **Private**, not Public, and must not be a guest network with client isolation (players see "No game found on this Wi-Fi").

### macOS and Linux
macOS may ask to accept incoming connections once. On Linux with `ufw`: `sudo ufw allow 7878:7879/tcp`.

### Ports
The host listens on 7878, or 7879 if that is busy (players probe exactly these two), then a random port; players on a random port need the typed address or the QR code.
