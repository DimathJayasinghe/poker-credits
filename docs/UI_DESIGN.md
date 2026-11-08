# UI Design: Editorial Brutalism

Decision: ADR-015 (supersedes the look chosen in ADR-013; the structural rules of ADR-013, own components and no platform widgets, stand). Applies to every screen on every platform, including the future web build.

Why the change: the first look (3 px outlines, hard offset shadows, signal yellow, thick fills) was tiring to watch for a whole evening, and the app had one screen and no reason to come back to it. The new direction takes its cues from two references the owner chose: a hairline cell grid, one huge condensed display face, small tracked mono labels, paper grain, warm cream with one vermilion accent, and a dark counterpart.

## 1. Principles
1. **Quiet chrome, loud numbers.** Lines are hairlines, fills are flat, nothing blurs or glows. Chips, pot and turn state are the biggest things on screen; everything else steps back.
2. **Structure is information.** The page is a grid of cells divided by shared lines, like the reference nav bars. A line means "these belong together" or "this is a different thing". Lines are never decoration.
3. **One loud thing per screen.** The home screen's stacked-echo title; on the player screen the YOUR TURN block; on the table the pot. Everything else is quiet.
4. **Turn state is the accent.** Only the seat that must act (and the control that acts) takes the vermilion `accent` fill. Colour is never the only signal: a label or tag always accompanies it.
5. **Two real themes.** Paper (light) and Night (dark), each designed, not inverted. The user picks System, Light or Dark in Settings.
6. **Readable in a dim room, at arm's length, on a TV.** High contrast, large numerals, 48+ px hit targets (56 on the player's action row).
7. **Fast and offline.** Fonts and texture are bundled. Motion is short and answers an action; state changes never wait for animation.
8. **Same look everywhere.** Components are our own, so iOS, Android, desktop and web match.

## 2. Tokens (implemented once in `app/lib/theme/tokens.dart`)

### Colour
| Token | Paper (light) | Night (dark) | Use |
| :--- | :--- | :--- | :--- |
| `paper` | `#EFE5CF` | `#12100F` | Page background (under the grain) |
| `surface` | `#F8F1E0` | `#1B1816` | Raised cells: cards, inputs, sheets |
| `ink` | `#15120F` | `#F2E8D2` | Text, lines, filled "ink" buttons |
| `accent` | `#B52D14` | `#FF5A36` | Whose turn it is, the primary action, errors |
| `onAccent` | `#FFF6E6` | `#12100F` | Text on `accent` |
| `felt` | `#143A2B` | `#0F2E22` | The table panel (the "photo slot" of the layout) |
| `onFelt` | `#F2E8D2` | `#F2E8D2` | Text on `felt` |
| `chip` | `#E8A23A` | `#F0AE48` | Pot block and chip marks; text on it is always `#15120F` |
| `muted` | `#5C5547` | `#A89F8D` | Secondary text; at least 4.5:1 on `paper` and `surface` |
| `line` | = `ink` | = `ink` at 85 % | Every hairline |

Rules: text on `accent` is `onAccent`; text on `chip` is dark; state is never colour alone (folded seats say FOLDED and are struck through; all-in seats carry an ALL-IN tag; the acting seat also carries `>` and the countdown). The earlier `signal`, `danger` and `info` hues are retired: **fold** is the outlined button, **call/check** the ink-filled one, **raise** the accent one, so meaning rides on position and label, which also keeps it readable for colour-blind players.

### Texture
A bundled 192 px noise tile (`assets/images/grain.png`) is tiled over `paper` at 7 % (Paper) or 5 % (Night) opacity by `PaperBackdrop`. It sits behind content only, never over text. Settings has a Texture switch (off = flat colour) for low-end devices and for people who find it busy.

### Type
Fonts are **bundled** (SIL OFL, licences beside the files), never fetched.
| Role | Font | Notes |
| :--- | :--- | :--- |
| Display, numerals | **Anton** | Condensed, heavy. Titles, pot, stacks, big buttons. Line height 0.95, uppercase by presentation. |
| Labels, body, data | **Space Mono** | 12-14 px, tracked +1.0 for labels. Tabular, so counting chips does not jitter. |

Scale (logical px, scaled by the OS text setting): 12 label, 14 body, 18 lead, 28 heading, 44 title, 64 stack, 96 pot, 120 hero. Layouts must hold at text scale 2.0 (tested).

### Type scale (`BrutalType` in `tokens.dart`)
| Role | Size |
| :--- | ---: |
| Page headline (Anton) | 34 |
| Section heading (Anton) | 26 |
| Row label: primary (Home) / dense (lists of settings and links) | 26 / 21 |
| Reading text (Space Mono), line height 1.5 | 14 (15 in walkthroughs) |
| Captions and small uppercase labels | 12 |

New screens use these and never a size of their own. Lists of settings and links use `BrutalRow(dense: true)`; only the two Home actions keep the large row. A section of reading text is one cell (`GuideBlock`: heading then paragraph), not two.

### Shape, line, space
| Token | Value |
| :--- | :--- |
| `radius` | 0 |
| `hairline` | 1.5 px `line` (all dividers and cell borders) |
| `rule` | 3 px `line` (the single underline or frame that anchors a screen) |
| `shadow` | none |
| `gap` | 4, 8, 16, 24, 32, 48 |
| `tap` | min 48 x 48; 56 high on the player action row |

Pressed state: the cell inverts (`ink` fill with `paper` text, or `accent` darkens), eased over `fast`, and **held for at least 140 ms** so a quick tap still shows it (`BrutalPressable` does this for every tappable cell; do not add a bare `GestureDetector`). No offset movement, no ripple. Disabled: 45 % opacity with a diagonal hatch.

### Motion
`fast` 90 ms, `base` 160 ms `easeOut`, `max` 280 ms. Motion only answers an action (press, open, change). One exception: the home title's echo layers draw in once, 400 ms, on first launch of the app session. Reduced motion (OS flag) makes everything 0 ms.

## 3. Components (`app/lib/widget/brutal/`, restyled in place)
| Widget | Description |
| :--- | :--- |
| `BrutalButton` | Rectangular cell with a hairline; kinds: `primary` (accent fill), `ink` (ink fill, the old `info` is mapped here), `neutral` (outlined), `danger` (outlined, accent text). `heavy` = taller, Anton label. |
| `BrutalRow` (new) | Full-width list row: label left, arrow cell right (`NavArrow`, drawn, not a glyph). The reference's SALE / TEAM / SPONSORSHIP rows. Used for home actions and Settings navigation. |
| `BrutalCard` | `surface` cell, hairline border, optional caption strip. |
| `BrutalTag` | Small boxed label: D, SB, BB, ALL-IN, FOLDED, AUTO, WATCHING. |
| `BrutalSegmented` (new) | Two to four equal cells, the chosen one inverted. Theme choice, small enums. |
| `BrutalSwitchRow` (new) | Label, one-line explanation, and a square switch. |
| `BrutalSlider`, `BrutalKeypad` | Hairline track, square thumb, ticks; the number in Anton. |
| `BrutalBanner` | Full-width strip: reconnecting and paused (ink with hatch), errors (accent). |
| `BrutalDialog`, `BrutalSheet` | `surface` panels with a hairline top rule; sheets slide in with `base`. A sheet's header (title and a CLOSE cell) never scrolls, so there is always a visible way out even when the sheet fills a short screen. |
| `TopBarStat` | A labelled value in a game top bar: a small muted label over the value in Anton, behind a hairline (ROOM / HMB5, HAND / 7, PHASE / PRE-FLOP). Accent colour only for something that needs attention. |
| `BrutalTextField` | Hairline box on `surface`, label above, error line in accent below. |
| `PaperBackdrop` (new) | Paints `paper` plus grain behind every route (installed once in `MaterialApp.builder`). |
| `EchoTitle` (new) | The hero wordmark: solid Anton text with three outlined copies stepped up-left (the reference 1 effect). Home only. |
| `AppFrame` (new) | Top bar (cells: mark, room or section title, actions) and bottom bar (cells: nav), sharing the hairline grid. |

All widgets are plain Flutter (`DecoratedBox`, `CustomPaint`); no platform widgets.

## 4. Information architecture
**Status: PLAY, GUIDE and SETTINGS are built.** The GUIDE tab also opens as a quick-guide sheet from the `?` cell on the Player and host Table top bars. Three destinations in a bottom bar on phones and a left rail on wide screens (>= 840 px):

| Destination | Purpose |
| :--- | :--- |
| **PLAY** | Host a game, join with a code, resume the game this device was in. |
| **GUIDE** | How a night works in four steps; hand rankings (a ranked sequence, so numbered); betting words; what to do when the Wi-Fi drops. Static, offline, useful at the table with real cards. |
| **SETTINGS** | Appearance, table, you, data, about (section 6). |

Game screens (Table, Player, Spectator) are full screen routes without the bar, so nothing competes with the game.

**Back rule:** every pushed route has a visible back arrow (`BackCell`, a left arrow) in its top bar, and the system back does the same thing. On Player it asks "Leave the table?" (leaving gives the seat up); on the host Table it asks "End the game?" (it ends the game for everybody); a spectator, or a game that has already ended, leaves at once. Join cancels a connection attempt; Host is locked while the server starts.

## 4b. No scrolling (1.3.1)
**Rule:** outside Settings, the Guide and the terms text, no screen scrolls. Every control, every number and every player is on screen at once, on every standard phone (Android 360x640 up to a Pro Max, iPhone SE to 16 Pro Max, with their system bars), upright and on its side, on tablets and in a desktop window. A game screen needs this most (a scroll in the middle of a hand costs a turn); the screens around it follow the same rule so the app feels one piece.

**What gives way, in this order:** (1) gaps and padding, (2) captions and hints (one line, then none), (3) the size of decoration (wordmark, QR code, plate and card sizes, never below the 44 px tap minimum), (4) layout (two columns or a right-hand pane on a phone on its side, a grid instead of an oval), (5) the size of the text, on game screens only. Things never drop out: a control, a number or a name is either on screen or in one tap (a sheet).

**How (code):**
- `FitPage` (`app/lib/widget/brutal/fit_page.dart`): a fixed top bar, a body and an optional footer. It picks a `FitTier` (comfortable, compact, tight) from the height it has (plus the keyboard's share of it, see below) divided by the text scale, tells the content with `FitInfo`, and puts the main action in a footer that is outside the scrolling area (a right-hand pane on a phone on its side). `FitSection` and `FitHeader` draw a labelled group and a headline in the size of the tier.
- Game screens: `PlayerFit` (player) and `TableFit` (host table: tiers `roomy`, `snug`, `tight`, with plate, button, pot, card and QR sizes; `FeltLayout` falls back from the oval to a grid, and the grid takes as few columns as keep every plate at its least height).
- Plates and rows adapt to the height they are given instead of the device: `SeatPlate` has a standard and a dense form, `BrutalRow` a dense and a snug one.
- Sheets (seat order, winners, raise) hold their content without scrolling; on a phone on its side they get wider (`wideSheetWidth`) and lay their cells out in columns. A list that comes from data (the winners of a showdown) scrolls inside its own box while its confirm button stays pinned.

**The keyboard must not change the layout (1.4.0).** A field is rebuilt in another place of the tree when a page moves to another tier, and a rebuilt field loses its focus: the keyboard used to open and close again at once on tall phones and tablets (found on an Android emulator; 1.3.1 shipped with it). So the tier and the side-by-side switch are worked out from the height the page would have without the keyboard (`FitPage.keyboardTake`, which adds back what the window took out of `MediaQuery.padding` as `viewInsets` grew). The keyboard may still make a page scroll as a last resort. `keyboard_focus_test.dart` opens the keyboard in three frames on five device sizes, with a bare `MediaQuery` and with one that behaves like a real window.

**Text size.** Non-game screens never cap the text scale; they are drawn denser, and past 1.3x or with the keyboard open they may scroll as a last resort (the scroll view stays in the tree as a guard, the main button stays pinned outside it). Game screens cap the scale to what fits, by height: the player screen at height over 555, the host table at usable height over 560 upright and over 330 on its side (never over 2). The wordmark and big numerals do not scale with text.

**Deliberate exceptions.**
- Settings, the Guide and the terms document scroll (they are documents or lists of unknown length). On the terms screen the "I am 18+ and I agree" switch and the Accept and Decline buttons are a footer that does not scroll, so the decision is always reachable (the footer takes at most 60% of the height and scrolls inside that only at huge text).
- The Nearby games list scrolls when many games are found.
- The host table's seat list may scroll inside its own box, with the pot, cards and every button fixed, in one case only: a seated host who plays with cards in the app, on their turn, with ten seats, on the smallest phones (seat plates would otherwise fall under 60 px).
- The error screen shown when the app fails to start scrolls its report; the copy button stays pinned.
- The Host name field no longer takes focus on open (the keyboard would cover half of a short screen at once); with a keyboard open any page may scroll.

**Checks.** `test/pages/no_scroll_test.dart` and `no_scroll_more_test.dart` (menus, setup pages, join, host, support, intro, terms buttons, tours, the poker lesson, Home with a game to resume, the spectator table, and keyboard-open cases) and `table_no_scroll_test.dart` (the host table in eight scenes and its sheets) measure the scroll extent of every screen on 18 device sizes (`test/support/devices.dart`) at text 1.0 and 1.3, and fail on any scroll above half a pixel or any exception. `solo_table_test.dart` does the same for the player screen.

## 5. Screens

### Play (home)
```
+--------------------------------------------------------+
| [mark] |                              |  [settings]    |  top bar cells
+--------------------------------------------------------+
|  POKER                                |                |
|  CREDITS   <- EchoTitle, 120, Anton   |  felt panel    |
|  tagline, mono 14                     |  (wide: table  |
+---------------------------------------+  drawing, chips|
| HOST A GAME                        [↗]|  and "ROOM"    |
| JOIN WITH A CODE                   [↗]|  code sample)  |
| RESUME ROOM KQ7M  (only if stored) [↗]|                |
+---------------------------------------+----------------+
| PLAY            | GUIDE        | SETTINGS               |
+--------------------------------------------------------+
```
Phone: single column, the felt panel becomes a 160 px band under the title. The resume row, when present, is first and carries the accent.

### Table (landscape or tablet, host)
Top bar cells: room code | hand and street | Pause | Undo. Centre: the `felt` panel with the pot block (`chip` fill, Anton 96) and seat plates on an oval path as hairline cells. The acting seat plate is the only accent fill, with its countdown as a 3 px bar. Ticker row of the last actions under the grid. Host controls: the next step (START HAND, BEGIN SHOWDOWN, RESOLVE) is one full-width heavy button on its own row; the rest (Seats, Pause, Undo, End game) sit under it in a grid of equal cells, two or three per row. When the host is on turn, YOUR TURN and the action row appear above the controls. On a phone on its side the seats stay on the left and everything the host presses is a pane on the right; the host's own cards sit in that pane. The whole table fits without scrolling (4b).

### Player (portrait, one thumb)
Top bar: room, connection state. Hero cell: stack in Anton 64, bet beside it. Middle: whose turn (quiet `surface` cell) or, when acting, a full-width accent YOUR TURN cell with the countdown. Bottom third: FOLD (outlined), CHECK or CALL n (ink), RAISE (accent); raise opens the slider sheet. Haptics unchanged.

**No scrolling (1.3.1).** A game never scrolls: the controls, my cards and every opponent are on screen at once, on every phone from 360x640 to a Pro Max, with its system bars, upright or on its side. How (`app/lib/widget/player/player_fit.dart`, `PlayerPage._controller`):
- The bottom block (my cards, the action buttons, the pause row) is pinned. The room for the buttons is kept while it is not my turn, so nothing moves when it is; a showdown gives that room to the hands.
- A tier (`roomy`, `snug`, `tight`) is picked from the height left after the system bars and banners: it sets the size of the chip count, my cards (`hero`, `hand`, `board`), the buttons (56, 52, 48), the gaps, and, on `tight`, merges the turn and the pot into one line.
- The text scale is capped to what fits (`PlayerFit.maxTextScale`: the height over 555). The middle (turn, pot, board) is the part that shrinks, never below about 0.65 of its size; below the least height the whole controller is scaled down.
- Opponents share the width (never a sideways scroll). Up to five get a cell with their two card backs; more take two rows of dense cells (name and chips only). A showdown lists the winners and my hand first, one line each, and a "+n more" line opens every hand in a sheet.
- A phone on its side (shorter than 600, much wider than tall) gets two panes: the chips, the table and the middle on the left, my cards and the buttons on the right. At a showdown the panes swap weight: the showdown takes the larger right-hand side, the buttons stay under it, and my cards move to the left under my chips.
`test/pages/solo_table_test.dart` (group "everything I need fits without scrolling") checks 24 real device sizes with their system bars, at text 1.0 and 1.3, and the biggest table (nine opponents, a six-way showdown).

**Seat order.** Seats run clockwise and are numbered 1 to 10 (seat 1 at the bottom of the table screen). Between hands the Player screen shows "Seat N: change seat" and the host controls show "Seats"; both open the seat sheet: ten numbered cells, free ones tappable for a guest, and for the host a pick-then-place move (a taken seat swaps). Names are listed clockwise under the grid so the room can check the order out loud. During a hand the sheet only explains that seats are locked.

**Table layout rule.** The oval is used only when ten plates fit around the pot without touching (`FeltLayout.ovalFits`, about five plate heights at the current text size); otherwise the plates go into a grid in seat order, in as few columns as keep every plate tall enough, and the plates get shorter (never below `TableFit.minPlate`) before anything scrolls. Nothing is ever drawn over anything else. `test/pages/table_layout_test.dart` fails on any overlap.

**Landing table.** The felt panel draws one fixed-shape table (aspect 1.7) scaled to fit and centred, never stretched to the panel.

### Spectator
The table view without controls, with a WATCHING tag in the top bar.

### Join / Host
Join: top bar title, then stacked cells: code, name (prefilled from Settings), find-or-type-address as today; one primary action. Host: room code in Anton 120, the QR beside it in a hairline cell, typed addresses in mono, START below.

### Guide
Cells separated by hairlines: a four-step strip, ten ranked hand cards (rank number, name in Anton, one plain line, the five example cards drawn as real mini playing cards), betting words as a two-column grid, "If it drops" with the reconnect story.

**Folding (1.2.1).** Each section is a `GuideSection`: a heading cell with a one-line summary and a plus/minus cell. Only "How a night works" starts open; the jump chips open a section and scroll to it; an Open all / Close all chip toggles every section. The body is built only while open, so a closed Guide is short and light. Copy per section stays under about five short items.

### Settings
After the sections below, ABOUT also holds a Terms and safety row and a Support the developer row (section 9). Rows grouped by a caption cell:
- **APPEARANCE**: Theme (System / Light / Dark), Paper texture (switch).
- **TABLE**: Sound, Vibration, Keep the screen on during a game (switches). Sound is one switch, on by default, and the only sound setting (no volume slider, no per-effect list: the phone's own volume decides how loud). Caption: "Soft sounds for your turn, chips and cards."
- **YOU**: Default name (used to prefill Join).
- **DATA**: Forget the saved game on this device (confirm dialog).
- **ABOUT**: version, protocol version, licences.
Settings persist in a small JSON file (`path_provider`, behind a platform seam; web keeps them in memory until the web build lands). They load before the first frame so the chosen theme never flashes.

## 6. Accessibility
- Contrast: body 7:1 or better; `muted` 4.5:1 or better; checked by `test/theme/contrast_test.dart` for both themes.
- Semantics label on every actionable cell; a 3 px `accent`-contrast focus outline with offset for keyboard use.
- Text scales to 3.0 without clipping or overflow on Home, Join, Host, Settings, Guide, Support, the splash, terms, intro and the tours (past 1.3x these may scroll, see "No scrolling"). The Player and host Table screens never scroll: they cap the text scale to what fits (see 4b). Widget tests (`test/pages/text_scale_test.dart`, `home_page_test.dart`) fail on any overflow at 1.0, 2.0 and 3.0 on 320x640, 390x844 and 1280x800.
- Colour never carries meaning alone (section 2). Reduced motion honoured. Texture can be switched off.

## 7. Implementation rules
- Tokens in one file; no colour literals or magic sizes in widgets (`tool/check_web_safe.sh` greps).
- `ThemeExtension<BrutalTheme>` over a minimal `ThemeData`; Material only as invisible plumbing.
- Strings in `util/strings.dart`; uppercase by presentation.
- Goldens for each component, and for Home, Player and Table, in both themes at phone portrait 390x844, tablet landscape 1280x800 and TV 1920x1080.
- Persisted settings never block start-up: a missing or corrupt file means defaults.

## 8. Virtual cards (ADR-016)

Spec and mockups: `docs/superpowers/specs/2026-11-07-virtual-cards-design.md` sections 3 and 4. What is built:
- **Card widgets** live in `app/lib/widget/cards/`: `PlayingCard` (sizes `hero`, `board`, `mini`, `tiny`; a null card is the back), `CardRow` (shrinks as a whole, never overflows), `BoardView` (five slots, so the row never changes size), `HoleCardsDock` with `FlipCard`, `ShowdownPanel`, and `suit_painter.dart`. Suits are `Path`s, not font glyphs (the bundled fonts have none, and goldens would show boxes); rank in Anton; hairline ink border, zero radius, no shadow. Cards are fixed-size graphics: they ignore the text scale and carry their name in the semantics instead.
- **Tokens** in `tokens.dart` only: `cardFace`, `cardBack`, `cardBackMark`, `suitRed`, `suitBlack`, `suitGreen`, `suitBlue`. The face is light in both themes, like a real card. `contrast_test` requires every suit colour at least 7:1 on the face in both themes. The shape of the suit always carries the meaning; the four-colour deck (clubs green, diamonds blue) only adds colour.
- **Player screen:** the other players as an opponent strip (a name and two backs each, "Folded" once out), the board under the pot, the showdown list at the end, and your two cards in a dock above the action buttons, face down until tapped. They turn back over when the app leaves the foreground and at the start of every hand. A folded player's dock says "No cards". Hands that were dealt but whose private message has not arrived yet show as backs.
- **Table and Spectator:** the board sits under the pot on the felt; each dealt seat shows two `tiny` cards in its chips row (the plate keeps its height, so the oval geometry is unchanged); at showdown the revealed faces replace the backs, winners get a WINS tag and the felt lists each pot with who won what (`PotResults`). A seated host's own cards sit in a dock: on a screen 600 px wide or more (a shared display) they show only while a finger is held on them, on a phone a tap turns them over.
- **Showdown list** (`ShowdownPanel`, Player screen): one block per revealed hand (name, category, the two hole cards, the best five lifted, a hole card that is not in the best five dimmed), WINS on winners, then a line per pot with its shares. An uncontested hand shows "Everyone else folded" and the payout only. The viewer's own line is tagged YOU.
- **Run-out pacing:** the server reveals the whole run-out at once; `RunoutPacer` shows it a street at a time, 700 ms apart. The winners, the revealed hands and the host's START HAND wait for the last card. Reduced motion shows everything at once.
- **Host controls** in virtual rooms drop BEGIN SHOWDOWN and PICK WINNERS (the server does both) and show a one-line note about what Undo can do.
- **Host form:** a CARDS cell (Real cards, Cards in the app, default real) and, for virtual, a note that the host's phone holds every hand. The Join page's nearby list says "Cards in the app" on virtual rooms.
- **Settings:** a Cards section with "Four-colour deck" and "Show my cards at once" (both off by default, so a glance from the next seat shows nothing).
- **Motion:** the flip is an X-scale squash through `BrutalTheme.duration`; reduced motion makes it instant.
- **Not built yet:** a deal slide, haptics on deal and flip, tapping a showdown row to see the hand large on the board, and a winner lift on the Table. The raise sheet can cover the dock while it is open.
- **Tests:** `cards_test` (widgets), `cards_gallery_golden_test` (four galleries: both themes, two and four colours), `player_cards_test`, `table_cards_test`, `runout_pacer_test`, goldens for the Player and Table in virtual rooms, and the text-scale sweep (1.0, 2.0, 3.0 on 320x640, 390x844, 1280x800) with a full board and a showdown.

## 9. First run, tours and support (ADR-017)

- **Launch:** `LaunchGate` (splash, terms, intro, name step, Home). The splash is a flush of five cards turning over with a filling bar, tap to skip; the whole picture scales down on a short screen and its caption wraps. Reduced motion shows the cards face up at once.
- **Terms** (`TermsPage`): five sections, an agree switch, ACCEPT disabled until ticked, DECLINE closes the app. The read-only version opens from Settings.
- **Intro** (`IntroPage`): Take the app tour, Learn poker, or Skip. Never shown again once chosen. Skipping the app tour from here opens Learn poker, skipping that goes to the name step; Skip, I know my way goes straight to the name step.
- **Name step** (`NamePage`, 1.4.0): asked once, after the intro (and its tour or lesson are chosen) and before the first Home. One field, SAVE NAME or Skip for now; the name is kept as `defaultName` and prefilled on Host, Join and Play alone, and changeable in Settings. `AppSettings.nameAsked` marks it as answered; an installation that already finished the intro or has a name never sees it (migration in `AppSettings.fromJson`). Copy lives in `Strings.nameStep*`.
- **Tours** (`WalkthroughPage`): progress cells at the top, one illustrated step per page, Back / Next / Done below, a Skip cell always present. Swipe, arrow keys and Escape work.
- **Support** (`SupportPage`): headline, a short text from the developer, three large link rows (Star, Follow, Report a bug; the first is the accent cell) and the repository QR. Reached from Settings (About) and the bottom of the Guide.
- **Guide additions:** a Tours block (Learn poker, Replay the app tour), sections Cards in the app and Play safe, the jump chips Cards and Safety.
- **Seat plates** have one fixed height (`FeltLayout.plateHeightFor`); their content shrinks to fit rather than growing the plate. **Top bar cells** (`TopBarStat`) use a fixed value slot and a label whose text scale is clamped at 1.4, so ROOM, HAND and PHASE share their lines.
- **Tests:** `screens_layout_test` sweeps Home, Settings, Guide, Support and the first-run screens over five sizes (320x568 to 1920x1080), three text sizes and both themes, and checks every pressable cell is at least 44 px; `launch_golden_test`, `walkthrough_golden_test`, `seat_plate_test`, `top_bar_test`.

## 10. Single player (ADR-018, built)

Spec: `docs/superpowers/specs/2026-11-07-single-player-bots-design.md` section 9. As built:
- **Home:** "Play alone" row (caption "Against computer players, no network"), and a "Resume solo game" row above Host when a saved solo game exists. Hidden where hosting is unsupported (web).
- **Setup (`SoloSetupPage`):** Opponents stepper (1 to 9, default 4); Skill as three equal cells (Easy, Normal, Hard) with a one-line caption for the chosen one; Game length cells (Quick 6 / Standard 8 / Long 12 hands per blind level); a caption with the personal record for that table kind; the primary Start cell. It fits without scrolling on every phone (see 4b); no tick marks on the stepper. Tokens only.
- **Table:** the Player screen (`PlayerPage(solo: true)`, a mode of the normal page, not a copy). Top bar adds BLINDS and RISE IN (`BlindStatusCells`, fed by `RoomView.blinds`). The opponent strip shows stacks and frames whose turn it is. Pause / Resume and END GAME replace top up, sit out and leave. Notes under the table ("> HEADS-UP", "> MAYA IS OUT (5TH)") show for two hands. When the human is out a SEE RESULT button appears. Back asks "Save and exit" (keeps the game, Home offers it again) or END GAME.
- **Lifecycle:** `SoloTablePage` pauses the game when the app is backgrounded; coming back keeps it paused until the player presses Resume.
- **Result (`SoloResultPage`):** place ("3RD" with "OF 6", or "YOU WON"), stats (hands played and won, biggest win, best hand), the hand that decided it as mini cards (`ShowdownPanel`), Play again (same table kind and length) and Home. The finished game is added to the local record and the saved game is cleared.
- **Thinking bar and reveals:** the opponent on turn shows a thin bar under their cards (`ThinkingBar`, in `opponent_strip.dart`) that fills with an easing curve and never reaches the end (about 4 s time constant), restarts on every new turn (hand, street, bet), stands still while paused, and is a fixed half bar with reduced motion. The flop's cards turn over one after the other (`FlipIn`, 460 ms each, 260 ms apart), the turn and river alone; a showdown turns the hands over one player after the other, then the five best cards. A run-out deals its streets 1.3 s apart (`RunoutPacer.step`; this also applies to games on the LAN). Goldens pump past the animations so they show the finished state.
- **Tournament feel:** no bot tag anywhere (owner decision: bots look like real players).
- The app tour has a "Play alone" step (8 steps now) and the Guide an "Alone" section with a jump chip.

## 11. Sound (ADR-020, built)

Sound is part of the table's feel: calm, focused, warm, never harsh. All clips are original work made by `tool/sounds/make_sounds.py` (no samples, no downloads; licence note in `app/assets/sounds/README.md`). Settings has one **Sound** switch.

**Palette.** Notes: a soft felt mallet on a tine, tuned to D major pentatonic (D E F# A B), so any two overlapping cues agree. Chips: small clay discs, a short ring plus a low knock. Cards: filtered paper noise (slide, flick, snap). Check: two knuckle taps on felt. One small damped room (RT60 about 0.45 s) under everything so the sounds belong to one place. Rules the analyser enforces (`tool/sounds/analyze.py`): nothing above 6.2 kHz (master low-pass), under 2 percent of the energy above 8 kHz, peaks at or below -3 dBFS, the loudest 200 ms between -26 and -15 dBFS, no click at the start or end, no DC offset, 0.15 to 4 s long. The set is 21 files, 16-bit mono WAV at 22.05 kHz, about 0.9 MB.

**Cues.**
| Cue | When | Sound |
| :--- | :--- | :--- |
| turn | your turn (from the pages, with the vibration) | A, D, F# rising over a low D |
| check | a check | two knuckle taps |
| call | a call or a bet | a few chips (3 clips, played in turn) |
| raise | a raise | a bigger stack (2 clips) |
| allIn | an all-in call, bet or raise | a long chip cascade on a low swell |
| fold | a fold | a card slid away |
| deal | your two cards arrive (virtual cards) | two cards |
| shuffle | a new hand at the table | the deck riffled |
| flop, street | the flop; the turn or river | three cards; one card |
| reveal | hands turned over | two flips and a low note |
| win | you won the pot | D, F#, A, D rising, chips gathered |
| potWon | somebody else won (table and solo) | chips drawn in, one soft note |
| out, gameWon | you are out; you won the game (solo) | three falling notes; a long arpeggio |
| levelUp | blinds went up (solo) | two soft bell notes |
| join, leave | someone sat down or left (table) | A then D; D then A |

**Who hears what.** Phones sit together at one table, so each device plays only its own part (`SoundAudience` in `app/lib/model/sound_cues.dart`): a **solo** game (the view carries blinds) plays everything on the one phone, without the riffle (the cards are dealt to you); the **table** device (host, spectator) plays the table's sounds (everyone's actions, riffle, board, reveal, pot, join, leave) and any personal ones; a **seated guest** plays only its own cards, its own actions, its own wins and losses. A room with real cards has an empty board and no result in the view (found by the real-server E2E), so there the street comes from the phase, the hands are shown when the hand reaches `showdown`, and the pot is paid when the hand enters `nextHandPrep`: a seat whose own stack grew in that very update hears `win`.

**When it plays.** From live server messages only (`SoundTracker`, fed by `SessionNotifier`): a `SNAPSHOT` sets the baseline and is silent, and so is the `HOLE_CARDS` the server resends after it, so coming back to a table replays nothing. A skipped or stale `STATE_UPDATE` is silent. One closing sound per moment (game end beats pot beats reveal). `Sound` drops, never queues, the same cue within 120 ms, goes through a cue's clips in turn, and is silent when the Settings switch is off or the app is not in front. Engine errors are logged and swallowed: a phone with no audio output plays the game in silence.

**Not done.** Per-effect settings, a volume slider, background music, per-seat positioning of sound.
