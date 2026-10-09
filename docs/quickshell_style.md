# HakuSpace Quickshell — Style Guide (Irunu Style)

> Accompanying document to `HAKUSPACE_QUICKSHELL_PLAN.md` section 7 (Theme pipeline) and M1 (`Theme.qml`).
> Goal: A single set of **tokens**, designed according to the **Irunu Style**, where QML strictly reads tokens — **hard-coding colors is forbidden**.

---

## 1. General Principles (Irunu Style)

1. **Two Primary Colors:** Solid Black (for all backgrounds) and Accent Color (dynamically changed, never hard-coded).
2. **SOLID BLACK ONLY:** The top panel, modules, popups, and all Hikai components MUST have a solid black background (`#000000`). No transparency or blur effects are allowed.
3. **Rounded Corners & Shadows:** Corner radius is fixed at `16px`, no borders (`borderWidth = 0`), with a subtle box-shadow. Rounded screen does NOT have a thick border/spacer for the top edge.
4. **Hierarchy:** The main background is solid black. Most modules will have a transparent background and accent text. Specific grouped modules (like `[backlight, pulseaudio, battery]`) will have an accent background. On hover, transparent modules can invert (accent background, black text).

### TopBar Layout Structure
- **Left:** Logo (Circular, Accent background, Black text), Workspaces (pill thickness 20px, active width 50px), Cava (no icon)
- **Center:** Title (placeholder)
- **Right:** Tray, `[Backlight, PulseAudio, Battery]` (Accent background group pill), Power Profile (icon only), Recorder, Clock, Notify
*(Monitor module and Drawer are removed)*

### Custom Typography Rules
For complex data modules, we apply space-saving typography rules to fit within the TopBar limits elegantly:
- **Stacked & Zic-Zac (Clock Module):** Values (Time and Date) are stacked into two lines. The top line is shifted left (`anchors.left`), and the bottom line is shifted right (`anchors.right`). Both use smaller fonts (`fontSize - 2` and `fontSize - 4`) with negative spacing (`-2px`) to pull them tight together.
- **Icon-Only Minimalism (System Group):** The `[Backlight, Volume, Battery]` group abandons text entirely. It relies on slightly enlarged (`fontSize + 2`) icons centered inside a unified accent background pill. Detailed percentages and states are moved to custom hover tooltips (`HTooltip`), making the TopBar exceptionally clean.

---

## 2. Token Contract (`quickshell.json` → `Theme.qml`)

`gen_style.sh` → `render_quickshell` outputs the file `~/.local/state/hakuspace/theme/quickshell.json`:

```json
{
  "preset": "irunu",
  "accent": "#c89a6a",
  "fontFamily": "JetBrainsMono Nerd Font",
  "fontSize": 14,
  "colors": {
    "bg": "#000000",
    "surface": "#000000",
    "surfaceHi": "#c89a6a",
    "border": "transparent",
    "fg": "#c89a6a",
    "fgDim": "#ccc89a6a",
    "fgMuted": "#80ffffff",
    "onAccent": "#000000"
  },
  "shape":  { "radius": 16, "radiusSm": 8, "borderWidth": 0, "gap": 4, "pad": 12 },
  "effects": { "shadow": true, "blur": false }
}
```

| Token | Used for |
|---|---|
| `bg` | Panel/bar/popup backgrounds (ALWAYS SOLID BLACK) |
| `surface` | Cards, input fields, list items (ALWAYS SOLID BLACK) |
| `surfaceHi` | Hovered / selected items (becomes the accent color) |
| `border` | Transparent (hidden borders) |
| `fg` / `fgDim` | Primary text and icons (uses accent color) |
| `accent` | Main aesthetic color (dynamic) |
| `onAccent` | Black text placed on an accent background |

---

## 3. Derivative Rules in `Theme.qml`

- When reading `quickshell.json`, `Theme.qml` maps these values directly.
- Hover state: Background switches to `surfaceHi` (accent) and text switches to `onAccent` (black).
