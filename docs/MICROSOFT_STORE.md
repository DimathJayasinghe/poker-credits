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

1. Partner Center > Apps and games > New product > **Game** (not "MSIX or PWA app": Microsoft's page says "If you want to submit MSIX or PWA game, click on Game", and a game filed as an app is rejected under policy 10.1.21, see section 9). Reserve the name **Poker Credits** (a
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
| Pricing and availability | Free; markets: Markets > Show options > Market selection popup, untick **Türkiye** and **China (ISBN Required)** (see section 10); visible to everyone; publish as soon as certification passes; no trial |
| Properties | Category **Games**, genre **Card + board** (a game needs at least one genre, up to three; do not pick Casino, it is described as games that let players gamble online). Privacy policy: paste `PRIVACY.md`, or its URL once it is on `main` (<https://github.com/DimathJayasinghe/poker-credits/blob/main/PRIVACY.md>). Website and support contact: the repository and its issues page. Win32 products always need a policy (10.5.1) |
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

## 9. Automatic submission: tried, not used

The Store Developer CLI can submit a package from GitHub Actions, but it needs a Microsoft Entra application with the
Manager role, and that needs a tenant linked to the Partner Center account. On the owner's individual account
(2026-11-08) Account settings > User management only offered "Sign in with Microsoft Entra ID", and that page kept
loading and crashed, so no application could be added. Decision: ADR-022. Every release is uploaded by hand
(section 5): download `poker-credits-msix` from the "Desktop builds" run of the version tag, then Product > Update >
Packages. If the account ever gets a tenant, Microsoft's guide is "Publish app updates to Microsoft Store with GitHub
Actions" on Microsoft Learn.

## 9. Rejected once: 10.1.21 Inaccurate Representation (2026-11-09)

The first product was created as **MSIX or PWA app** with category **Entertainment**. Certification of 1.4.0.0 failed with: "The game is assigned to an app category but has game functionality. Please create a new game in a game category." Microsoft's category page says you "can't choose the Games category when updating an app that you previously published in a different category" and that a game has to be a product of type **Game** with the **Games** category and at least one genre (<https://learn.microsoft.com/windows/apps/publish/publish-your-app/msix/categories-and-subcategories>). The fix is a new product of type Game; steps 1 to 4 of section 3 are repeated for it, and if its Product identity values differ from the old product's, the three `MSSTORE_*` values are replaced and the package is rebuilt, because the Store compares the manifest identity with the product identity. This guide used to say "MSIX or PWA app" and "Entertainment"; both were wrong for a game.

The Game product's Properties page also asks for Game settings; the answers and the source of the definitions are in `packaging/windows/store/listing.md` (Properties). "Local multiplayer" means players connected through a local network, not one shared device.

## 10. Rejected twice: 11.10.3 Region Specific Requirements, Türkiye (2026-11-09)

The Game product (Store ID 9P9FSHQD11V3, package 1.6.0.0) then failed with **11.10.3**: "The product or its associated metadata contains references to content not allowed in Turkiye including simulated gambling. Please remove the content or deselect Turkey as a targeted market." The report's "Found In" line was an unfilled template placeholder. The public Store Policies page (version 7.20) has no 11.10.3; its 11.10 names only China, and 11.14 bans only *real-money* gambling in Brazil, Chile, China, Russia, Singapore, Taiwan, the United States, Korea and India. So the Türkiye rule comes from the certifier, not from published policy text. Poker is the whole app, so the content cannot be removed: the fix is to deselect the market.

- **Where:** Pricing and availability > Markets > **Show options** > Market selection popup (an "All markets" dropdown, a search bar, "Unselect all", OK), then **Save draft**. Removing a market affects new acquisitions only.
- **Also advised:** untick **China (ISBN Required)** (the list itself marks it as needing a Chinese game licence, and 11.10 names China for content illegal under local law). Every other market stayed ticked, including those with gambling-specific IARC ratings (Indonesia, Saudi Arabia); no document says they are blocked. If a later report names another market, remove it the same way.
- **What went wrong in the guide:** it said "Update" would start a new submission. On 2026-11-10 the failed product showed **Product submission: In draft** with **Delete submission** and **Resubmit for certification**, and **Pricing and availability** was **Read only** (it seems to stay locked once sent). The owner deleted the draft and started again with **Start submission**; that new submission was blank, so every page was entered again from `listing.md`. Lesson: set the markets in the first submission; a locked module cannot be fixed in place.
- **Outcome:** the owner reported the product published on the Store on 2026-11-10; the page <https://apps.microsoft.com/detail/9P9FSHQD11V3> answers 200. Which markets were actually unticked was not confirmed back, so check Pricing and availability before the next submission.

The wording "Product > Update > Packages" in section 5 (and in `docs/RELEASE_CHECKLIST.md` and ADR-022) was written before this and is not what the failed product showed; for the next version, open the product's overview and use whichever of **Start submission** or **Update** it offers, then read the page before clicking.
