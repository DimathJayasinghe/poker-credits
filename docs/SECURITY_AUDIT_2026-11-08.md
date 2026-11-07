# Security audit, 2026-11-08 (before the first signed store release)

Scope: the Rust engine and server (`crates/`), the FRB bridge (`packages/poker_bridge`), the Flutter app
(`app/`), the Android, iOS, Windows and Linux packaging, CI and the dependency set. Version audited:
1.3.1 (`main` at `e0997b5`). Reviewed by reading the code, the docs and the build files; nothing was
run against a real network or a real device.

Severity: **High** can leak a player's cards or let someone take over a seat or a table in a normal
game. **Medium** needs an attacker to be positioned or to trick a user. **Low** is hardening.
**Blocker** means the signed store release must not go out until it is fixed.

Each finding says where it is and its status. Status lines were updated when the fix branch
(`security/lan-tls`) was finished; the design of the fix is in ADR-019 (`docs/DECISIONS.md`).

## Findings

### F1. All LAN traffic is plaintext (High, blocker)
Every game on the LAN uses `ws://` to the host's IP (`app/lib/model/join_link.dart:17`, host UI over
loopback in `app/lib/provider/host_provider.dart:42`); the Android manifest even sets
`usesCleartextTraffic="true"` (`app/android/app/src/main/AndroidManifest.xml`). Anyone on the same
Wi-Fi who can sniff (open or shared Wi-Fi, a compromised router, ARP spoofing) reads:
- `HOLE_CARDS` of every player in a virtual-card room (the cards the app keeps secret),
- every session token and the host token (bearer secrets: with one the attacker resumes the seat,
  or the host's controls),
- the table state and the chat-like names.

Fix: the host serves **TLS 1.3 only** with a per-install self-signed certificate; every client pins
the certificate fingerprint it was given in the QR code (or saw on first contact for code and lobby
joins). Plaintext is refused on any non-loopback listener in host mode.
Status: **fixed** on `security/lan-tls` (ADR-019). Tested: 12 TLS integration tests (pinned join in host and cloud mode, wrong pin refused, plaintext client gets no answer, host refuses plaintext on the network, tokens visible on the wire only in the plaintext control run), a native Dart-to-rustls interop test, and a real TLS server test in the app. Not yet run on a physical device.

### F2. A guest cannot tell the real host from an impostor (High, blocker)
Nothing authenticates the server. A device on the LAN can answer the code probe
(`GET /v1/room/{code}` across the /24, `app/lib/platform/host_finder_io.dart`) or the lobby browse,
and the guest then sends `RESUME` with its stored session token to the impostor, which keeps it
(`docs/SECURITY_AND_EDGE_CASES.md` 6.6). It can also show the guest a forged table.
Fix: the pin (F1). A resumed session is bound to the fingerprint it was created with; a different
certificate is a hard stop with a clear message, never a silent downgrade. Joining by code or lobby
is trust-on-first-use; the QR code is the strong path (the fingerprint is in it).
Status: **fixed** on `security/lan-tls`. The QR code carries the pin; code, lobby and typed-address joins pin on first use and the stored session keeps the pin; `rediscover` refuses a device with another certificate (`player_flow_test`). Residual: an attacker already on the Wi-Fi at the very first code or lobby join (see R1).

### F3. The Android release is signed with the debug key (High for distribution, blocker)
`app/android/app/build.gradle.kts:37` signs `release` with `signingConfigs.getByName("debug")`. The
Play Store rejects it, and a debug key is not secret, so anyone could ship an update that Android
accepts over the user's install.
Fix: read an upload key from `android/key.properties` (git-ignored) when present; fail the release
build when it is absent instead of falling back to debug. The owner creates the key; this repository
never generates or stores one. Play App Signing keeps the real signing key with Google.
Status: **fixed in the build script, owner action needed.** `android/key.properties` (git-ignored) is read when present; `REQUIRE_RELEASE_SIGNING=1` (or `-PrequireReleaseSigning`) makes a missing key fail the build. Without the switch the build still falls back to the debug key with a warning, which keeps the 2026-11-07 owner decision (debug-signed GitHub releases until a real key exists). The store build must use the switch. The upload key itself is created by the owner (`docs/RELEASE_CHECKLIST.md`).

### F4. HTTP routes accept any `Host` header (Medium)
`GET /v1/lobbies`, `/v1/room/{code}` and `/v1/info` do not check `Host` (the WebSocket upgrade
checks `Origin`, `crates/poker_server_core/src/net/guards.rs:26`). A web page the host's neighbour
visits can use DNS rebinding to read them from the neighbour's browser: it learns which lobbies and
room codes exist on the LAN. No cards or tokens are exposed by those routes.
Fix: in host mode accept only an IP literal, `localhost` or the server's own name as `Host`.
Status: **fixed** on `security/lan-tls`. A middleware on every host-mode route accepts only an IP literal, `localhost` or a `*.local` name (`net/guards.rs::host_header_allowed`, tests in `tests/net.rs`). Cloud mode serves its own name and is unaffected.

### F5. CI actions are pinned to mutable tags (Medium, supply chain)
`.github/workflows/ci.yml` and `desktop-builds.yml` use `actions/checkout@v4`,
`subosito/flutter-action@v2`, `actions-rust-lang/setup-rust-toolchain@v1`,
`EmbarkStudios/cargo-deny-action@v2` and `actions/upload-artifact@v4`. A moved tag runs new code in
the workflow that builds the release binaries. Permissions are already `contents: read`.
Fix: pin every action to a full commit SHA with the tag in a comment.
Status: **fixed** on `security/lan-tls`. All `uses:` lines are pinned to full commit SHAs with the tag in a comment, and `.github/dependabot.yml` proposes updates weekly. Unverified until CI runs on a pushed branch.

### F6. The solo game's loopback server is reachable by other apps on the device (Low)
`ServerConfig::loopback_only` listens on `127.0.0.1`. On Android any other app with `INTERNET` can
open that port. It cannot read the player's session (tokens) but can probe `/v1/room/{code}` and try
to join the solo room by code. Rate limits apply (`http_rate_per_second`, join failures) and the
room code has 32^4 values.
Status: accepted for 1.4; track a per-room join secret for loopback servers.

### F7. Four-character room codes (Low)
`crates/poker_server_core/src/util/room_code.rs`: 32^4 ≈ 1.05 million codes. On a LAN with the
limits in `config.rs` full enumeration by one address takes days; with many addresses (cloud mode,
no app UI today) an attacker can find a room. A found room still needs a free seat and the host's
approval flow.
Status: accepted; revisit before any public cloud launch.

### F8. Desktop packages are unsigned (Low for stores, Medium for trust)
The Windows installer and zip and the Linux tarball are unsigned (`SmartScreen` warns; release notes
say so). Checksums are published in `SHA256SUMS`.
Status: open; needs a signing certificate chosen by the owner. Tracked in `docs/RELEASE_CHECKLIST.md`.

### F9. Store-submission gaps (release checklist, no code vulnerability)
- iOS was never built or run from this repository: the privacy manifest (`PrivacyInfo.xcprivacy`)
  and required-reason API declarations are missing; the Local Network permission text exists
  (`ios/Runner/Info.plist`).
- Play Console: Data safety form, privacy policy URL, foreground-service `specialUse` declaration
  (documented in `docs/DEPLOY.md`), target API level.
- The Terms text needs a legal review before publishing.
- R8 and minification of the release build are not confirmed by a test run.
Status: tracked in `docs/RELEASE_CHECKLIST.md`.

## Residual risks after the fixes

- **R1. Trust on first use.** A join by room code, lobby list or typed address pins the certificate
  the answering device shows. An attacker on the same Wi-Fi who answers first at that moment is
  pinned instead of the host. The QR code is the defence; the Guide and the Terms say so. Later
  reconnects are pinned and cannot be redirected.
- **R2. The private key is a 0600 file** in the app's private directory, not in the platform
  keystore. The app sandbox protects it; a rooted or backed-up device could expose it. It identifies
  a LAN host only; it protects no account and no money.
- **R3. No global cap on established connections** after the handshake (per-IP caps apply). A device
  on the LAN can still occupy the host's connection slots with many addresses.
- **R4. Old hosts and new guests cannot play together** (1.3.1 hosts speak plain `ws://`). The guest
  shows "host runs an older version". The release notes must say so.
- **R5. Nothing was run on a real device.** TLS interop was proven between `dart:io` and rustls on
  loopback sockets, on Linux. Windows (`ring` build), Android, iOS and macOS need a run.

## What was checked and is fine

- Tokens: 128 bits from the OS RNG; only SHA-256 hashes stored; constant-time compare
  (`util/token.rs`); host `RESUME` needs the host token (`room/actor.rs`).
- Device storage: tokens only in Keystore, Keychain, Credential Locker or the Secret Service, no
  file fallback (`platform/token_store_io.dart`); `allowBackup="false"` and extraction rules.
- Server input: first message must be `CREATE_ROOM`, `JOIN_ROOM` or `RESUME` within the auth
  deadline; 16 KiB frames; token-bucket rate limits with three strikes; per-IP connection cap and
  failed-join blocker; write timeout against stuck peers; panics isolated per room by the
  supervisor; workspace lints forbid `unsafe`, `unwrap`, `expect`, indexing and `panic!`.
- Private files are created `0600` in `0700` folders (`store/private.rs`).
- No custom URL scheme or deep-link intent filter is registered, so no external app can drive a
  join; the QR link is parsed only by the in-app scanner. Only `MainActivity` is exported.
- Supply chain: `cargo deny` (advisories, licences, sources) is in CI; the Dart side uses the
  approved package list only.
- Logging: `tool/check_no_state_logging.sh` keeps game state and tokens out of logs.

## Release gate

The signed store release waits for: F1, F2, F4 and F5 (done, see above), F3 (the owner creates the
upload key and builds with `REQUIRE_RELEASE_SIGNING=1`), a play-through on at least one physical
Android host and two guests, and every item of `docs/RELEASE_CHECKLIST.md` ticked by the owner.
