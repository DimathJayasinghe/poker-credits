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

### Shape, line, space
| Token | Value |
| :--- | :--- |
| `radius` | 0 |
| `hairline` | 1.5 px `line` (all dividers and cell borders) |
| `rule` | 3 px `line` (the single underline or frame that anchors a screen) |
| `shadow` | none |
| `gap` | 4, 8, 16, 24, 32, 48 |
| `tap` | min 48 x 48; 56 high on the player action row |

Pressed state: the cell inverts (`ink` fill with `paper` text, or `accent` darkens). No offset movement, no ripple. Disabled: 45 % opacity with a diagonal hatch.

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
| `BrutalDialog`, `BrutalSheet` | `surface` panels with a hairline top rule; sheets slide in with `base`. |
| `BrutalTextField` | Hairline box on `surface`, label above, error line in accent below. |
| `PaperBackdrop` (new) | Paints `paper` plus grain behind every route (installed once in `MaterialApp.builder`). |
| `EchoTitle` (new) | The hero wordmark: solid Anton text with three outlined copies stepped up-left (the reference 1 effect). Home only. |
| `AppFrame` (new) | Top bar (cells: mark, room or section title, actions) and bottom bar (cells: nav), sharing the hairline grid. |

All widgets are plain Flutter (`DecoratedBox`, `CustomPaint`); no platform widgets.

## 4. Information architecture
**Status: PLAY and SETTINGS are built; GUIDE is specified but not built yet.** Three destinations in a bottom bar on phones and a left rail on wide screens (>= 840 px):

| Destination | Purpose |
| :--- | :--- |
| **PLAY** | Host a game, join with a code, resume the game this device was in. |
| **GUIDE** | How a night works in four steps; hand rankings (a ranked sequence, so numbered); betting words; what to do when the Wi-Fi drops. Static, offline, useful at the table with real cards. |
| **SETTINGS** | Appearance, table, you, data, about (section 6). |

Game screens (Table, Player, Spectator) are full screen routes without the bar, so nothing competes with the game.

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
Top bar cells: room code | hand and street | Pause | Undo. Centre: the `felt` panel with the pot block (`chip` fill, Anton 96) and seat plates on an oval path as hairline cells. The acting seat plate is the only accent fill, with its countdown as a 3 px bar. Ticker row of the last actions under the grid. Host controls sit in a right-hand cell column (landscape) or a bottom sheet (portrait). When the host is on turn, YOUR TURN and the action row appear above the controls.

### Player (portrait, one thumb)
Top bar: room, connection state. Hero cell: stack in Anton 64, bet beside it. Middle: whose turn (quiet `surface` cell) or, when acting, a full-width accent YOUR TURN cell with the countdown. Bottom third: FOLD (outlined), CHECK or CALL n (ink), RAISE (accent); raise opens the slider sheet. Haptics unchanged.

### Spectator
The table view without controls, with a WATCHING tag in the top bar.

### Join / Host
Join: top bar title, then stacked cells: code, name (prefilled from Settings), find-or-type-address as today; one primary action. Host: room code in Anton 120, the QR beside it in a hairline cell, typed addresses in mono, START below.

### Guide
Cells separated by hairlines: a four-step strip, ten ranked hand cards (rank number, name in Anton, one plain line, example in mono such as `A K Q J 10 same suit`), betting words as a two-column grid, "If it drops" with the reconnect story.

### Settings
Rows grouped by a caption cell:
- **APPEARANCE**: Theme (System / Light / Dark), Paper texture (switch).
- **TABLE**: Sound, Vibration, Keep the screen on during a game (switches).
- **YOU**: Default name (used to prefill Join).
- **DATA**: Forget the saved game on this device (confirm dialog).
- **ABOUT**: version, protocol version, licences.
Settings persist in a small JSON file (`path_provider`, behind a platform seam; web keeps them in memory until the web build lands). They load before the first frame so the chosen theme never flashes.

## 6. Accessibility
- Contrast: body 7:1 or better; `muted` 4.5:1 or better; checked by `test/theme/contrast_test.dart` for both themes.
- Semantics label on every actionable cell; a 3 px `accent`-contrast focus outline with offset for keyboard use.
- Text scales to 2.0 without clipping or overflow on Home, Join, Player, Table, Guide and Settings (widget tests fail on any overflow).
- Colour never carries meaning alone (section 2). Reduced motion honoured. Texture can be switched off.

## 7. Implementation rules
- Tokens in one file; no colour literals or magic sizes in widgets (`tool/check_web_safe.sh` greps).
- `ThemeExtension<BrutalTheme>` over a minimal `ThemeData`; Material only as invisible plumbing.
- Strings in `util/strings.dart`; uppercase by presentation.
- Goldens for each component, and for Home, Player and Table, in both themes at phone portrait 390x844, tablet landscape 1280x800 and TV 1920x1080.
- Persisted settings never block start-up: a missing or corrupt file means defaults.
