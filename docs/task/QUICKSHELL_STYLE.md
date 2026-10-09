# HakuSpace Quickshell — Style Guide (Irunu Style)

> Synced with the code at commit `bee8b633` (2026-10-05) plus the working tree. **The code is the source of truth.**
> Companion to `HAKUSPACE_QUICKSHELL_PLAN.md` (D7 Theme via JSON) and `M2_PLAN.md`.
> Rule: QML reads **tokens** (`Theme.*`, `HAnimation.*`); hard-coding colours/durations is not allowed (the known exceptions are listed in section 6 and are tracked, not endorsed).

---

## 1. General principles (Irunu Style)

1. **Two primary colours:** solid black for backgrounds and the dynamic **accent** (never hard-coded).
2. **Solid black surfaces:** the top bar, modules, tooltips, picker card and Rounded Screen frame are solid black. No transparency/blur is applied (the Picker uses a dimming scrim behind its card).
3. **Shape:** corner radius `16 px` (`Theme.radius`), small radius `Theme.radiusSm = radius − 4` (12 px once the JSON is applied), no borders (`borderWidth = 0`). **No shadows are implemented** (the earlier "subtle box-shadow" idea is not in the code).
4. **Hierarchy:** the bar is solid black; most modules have a transparent background with accent/foreground text; grouped modules (the Settings group) sit on an accent pill; on hover transparent modules fill with the highlight colour and invert text, accent modules invert to black.

### TopBar layout (as built)
- **Left:** Logo (circular, accent background, black glyph), Workspaces (pill/worm indicator: dot 20 px, gap 8 px, active width 50 px), WindowTitle (icon + class + title; Hyprland only).
- **Center:** empty.
- **Right:** Tray, Settings group (accent pill with icon-only backlight / volume / battery) followed by the Power-profile module (icon only), Recorder, Clock, Notification (stub).
- Not mounted (files exist): Monitor drawer, Cava, Music.

### Typography rules for dense modules
- **Clock (stacked, zig-zag):** time `HH:mm` bold; next to it a column with the weekday above (`fontSize − 2`, shifted left) and the date `dd/MM/yyyy` below (`fontSize − 4`, shifted right), line spacing `−2 px`.
- **Settings group (icon-only):** icons at `fontSize + 2` centred in one accent pill; values live in the hover tooltips.
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
(`accent`, `font`, `fontSize`, `fgDim` come from `state.env`/the accent pipeline; the rest are constants of the preset.) `preset` is informational: `Theme.qml` ignores it.

`Theme.qml` loads the file with `FileView` (`watchChanges`, `onFileChanged: reload()`), parses it in `apply()` inside `try/catch` (invalid or empty content keeps the previous values), and converts CSS `rgba(r, g, b, a)` strings to `#AARRGGBB` with `parseColor()`.

### Mapping JSON → `Theme`
| JSON key | `Theme` property | Notes |
|---|---|---|
| `bg` | `bg` | default `#b3000000` until the JSON is read |
| `fg` | `fg` | equals the accent |
| `fgDim` | `fgDim` | default `#aaaaaa` |
| `fgMuted` | `fgMuted` | `rgba(255,255,255,0.5)` → `#80ffffff` |
| `border` | `border` | `transparent` |
| `surface` | `surface` | `#000000` |
| `surfaceHi` | `surfaceHi` | equals the accent (hover/selection fill) |
| `accent` | `accent` | |
| `onAccent` | `onAccentColor` | text on accent backgrounds |
| `radius` | `radius`, and `radiusSm = max(0, radius − 4)` | |
| `borderWidth`, `gap`, `pad` | same names | |
| `font` | `font` and `fontFamily` | |
| `fontSize` | `fontSize` | |

### `Theme`-only tokens (not in the JSON)
| Token | Default | Use |
|---|---|---|
| `scrim` | `#80000000` | dimming layer behind the Picker |
| `inkBg` | `#111111` | background used by `barColor` in opaque mode |
| `barColor` | `AppState.opaqueThemeState ? inkBg : bg` | **single source** for the bar background and the flare/tooltip body |
| `tipRadius` | `20` | corner radius of the tooltip/flare body and the ears |
| `tipHugRadius` | `24` | radius of the edge-hugging feet; the flare snap distance is `2 × tipHugRadius` |

### Token use
| Token | Used for |
|---|---|
| `barColor` / `bg` | bar, tooltip and flare body (solid black unless the opaque preset changes it to `inkBg`) |
| `surface` | Picker card, input fields, list items |
| `surfaceHi` | hovered/selected fill; selected Picker row |
| `fg` / `fgDim` / `fgMuted` | primary text and icons (accent); dim and muted text (class name in WindowTitle, empty workspace dots) |
| `accent` | highlights; accent-pill modules; tooltip text colour; workspace indicator |
| `onAccentColor` | black text/icons on accent backgrounds |
| `border`, `borderWidth` | transparent/0 (hidden borders) |

### Derived rules (as coded in `TopModule`)
- Accent module: background `accent`; hovered → black background with `surfaceHi` text/icon (`surfaceHi` is the accent).
- Transparent module: background `transparent`; hovered → `surfaceHi` background with `onAccentColor` text/icon.
- `urgent`: red background with white text. `muted`: opacity 0.5. `blink`: opacity pulses 1.0 ↔ 0.5.
- Hover also widens modules by 20 px (`implicitWidth` has an animated `Behavior`), except fixed-width ones (Logo, Tray items).

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

- **Workspaces:** dots `20 px`, gap `8 px`, active width `50 px`; empty dots use `fgMuted` at opacity 0.4, occupied dots `accent` at 0.6; the single gliding indicator uses `accent`. Geometry is computed (not read from layout); edges animate separately (leading edge `spatial`, trailing `spatial × trailFactor`).
- **Tooltip / flare:** body `Theme.barColor`, text `Theme.accent` centred and wrapped (max width 400 px), body radius `tipRadius`, concave ears (top, attach to the bar) and feet (bottom, hug the Rounded Screen edge) of radius `tipRadius`/`tipHugRadius`; see `FLARE_LIB_SPEC.md`.
- **Rounded Screen:** solid black corners of radius `border_radius` (default 20) plus a black stroke of `border_thickness` (default 4) read from `~/hakucfg/config/rounded-screen.conf`; three transparent spacer windows reserve the thickness; layer Top when dynamic, Overlay otherwise.
- **Picker:** full-screen dim (`scrim`), centred card `Theme.surface` with radius `Theme.radius`, accent prompt, `fg` text, selected row `surfaceHi`.
- **Tray icons:** `IconImage` of size `fontSize + 4` on a square transparent module (hover: translucent white).

---

## 5. Rules for new components
- Take every colour from `Theme` and every duration/curve from `HAnimation`.
- Panels that attach to the bar or screen edge must use `FlareHost` (no hand-written flare maths).
- Backgrounds use `Theme.barColor` (bar/flare) or `Theme.surface` (cards).
- Keep icon-only/typography rules above for dense modules; put detailed values in tooltips.

---

## 6. Known exceptions to "no hard-coded colours" (tracked, not changed)
| Where | Value | Why |
|---|---|---|
| `TopModule.qml` | `#ff3333` (urgent bg), `#ffffff` (urgent text), `#000000` (accent hover bg) | no `Theme` token yet (`urgent`, `onAccentHover`) |
| `TrayGroup.qml`, `WindowTitle.qml` | `Qt.rgba(1,1,1,0.1)` (hover) | no hover token for transparent surfaces |
| `MonitorGroup.qml` (not mounted) | `"rgba(32,32,32,0.6)"` | local cell background |
| `RoundedScreen.qml` | `#000000` fill and stroke | frame is always black |
| `Picker.qml` | `"#80000000"` fallback | only used if `Theme.scrim` is empty |

Suggested tokens when these are cleaned up: `Theme.urgent`, `Theme.onUrgent`, `Theme.hoverFill`, `Theme.cell`.

---

## 7. Observations
- With the JSON `bg` already `#000000`, **opaque mode switches the bar to `inkBg` (`#111111`)**, i.e. slightly lighter, not "more opaque". Confirm this is intended.
- The Theme defaults (`bg #b3000000`, `surface #99202020`, `pad 10`) differ from the Irunu JSON (`#000000`, `#000000`, `pad 12`); they only show before the file is first read or when it is missing/invalid.
- The previous version of this guide described a nested JSON schema (`colors`, `shape`, `effects`) and shadows; neither exists in the code.