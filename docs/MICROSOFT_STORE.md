# Microsoft Store

How Poker Credits gets into the Microsoft Store as a **free Windows app (MSIX)**, what the repository already
provides, and the steps only the owner can do (the Partner Center account and its values). Policies quoted below
are Microsoft Store Policies v7.20 (effective 2026-10-22); read the current page before every submission:
<https://learn.microsoft.com/windows/apps/publish/store-policies>. Decision record: ADR-021.

## 1. Why MSIX and not the EXE type

Partner Center has two Windows product types: **MSIX or PWA app** and **EXE or MSI app**. The EXE type needs
the installer and every `.exe` and `.dll` inside it signed with a certificate from a trusted CA (policy 10.2.9;
<https://learn.microsoft.com/windows/apps/publish/publish-your-app/msi/app-package-requirements>), a silent
install, a standalone installer and an HTTPS download link that never changes after submission. Our Inno Setup
installer is unsigned and the Store does not sign EXE or MSI packages. An **MSIX package is signed by the Store
itself** after certification, so nothing has to be bought. The GitHub release keeps the installer and the zip for
people who download directly.

## 2. What the repository provides

| What | Where |
| :--- | :--- |
| Package manifest template (identity placeholders, capabilities) | `packaging/windows/msix/AppxManifest.xml.in` |
| Logos for the package (generated from `branding/logo.svg`) | `packaging/windows/msix/Assets/`, regenerate with `python3 packaging/windows/build_msix_assets.py` |
| Stage and check script | `tool/msix_stage.py` (`--check` validates the template; CI runs it) |
| CI: builds `poker-credits-windows-x64.msix` | the Windows leg of `.github/workflows/desktop-builds.yml`, artifact `poker-credits-msix` |
| Listing text, answers for the questionnaires, restricted-capability text, certification notes | `packaging/windows/store/listing.md` |
| Listing logos (300 x 300, 1080 x 1080) and screenshots (1920 x 1080) | `packaging/windows/store/` and `packaging/windows/store/screenshots/` |
| Privacy policy (in the app under Settings, and for the Store) | `PRIVACY.md`, `app/lib/util/privacy_content.dart`; a test keeps them equal |

Capabilities declared (policy 10.6: each must relate to a function): `internetClient` (a server address typed outside
the local network), `privateNetworkClientServer` (host and join on the local network) and the restricted
`runFullTrust` (the app is a normal Win32 program). No camera and no microphone: the Windows app has no QR scanner.
`tool/msix_stage.py --check` fails if the list changes without this page and `PRIVACY.md` being updated.

## 3. One-time owner steps (Partner Center)

1. Partner Center > Apps and games > New product > **MSIX or PWA app**. Reserve the name **Poker Credits** (a
   reserved name is held for a limited time; if it is taken, pick a variant without marketing words, policy 10.1.1).
   Choose an individual account name as publisher; a name that reads like a company needs a company account
   (policy 10.14).
2. Open the app > Product management > **Product identity**. Copy three values exactly:
   `Package/Identity/Name`, `Package/Identity/Publisher` (starts with `CN=`) and
   `Package/Properties/PublisherDisplayName`.
3. GitHub: repository > Settings > Secrets and variables > Actions > **Variables**: create
   `MSSTORE_IDENTITY_NAME`, `MSSTORE_PUBLISHER`, `MSSTORE_PUBLISHER_DISPLAY_NAME` with those values. They are
   identifiers, not secrets (a repository *secret* of the same name also works; CI reads either, but a secret's value is hidden in the logs). Without them CI builds a package named `...-PLACEHOLDER-do-not-submit.msix`, which
   proves packing works and **must never be uploaded**.
4. Run the **Desktop builds** workflow (Actions tab; it also runs on a pull request that changes
   `packaging/windows` and on version tags). Download the artifact `poker-credits-msix`.

## 4. The submission, page by page

Values for every text field are in `packaging/windows/store/listing.md`. Order does not matter; Microsoft
re-checks everything at submission.

| Page | What to enter |
| :--- | :--- |
| Pricing and availability | Free; all markets; visible to everyone; publish as soon as certification passes; no trial |
| Properties | Category Entertainment. Privacy policy: paste `PRIVACY.md`, or its URL once it is on `main` (<https://github.com/DimathJayasinghe/poker-credits/blob/main/PRIVACY.md>). Website and support contact: the repository and its issues page. Win32 products always need a policy (10.5.1) |
| Age ratings | The IARC questionnaire, answered truthfully (answers and the result, **Microsoft 18+**, are in `listing.md`). Policy 11.14 (gambling) applies to "real-world gambling transactions" and "payout of winnings which can be converted into items of real-world value"; the chips here have no value and nothing is paid out |
| Packages | Upload `poker-credits-windows-x64.msix` (x64). The Store checks the identity in the manifest against the product identity and signs the package |
| Store listing | English (US): description, short description, features, search terms (at most seven, policy 10.1.3), screenshots, logos, copyright line |
| Submission options | Restricted capability `runFullTrust`: paste the justification from `listing.md`. Notes for certification: paste from `listing.md` |

Certification takes up to a few business days. A failure comes with a report naming the policy.

## 5. Every later update

The MSIX version is `major.minor.patch.0` taken from `app/pubspec.yaml` (`1.4.0+9` becomes `1.4.0.0`); the Store
refuses a version that is not higher than the last one and refuses a last part other than 0. So each Store update
needs a version bump (the usual release flow does that), then a new package from CI, then Product > Update >
Packages. Keep `PRIVACY.md` and Settings > Privacy policy current; if the app starts to collect or send data in a
new way the policy changes first (policy 10.5.1) and the date in `privacy_content.dart` is raised.

## 6. Remaking the screenshots

The listing screenshots are renders of the real screens (the same fakes and fonts as the golden tests) at
1920 x 1080 in the app's Windows desktop layout:

```bash
cd app
STORE_SHOTS_DIR=$PWD/../packaging/windows/store/screenshots fvm flutter test test/store
STORE_SHOTS_DIR=$PWD/../packaging/windows/store/screenshots fvm flutter test test/pages/solo_table_test.dart --plain-name "store screenshot"
```

Without `STORE_SHOTS_DIR` those tests are skipped. Remake them when a screen changes; the listing must show what
the app really looks like (policy 10.1).

## 7. Checks

- `python3 tool/msix_stage.py --check` (manifest parses, version shape, capability list, executable name, logo files and sizes).
- CI packs the stage folder with `makeappx pack`, which validates the manifest against Microsoft's schema.
- Optional, on a Windows PC: install the Windows SDK, install the signed-for-test package or run the kit on the
  package file, and run the **Windows App Certification Kit** (`appcert.exe test -appxpackagepath <file> -reportoutputpath <report.xml>`),
  see <https://learn.microsoft.com/windows/uwp/debug-test-perf/windows-app-certification-kit>. The Store runs
  the same kit during certification.

## 8. Not verified

- A package has not been built here: `makeappx` exists only on Windows. The first CI run of the Windows leg is the
  first real check of the manifest. If `makeappx` rejects it, the job goes red after the zip and installer were
  already uploaded.
- The app has not been run from an installed MSIX (virtualised AppData, the firewall prompt when hosting, the
  secure storage under the package). The first install from the Store or a test-signed package on a Windows PC is
  the check.
- The Windows build has never been run on a Windows machine by the assistant; CI builds it.
- The app is rated **18+** (simulated gambling, gambling themes a strong focus). Policy 11.1 says listing text and
  screenshots may only contain content that would merit PEGI 12, ESRB Everyone 10+ or lower. Our text and pictures are
  plain poker, but how a reviewer applies that rule to an 18+ poker app is unknown; if they object, soften the text.
- The Partner Center pages change; field names here were taken from Microsoft Learn on 2026-11-08.
- Automatic submission (section 9) has never run: `.github/workflows/store-publish.yml` was written from Microsoft Learn
  (Store Developer CLI and "Publish app updates with GitHub Actions"), not tested against a live product, and it is
  not known whether an individual account can link a Microsoft Entra application (see 9.1).

## 9. Automatic submission from CI (optional, after the first release is live)

`.github/workflows/store-publish.yml` sends the package of a **stable version tag** to Partner Center, so a release
needs no upload by hand. Decision and limits: ADR-022.

**How it runs.** You merge to `main`, bump the version, and push a tag `vX.Y.Z` (the usual release flow). The tag
runs "Desktop builds", which makes `poker-credits-msix`. When that run succeeds, "Microsoft Store publish" starts, checks
that the run was a tag `vX.Y.Z` on a commit that is on `main`, downloads that package, refuses the placeholder
package or a package whose version differs from the tag, and calls `msstore publish`. Pushes to `main` without a tag do
nothing, on purpose (ADR-022). Without the secrets below it logs a notice and stays green.

### 9.1 One-time setup

1. **First release by hand.** The API only updates a product that is already live: finish the submission in section 4
   and wait until the Store shows the app.
2. **A tenant, then a Microsoft Entra application for the API.** An individual account signs in with a personal
   Microsoft account, so User management first shows only "Sign in with Microsoft Entra ID" (seen 2026-11-08: that page
   kept loading and never opened). It needs a tenant linked to the account: Account settings > Organization profile >
   **Tenants** > "Create Microsoft Entra ID" (or "Associate" an existing one), per Microsoft Learn. Only then sign in
   there with the tenant's own account and use Microsoft Entra applications. **Unknown whether the individual account
   can finish this** (the Partner Center pages were unreliable); if it will not work, stop: uploading the package by hand
   (section 5) stays the route and nothing is lost.
3. In Entra register an application, give it the **Manager** role in Partner Center, copy its tenant ID and client ID,
   and create a client secret (it expires: note the date and renew it).
4. Copy the **Seller ID** (Microsoft Learn: Account settings > Developer settings or Identifiers, labelled "Publisher ID"
   or "Seller ID"; the page may differ) and the product's **Store ID** (the 12 character id on the product's overview page).
5. GitHub > Settings > Secrets and variables > Actions. Secrets: `AZURE_AD_TENANT_ID`,
   `AZURE_AD_APPLICATION_CLIENT_ID`, `AZURE_AD_APPLICATION_SECRET`, `SELLER_ID`. Store ID: `MSSTORE_PRODUCT_ID` as a
   variable (or secret). Never paste any of these into a file.
6. Optional but advised: Settings > Environments > `microsoft-store` > Required reviewers: yourself, so each
   submission waits for one click.

### 9.2 Draft first, then fully automatic

Until the repository variable `MSSTORE_AUTO_COMMIT` is `true` the workflow only prepares a **draft** submission
(`--noCommit`); open Partner Center and press Submit. After one or two releases that went well, set the variable to
`true` and the workflow submits for certification by itself. Certification still takes Microsoft's usual time and a
rejection arrives by e-mail: the Store, not the workflow, decides what goes live.

### 9.3 By hand and when it fails

- Actions > Microsoft Store publish > Run workflow, with the id of a successful "Desktop builds" run on a tag, to
  retry without a new tag.
- "cannot read run", "not a stable version tag", "not on main": the run is not one this workflow accepts. Tags with a
  suffix (`v1.5.0-rc1`) are skipped on purpose.
- "package version does not match tag": bump `version:` in `app/pubspec.yaml` before tagging.
- `msstore publish` errors about a submission already in progress: the Store allows one at a time; finish or delete the
  pending one in Partner Center.
