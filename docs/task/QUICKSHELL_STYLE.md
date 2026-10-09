# HakuSpace Quickshell — Style Guide (Irunu Style)

> Synced with the P0 working tree based on `68c3ba59` (2026-10-07). **The code is the source of truth.**
> Companion to `HAKUSPACE_QUICKSHELL_PLAN.md` and `FLARE_LIB_SPEC.md`.
> Rule: QML reads **tokens** (`Theme.*`, `HAnimation.*`); hard-coding colours/durations is not allowed (the known exceptions are listed in section 6 and are tracked, not endorsed).

---

## 1. General principles (Irunu Style)

1. **Two primary colours:** solid black `#000000` for shell backgrounds and the dynamic **accent** for hover fills, text, icons, borders and state indicators. The Logo, Settings group and MPRIS icon circle use accent fill at rest.
2. **Background surfaces:** `Theme.bg`, `surface`, `scrim` and `inkBg` are fixed to opaque `#000000`. `Theme.surfaceHi` follows `Theme.accent` for hover and selection. `Theme.barColor` still follows the opaque-state binding, but both branches are black. The Picker scrim covers the screen in black. Transparent window regions remain transparent so the bar, flare and rounded corners keep their intended shapes.
3. **Shape:** corner radius `16 px` (`Theme.radius`), small radius `Theme.radiusSm = radius − 4` (12 px once the JSON is applied), no borders (`borderWidth = 0`). **No shadows are implemented** (the earlier "subtle box-shadow" idea is not in the code).
4. **Hierarchy:** ordinary module and card fills are black; hovered or selected controls use an accent fill with black text/icons. The Logo and Settings group stay accent-filled with black icons even on hover. Tray and WindowTitle instead use dark grey `Theme.hoverMuted` on hover; WindowTitle text/icon becomes accent. Urgent modules use red text when idle. The MPRIS icon has an accent circle with a black glyph; workspace dots and the moving indicator are status graphics.

### TopBar layout (as built)
- **Left:** Logo (accent background, black glyph; hover adds 2 px to icon font size and expands the pill by `Theme.pad`), Workspaces (pill/worm indicator: dot 20 px, gap 6 px, active width 50 px; hidden on Labwc), WindowTitle (icon + class + title on Hyprland and Niri).
- **Center:** Dynamic Center shows media or recording state, with conditional Cava and level OSD.
- **Right:** Tray, Settings group (accent pill with black backlight / volume / battery icons) followed by the Power-profile module (icon only), Recorder, Clock, Notification (stub).
- Not mounted (files exist): Monitor drawer and the obsolete Music placeholder. Cava uses the center cluster.

### Typography rules for dense modules
- **Clock (stacked, zig-zag):** time `HH:mm` bold; next to it a column with the weekday above (`fontSize − 2`, shifted left) and the date `dd/MM/yyyy` below (`fontSize − 4`, shifted right), line spacing `−2 px`.
- **Settings group (icon-only):** black icons at `fontSize + 2` centred in one accent pill; its background and icon colour do not change on hover. Values live in the hover tooltips.
- All text uses `Theme.fontFamily` (a Nerd Font) and `Font.Bold` for module labels.

---

## 2. Token contract (`quickshell.json` → `Theme.qml`)

`gen_style.sh` → `render_quickshell` writes `~/.local/state/hakuspace/theme/quickshell.json` atomically (`jq` → `.tmp` → `mv`). The file is **flat**:

```json
{
  "preset": "irunu",
  "accent": "#c89a6a",
  "font": "JetBrainsMono Nerd Font",
  "fontSize": 14,
  "bg": "#000000",
  "surface": "#000000",
  "surfaceHi": "#c89a6a",
  "border": "transparent",
  "fg": "#c89a6a",
  "fgDim": "<ACCENT_DIM>",
  "fgMuted": "rgba(255, 255, 255, 0.5)",
  "onAccent": "#000000",
  "radius": 16,
  "borderWidth": 0,
  "gap": 4,
  "pad": 12
}
```
(`accent`, `font`, `fontSize`, `fgDim` come from `state.env`/the accent pipeline; the rest are constants of the preset.) `preset` is informational. The generated `bg` and `surface` keys document the black-background policy. `Theme.qml` keeps them read-only and ignores incoming values so an older generated file cannot restore translucent fills. `surfaceHi` is read-only and bound to `accent`; its JSON value is informational.

`Theme.qml` loads the file with `FileView` (`watchChanges`, `onFileChanged: reload()`), parses it in `apply()` inside `try/catch` (invalid or empty content keeps the previous values), and converts CSS `rgba(r, g, b, a)` strings to `#AARRGGBB` with `parseColor()`.

### Mapping JSON → `Theme`
| JSON key | `Theme` property | Notes |
|---|---|---|
| `bg` | `bg` | fixed opaque `#000000`; JSON value ignored |
| `fg` | `fg` | equals the accent |
| `fgDim` | `fgDim` | default `#aaaaaa` |
| `fgMuted` | `fgMuted` | `rgba(255,255,255,0.5)` → `#80ffffff` |
| `border` | `border` | `transparent` |
| `surface` | `surface` | fixed opaque `#000000`; JSON value ignored |
| `surfaceHi` | `surfaceHi` | bound to `accent` for hover/selection; JSON value ignored |
| `accent` | `accent` | |
| `onAccent` | `onAccentColor` | fixed `#000000` for text/icons on accent fills; JSON value ignored |
| `radius` | `radius`, and `radiusSm = max(0, radius − 4)` | |
| `borderWidth`, `gap`, `pad` | same names | |
| `font` | `font` and `fontFamily` | |
| `fontSize` | `fontSize` | |

### `Theme`-only tokens (not in the JSON)
| Token | Default | Use |
|---|---|---|
| `scrim` | `#000000` | opaque overlay behind the Picker card |
| `inkBg` | `#000000` | background used by `barColor` in opaque mode |
| `onAccentColor` | `#000000` | black text/icons on accent fills |
| `hoverMuted` | `#2b2b2b` | dark grey hover fill for Tray and WindowTitle |
| `workspaceDot` | `#424242` | inactive workspace status dots |
| `barColor` | `AppState.opaqueThemeState ? inkBg : bg` | both states render `#000000`; bar and flare/tooltip body |
| `tipRadius` | `20` | corner radius of the tooltip/flare body and the ears |
| `tipHugRadius` | `24` | radius of the edge-hugging feet; the flare snap distance is `2 × tipHugRadius` |

### Token use
| Token | Used for |
|---|---|
| `barColor` / `bg` | bar, tooltip and flare body; always solid black |
| `surface` | module and card fills, including Settings and Picker |
| `surfaceHi` | accent fill on hovered/selected controls |
| `hoverMuted` | dark grey hover fill for Tray and WindowTitle |
| `fg` / `fgDim` / `fgMuted` | primary, dim and muted text/icons (including the WindowTitle class name) |
| `accent` | highlighted text/icons and borders; tooltip text; workspace indicator |
| `onAccentColor` | black text/icons on accent fills, including hover, Settings and MPRIS |
| `border`, `borderWidth` | transparent/0 (hidden borders) |

### Derived rules (as coded in `TopModule`)
- Idle `TopModule` controls use `surface` (`#000000`) as their fill. Hovered controls use `surfaceHi` (accent) with `onAccentColor` (black) text/icons. The Logo overrides both states with accent fill and a black glyph; on hover it grows its icon font size by 2 px and its width by `Theme.pad`. Tray and WindowTitle use `hoverMuted` (`#2b2b2b`); WindowTitle foreground becomes accent, while tray icon artwork keeps its own colours. The Settings group is a separate accent pill and keeps its accent background and black icons on hover.
- `urgent`: black background with red text when idle; accent background with black text on hover. `muted`: opacity 0.5. `blink`: opacity pulses 1.0 ↔ 0.5.
- Hover also widens ordinary modules by 20 px (`implicitWidth` has an animated `Behavior`). Logo expands by `Theme.pad`; Tray items keep a fixed width.

---

## 3. Animation tokens (`HAnimation`)

| Token | Value | Use |
|---|---|---|
| `fast` / `normal` / `slow` | 100 / 220 / 400 ms | hover, colour and opacity changes; module width; flare height |
| `spatial` | 250 ms | position/size of the workspace indicator and its dots |
| `effects` | 150 ms | colours/opacity inside workspaces and crossfade of flare content |
| `trailFactor` | 1.5 | trailing edge duration multiplier (workspace worm, flare morph) |
| `moduleCurve` | `[0.16, 1.0, 0.3, 1.0]` | module width/colour animations, flare height |
| `tooltipCurve` | `[0.4, 0.0, 0.2, 1.0]` | defined, currently unused by the flare |
| `shellCurve` | `[0.16, 1.0, 0.3, 1.0]` | defined for drawers/layers |
| `spatialCurve` | `[0.38, 1.21, 0.22, 1.0]` | workspace worm and flare edges (control point y = 1.21 for a slight overshoot) |
| `effectsCurve` | `[0.34, 0.8, 0.34, 1.0]` | workspace colours/opacity |

> **VERIFY:** the curves are written with 4 numbers; Qt's `easing.bezierCurve` takes control points plus the end point (groups of 6, ending `…, 1, 1`). Confirm they are really applied.

---

## 4. Component style notes

- **Workspaces:** dots `20 px`, gap `6 px`, active width `50 px`; ordinary inactive dots use `workspaceDot` (`#424242`), with lower opacity when empty. The single gliding indicator uses `accent`. Geometry is computed (not read from layout); edges animate separately (leading edge `spatial`, trailing `spatial × trailFactor`).
- **Tooltip / flare:** body `Theme.barColor`, text `Theme.accent` centred and wrapped (max width 400 px), body radius `tipRadius`, concave ears (top, attach to the bar) and feet (bottom, hug the Rounded Screen edge) of radius `tipRadius`/`tipHugRadius`; see `FLARE_LIB_SPEC.md`.
- **MPRIS:** the small round background behind the media icon uses `Theme.accent`; its glyph uses `Theme.onAccentColor` (black). The rest of the Center module is black when idle and accent on hover, with black caption text.
- **Rounded Screen:** solid black corners of radius `border_radius` (default 20) plus a black stroke of `border_thickness` (default 4) read from `~/hakucfg/config/rounded-screen.conf`; three transparent spacer windows reserve the thickness; layer Top when dynamic, Overlay otherwise.
- **Picker:** full-screen opaque black scrim, centred black card (`Theme.surface`) with radius `Theme.radius`, accent prompt, and accent selection/hover fill with black row text.
- **Tray icons:** `IconImage` of size `fontSize + 4` on a square black module; hover uses dark grey `Theme.hoverMuted`. Icon artwork comes from the tray application and retains its own colours; tooltip text remains accent.

---

## 5. Rules for new components
- Take every colour from `Theme` and every duration/curve from `HAnimation`.
- Panels that attach to the bar or screen edge must use `FlareHost` (no hand-written flare maths).
- Backgrounds use `Theme.barColor` (bar/flare), `Theme.surface` (ordinary idle modules/cards) or `Theme.scrim` (Picker overlay), all opaque `#000000`. Hover and selection use `Theme.surfaceHi` (accent), except Tray and WindowTitle hover (`Theme.hoverMuted`, dark grey). Logo and Settings keep accent fill in both states.
- Keep transparent window regions and shape cutouts transparent; they are outside visible background surfaces.
- Use `Theme.onAccentColor` (black) for text/icons on accent fills, including hovered modules, Picker rows and the MPRIS icon circle.
- Keep icon-only/typography rules above for dense modules; put detailed values in tooltips.

---

## 6. Known exceptions to "no hard-coded colours"
| Where | Value | Why |
|---|---|---|
| `TopModule.qml` | `#ff3333` (urgent text) | no urgent-text token yet |
| `LevelOsdOverlay.qml` | `#000000` (OSD body) | matches fixed background policy |
| `RoundedScreen.qml` | `#000000` fill and stroke | frame is always black |

Suggested token if the urgent colour is centralized later: `Theme.urgentText`.

---

## 7. Observations
- Opaque mode keeps the bar at `#000000` because `bg` and `inkBg` are both black.
- Theme defaults for backgrounds match the generated JSON even before the file is read. Size defaults can still differ (`pad 10` before JSON, `pad 12` after it).
- The previous version of this guide described a nested JSON schema (`colors`, `shape`, `effects`) and shadows; neither exists in the code.
