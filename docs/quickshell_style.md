# HakuSpace Quickshell — Style Guide (Ink)

> Accompanying document to `HAKUSPACE_QUICKSHELL_PLAN.md` section 7 (Theme pipeline) and M1 (`Theme.qml`).
> Goal: A single set of **tokens**, designed according to the **Ink** style, where QML strictly reads tokens — **hard-coding colors is forbidden**.

---

## 1. General Principles (Ink Style)

1. **Two Primary Colors:** Black (for background) and Accent Color (dynamically changed, never hard-coded).
2. **Rounded Corners & Shadows:** Corner radius ranges from `8px` to `12px`, no borders (`borderWidth = 0`), with a subtle box-shadow.
3. **Hierarchy:** The main background is transparent black; text and icons use the accent color directly. On hover, colors can invert (accent background, black text).

---

## 2. Token Contract (`quickshell.json` → `Theme.qml`)

`gen_style.sh` → `render_quickshell` outputs the file `~/.local/state/hakuspace/theme/quickshell.json`:

```json
{
  "preset": "ink",
  "accent": "#c89a6a",
  "fontFamily": "JetBrainsMono Nerd Font",
  "fontSize": 14,
  "colors": {
    "bg": "#b3000000",
    "surface": "#99202020",
    "surfaceHi": "#c89a6a",
    "border": "transparent",
    "fg": "#c89a6a",
    "fgDim": "#ccc89a6a",
    "fgMuted": "#80ffffff",
    "onAccent": "#000000"
  },
  "shape":  { "radius": 12, "radiusSm": 8, "borderWidth": 0, "gap": 4, "pad": 10 },
  "effects": { "shadow": true, "blur": true }
}
```

| Token | Used for |
|---|---|
| `bg` | Panel/bar/popup backgrounds |
| `surface` | Cards, input fields, list items |
| `surfaceHi` | Hovered / selected items (becomes the accent color) |
| `border` | Transparent (hidden borders) |
| `fg` / `fgDim` | Primary text and icons (uses accent color) |
| `accent` | Main aesthetic color (dynamic) |
| `onAccent` | Black text placed on an accent background |

---

## 3. Derivative Rules in `Theme.qml`

- When reading `quickshell.json`, `Theme.qml` maps these values directly.
- `opaque_theme_state` (if enabled): QML automatically alters `bg` to solid black, removing the blur effect.
- Hover state: Background switches to `surfaceHi` (accent) and text switches to `onAccent` (black).
