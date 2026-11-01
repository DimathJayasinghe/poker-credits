# UI Design: Neo-Brutalism

Decision: ADR-013. Applies to Table, Player and Spectator screens on every platform, including the future web build.

## 1. Principles
1. **Raw and honest.** Thick black outlines, flat fills, hard offset shadows. No blur, no gradients, no glass, no rounded corners (radius 0).
2. **Information first.** Chips, pot and turn state are the biggest things on screen. Decoration never competes with numbers.
3. **Loud turn signal.** One element on screen may use signal yellow at a time: the player who must act.
4. **Readable in a dim room, at arm's length, on a TV.** Very high contrast, large type, big hit targets.
5. **Fast.** Motion is short and snappy. State changes appear immediately; animation never delays them.
6. **Same look everywhere.** Components are our own (not Material look-alikes), so iOS, Android, Windows and web match.

## 2. Tokens (implemented once in `app/lib/theme/tokens.dart`)

### Colour
| Token | Light | Dark (Table default) | Use |
| :--- | :--- | :--- | :--- |
| `ink` | `#0A0A0A` | `#F3F0E6` | Text, borders, shadows |
| `paper` | `#F3F0E6` | `#0A0A0A` | Backgrounds |
| `felt` | `#0F6B3A` | `#0F6B3A` | Table surface (flat, no texture) |
| `signal` | `#FFE600` | `#FFE600` | Active turn, primary action highlight |
| `danger` | `#FF3B1D` | `#FF5A3C` | Fold, all-in, errors |
| `info` | `#2B50FF` | `#6B83FF` | Call, links, connection state |
| `chip` | `#FF9F1C` | `#FF9F1C` | Chip amounts, pot |
| `muted` | `#6B6B6B` | `#A8A8A8` | Secondary text (must stay at contrast 4.5:1 or better on its background) |

Rules: text on `signal`, `chip` and `paper` is always `ink`; text on `danger`, `info` and `felt` is white or `paper`. State is never colour alone: add a label, icon or pattern (folded seats are struck through with the word FOLDED; all-in seats carry an ALL-IN tag).

### Type
Fonts are **bundled as assets** (SIL OFL), never fetched at runtime, because LAN games have no internet. Do not use the `google_fonts` runtime download.
| Role | Font | Notes |
| :--- | :--- | :--- |
| Display / numbers | Archivo Black (or Space Grotesk Bold) | Pot, stack, buttons |
| Body / labels | Space Mono | Uppercase labels with +0.5 letter spacing, tabular digits for chips |

Scale (logical px, then scaled by the user's text setting): 12 label, 14 body, 18 lead, 24 title, 40 stack, 72 pot (Table), 96 pot (TV). Chip amounts always use tabular figures so numbers do not jitter while counting.

### Shape, border, shadow
| Token | Value |
| :--- | :--- |
| `radius` | 0 |
| `border` | 3 px solid `ink` (4 px for primary buttons and the pot) |
| `shadow` | solid offset `4,4` in `ink`, no blur (`8,8` for the pot block) |
| `gap` | 8-point grid: 4, 8, 16, 24, 32 |
| `tap` | min 56x56 on Player screen action buttons, min 48x48 elsewhere |

### Motion
| Token | Value |
| :--- | :--- |
| `fast` | 80 ms, linear or step |
| `base` | 150 ms, `Curves.easeOut` |
| `max` | 300 ms (chips to pot) |
Pressing a brutal button moves it by the shadow offset and removes the shadow (a "pressed in" look). No ripple, no bounce, no spring. If the OS requests reduced motion, durations become 0 and the turn highlight stops blinking (solid fill instead).

## 3. Components (`app/lib/widget/brutal/`)
| Widget | Description |
| :--- | :--- |
| `BrutalButton` | Rectangular, 3-4 px border, hard shadow, uppercase label, variants: primary (`signal`), danger, info, neutral. Disabled = hatched fill, no shadow. |
| `BrutalCard` | `paper` block with border and shadow, optional header strip in `ink` with inverted label. |
| `BrutalTag` | Small boxed label: `D`, `SB`, `BB`, `ALL-IN`, `FOLDED`, `AUTO`. |
| `BrutalSlider` | Thick track and a square thumb; tick marks for Min, 1/2, 3/4, Pot, All-in; the value in a large box above. |
| `BrutalKeypad` | Plain numeric grid for exact bets. |
| `BrutalBanner` | Full-width strip for Reconnecting, Paused, errors. Striped `signal`/`ink` background for warnings. |
| `BrutalDialog` / `BrutalSheet` | Bordered panels with hard shadow; sheets slide in with `base` motion. |
| `BrutalTextField` | Bordered box, label above, error text in a `danger` strip below. |

All widgets are pure Flutter (`CustomPaint`/`DecoratedBox`), no platform widgets, so they behave the same on web.

## 4. Screens

### Table Display (landscape, dark by default)
```
+----------------------------------------------------------+
| ROOM KQ7M          HAND 7   FLOP       [PAUSE][UNDO]     |  top bar: ink strip, inverted text
+----------------------------------------------------------+
|        [ALICE 940]   [BOB 1200]   [CARA 310 ALL-IN]      |
|   [DAN 75]        +----------------------+     [EVE 500] |
|                   |   POT  210           |                |  felt block, 4px border, 8px shadow
|                   |   SIDE 60            |                |
|   [FAY 0 FOLDED]  +----------------------+     [GUS 880] |
|        [D] [SB]  [BB]       > ACTING: BOB 00:21          |
+----------------------------------------------------------+
| ticker: BOB RAISES TO 60 | CARA CALLS 60 | ...           |
+----------------------------------------------------------+
```
Seats are rectangular name plates placed on an oval path (oval remains the layout, shapes are boxes). The acting seat is the only `signal` fill; its countdown is a thick bar under the plate. The pot is the largest block.

### Player Controller (portrait, one thumb)
- Top: your stack and bet in large type; connection chip.
- Middle: "YOUR TURN" full-width `signal` block when acting, with haptics; otherwise a calm `paper` block saying whose turn it is.
- Bottom third (thumb zone): `FOLD` (danger), `CHECK`/`CALL 20` (info), `RAISE` (signal) as three stacked or side-by-side blocks at 56+ px; Raise opens the slider sheet.

### Spectator
Table view without admin controls and with a `WATCHING` tag.

### Join / Host / Settings
Plain stacked cards, uppercase section headers, one primary action per screen. The Host screen shows the QR in a bordered block next to the typed IP and room code in large mono type.

## 5. Accessibility
- Contrast: body text at 7:1 or better on its background; `muted` at 4.5:1 or better.
- Semantics labels on every actionable element; focus ring is a 3 px `info` outline with a 3 px offset (keyboard use on desktop and web).
- Text scales with the OS setting up to 1.6x without clipping (layouts use flexible boxes).
- Colour never carries meaning alone (see section 2).
- Reduced motion honoured.

## 6. Implementation rules
- Tokens live in one file; no hex literals or magic numbers in widgets (lint via a simple grep check in CI).
- Theme is a custom `ThemeExtension<BrutalTheme>` over a minimal `ThemeData`; Material widgets are used only where invisible (for example `Scaffold`, `Navigator`, text input plumbing).
- Strings go through `util/strings.dart` and are uppercase by presentation (`TextStyle`/`toUpperCase` in the widget), not by data.
- Golden tests for each component and for the Table and Player screens at: phone portrait 390x844, tablet landscape 1280x800, TV 1920x1080.
