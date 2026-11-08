# Release checklist for a signed store build

Owner-facing. Tick every line before a build goes to Google Play or the App Store. Context: the audit in
`docs/SECURITY_AUDIT_2026-11-08.md` and ADR-019 (encrypted, pinned LAN transport). Items marked
**owner** need an account, a key or a decision only the owner can make; nothing here generates or
stores a signing key in the repository.

## 1. Code gates (run on the release commit)

- [ ] `cargo fmt --all --check`
- [ ] `cargo clippy --workspace --all-targets -- -D warnings`
- [ ] `cargo test --workspace`
- [ ] `cargo deny check` (advisories, licences, sources; `rustls`, `tokio-rustls`, `rcgen` and `ring` are approved)
- [ ] `fvm dart analyze` and `fvm dart format --set-exit-if-changed .` in `app/` and in each package
- [ ] `fvm flutter test` in `app/`, `packages/poker_protocol`, `packages/poker_bridge`
- [ ] Native TLS interop: `cd packages/poker_bridge && cargo build -p rust_lib_poker_bridge && POKER_BRIDGE_LIB=$PWD/../../target/debug/librust_lib_poker_bridge.so fvm flutter test test/native_tls_test.dart`
- [ ] `bash tool/check_web_safe.sh` and `bash tool/check_no_state_logging.sh`
- [ ] End-to-end suite on the real stack (22 scenarios, about 15 s): `cargo build -p rust_lib_poker_bridge && cd app && POKER_BRIDGE_LIB=$PWD/../target/debug/librust_lib_poker_bridge.so fvm flutter test test/e2e`. Every scenario must pass; the matrix of events it covers is `docs/SECURITY_AND_EDGE_CASES.md` section 8. It runs headless on one machine, so it does not replace section 2 below.
- [ ] CI is green on the pushed branch, including the desktop build workflow (it is the first place the `ring` crate is compiled for Windows and macOS) and `cargo deny`
- [ ] GitHub Actions in the workflows are still pinned to full SHAs (Dependabot PRs update them; read each one)

## 2. Run it on real devices (an emulator pass was done 2026-11-08; no physical phone yet)

An Android emulator pass (2026-11-08, `docs/SECURITY_AND_EDGE_CASES.md` section 8) covered install, first run, hosting with the foreground service, joining over TLS both ways, a full hand, a vanished host, a changed certificate and a solo game in the background. It also found three defects that the unit tests had missed (the keyboard closing at once on tall screens, a host table that never showed a guest as connected, validation messages that stayed after the fix); they are fixed in 1.4.0. The headless end-to-end suite already proved the join, play, reconnect, host restart, moved port, wrong certificate and old-host cases over real TLS sockets. What it cannot prove is the phone itself: camera, radio, OS background rules, release build. The lines below are only those.

- [ ] Host on a physical Android phone, join with **two** other phones: once by QR code, once by room code, once by typed address. Play a few hands. Confirm each joins.
- [ ] Wrong host: scan the QR of host A, then change host A's certificate (delete `tls-identity.bin` through a reinstall or clear data) and reconnect: the guest must stop with "not the host you meant", keep its seat data, and never connect.
- [ ] Old host, new guest: a 1.3.1 host and a new guest. The guest must say the host runs an older version. (1.3.1 hosts and TLS builds cannot play together; say so in the release notes.)
- [ ] Lose Wi-Fi mid-hand on a guest, then return: the seat resumes (pinned) without asking again.
- [ ] Kill the host app and reopen it: the same QR (same pin) still works for guests who were seated.
- [ ] QR scannability: the QR now carries a 43-character fingerprint at error-correction level L. Scan it from another phone at arm's length in the compact landscape layout (smallest QR) and on a tablet.
- [ ] iOS: the first run asks for the Local Network permission; joining by code and by QR works after allowing it.
- [ ] Solo game on a physical phone: start, background and return, save and exit, resume.
- [ ] Release build only: install the **release** APK or AAB build (R8 and minification can break reflection-based code), host and join once. Check `adb logcat` for crashes in the first minute.
- [ ] Battery: a 30-minute hosted game with the screen on; the foreground service notification appears and disappears correctly.

## 3. Android (Google Play)

- [ ] **owner:** Create the upload key once and keep a backup in two places (a password manager and an offline copy). Do not commit it.
  `keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload`
- [ ] **owner:** Create `app/android/key.properties` (already git-ignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
- [ ] Build the bundle with the switch that refuses the debug key:
  `cd app && REQUIRE_RELEASE_SIGNING=1 fvm flutter build appbundle --release`
  The build must fail if `key.properties` is missing. A warning that says the debug key is used means the build is **not** for the store.
- [ ] Enrol in **Play App Signing**; upload the AAB signed with the upload key.
- [ ] Target API level: this Flutter (`.fvmrc` 3.41.9) targets what `flutter.targetSdkVersion` says; compare it with the minimum Play requires on the day you submit, and upgrade Flutter first if it is lower.
- [ ] **Data safety form.** The app has no accounts, no analytics, no crash reporting and no server of ours. Game data goes only between the players' own devices on their local network and, for a solo game, stays on the phone; names and tokens stay on the device. Camera: scans the join QR code only, nothing is stored or sent. Answer the form from that, and re-check it against Play's wording when you fill it in.
- [ ] **Privacy policy URL** (Play requires one even for an app that collects nothing). Host a short page; say what the Data safety form says.
- [ ] **Foreground service declaration** (`specialUse`): use the subtype text from the manifest, "Hosts a local poker game for other devices on the same network", and attach the short demo video Play asks for (`docs/DEPLOY.md`).
- [ ] Content rating questionnaire. The app is a poker game with play chips, no real money, no purchases. Answer the gambling questions honestly (simulated gambling); check the category and age rating you get.
- [ ] Permissions screen in the Console matches the manifest: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `WAKE_LOCK`, `CAMERA`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`.
- [ ] Release notes mention: the LAN connection is now encrypted; scanning the host's QR code is the safest way to join; hosts and guests must both be on the new version.

## 4. iOS (App Store). iOS has never been built from this repository

- [ ] **owner:** Apple Developer account, bundle identifier, signing certificate and provisioning profile. Build on a Mac: `fvm flutter build ipa`.
- [ ] Confirm the Rust library builds for `aarch64-apple-ios` (and the simulator) with `ring`. This is not proven.
- [ ] Add `ios/Runner/PrivacyInfo.xcprivacy` with the required-reason API declarations this app and its plugins use (file timestamp, user defaults, disk space, system boot time). Check each plugin's own manifest, and that no tracking is declared.
- [ ] Local Network permission text is in `Info.plist` (`NSLocalNetworkUsageDescription`); camera text is there too. Re-read both for clarity.
- [ ] Export compliance in App Store Connect: the app uses standard TLS (rustls, and the BoringSSL inside the Dart runtime). Answer the questions, and decide `ITSAppUsesNonExemptEncryption` from the answers; this is a legal decision for the owner, not made here.
- [ ] iOS suspends a hosting app in the background (documented in `docs/DEPLOY.md`); say "keep the app open while hosting" in the store text.
- [ ] Review the Guideline 5.3 (gambling) rules for a play-money poker app; keep the "no real money, chips are counters" wording visible in the description.

## 5. Desktop packages (GitHub releases)

- [ ] **owner:** Decide on code signing. Windows installers and the Linux tarball are unsigned; SmartScreen warns. Publish `SHA256SUMS` and verify it on download. A Windows signing certificate is the fix (audit F8).
- [x] The first desktop build with the TLS crates ran green in CI for Linux and Windows (run 42419140147, 2026-11-08). Re-check on the release commit; macOS is not built by that workflow.

## 6. Terms and copy

- [ ] **owner:** Legal review of `app/lib/util/terms_content.dart`. It is plain-language text, not legal advice. It now says the connection is encrypted and that joining by QR code is the safest way; confirm that matches what you want to promise.
- [ ] If the terms change in a way that matters to players, raise `currentTermsVersion` in `app/lib/model/app_settings.dart` so everybody accepts again.

## 7. Before you press publish

- [ ] Version bump in `Cargo.toml`, `app/pubspec.yaml` (build number must go up) and the changelog.
- [ ] Tag the release commit once the builds you uploaded are the ones from that commit.
- [ ] Keep the upload key backups, `key.properties` and its passwords out of the repository, chat, CI logs and screenshots. If any of them leaks, rotate the upload key with Play support.
- [ ] Re-read `docs/SECURITY_AUDIT_2026-11-08.md` "Residual risks" and accept or fix each one.

## Microsoft Store (Windows)

Owner-facing. The whole route, the Partner Center fields and the account steps are in `docs/MICROSOFT_STORE.md`. Before each Store update: version bumped in `app/pubspec.yaml` (the MSIX version is `major.minor.patch.0`), `PRIVACY.md` and Settings > Privacy policy still true, screenshots remade if a screen changed (`docs/MICROSOFT_STORE.md` section 6), the `poker-credits-msix` artifact built with the real identity variables (never the `PLACEHOLDER` file).

Automatic submission (`docs/MICROSOFT_STORE.md` section 9): a stable tag `vX.Y.Z` on a commit that is on `main` starts `store-publish.yml` once the secrets exist; check the run, then Partner Center (draft: press Submit; `MSSTORE_AUTO_COMMIT=true`: it is already in certification).
