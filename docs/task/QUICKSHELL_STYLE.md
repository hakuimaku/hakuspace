# HakuSpace Quickshell — Style Guide (Irunu Style)

> Canonical full style guide for the stable P2 baseline plus the mockup-locked P3 direction (2026-10-08).
> Companion to `HAKUSPACE_QUICKSHELL_PLAN.md` and `FLARE_LIB_SPEC.md`.
> QML reads **tokens** (`Theme.*`, `HAnimation.*`); hard-coded colours/durations remain exceptions, not a design pattern.
>
> P3 visual authority order:
>
> 1. latest seven Paint mockups (`base.png`, `navigation.png`, `dashboard.png`, `sidebar.png`, `setting.png`, `hakumenu.png`, `wallpaper-change.png`);
> 2. this style guide;
> 3. `HAKUSPACE_QUICKSHELL_PLAN.md`;
> 4. older Paint experiments;
> 5. AI-generated concept images.
>
> The old TopBar-center collar/notch/shoulder mockup and the old Wallpaper dual-front/wide-Flare concept are superseded.

## 1. General principles (Irunu Style)

1. **Two primary colours:** solid black `#000000` for shell surfaces and the dynamic **accent** for active/selected/hover states, text, icons and state indicators where defined.
2. **Background surfaces:** `Theme.bg`, `surface`, `scrim` and `inkBg` are fixed opaque black in the current preset. Transparent regions stay transparent when they are real shape cutouts or empty window space.
3. **Shape:** default radius comes from `Theme.radius`; use a small shared radius family rather than unrelated radii per card. Borders are normally hidden (`borderWidth = 0`). Paint outlines describe geometry/grouping, **not literal border requirements**.
4. **Hierarchy:** ordinary cards/modules are black. Accent fill + black foreground is the primary selected/active treatment. Tray/WindowTitle keep their existing muted-hover exception. Do not turn every shell surface into the same generic rounded rectangle.
5. **Geometry ownership:** RoundedScreen/frame geometry is shared per output. TopBar-origin surfaces derive attachment coordinates from that shared frame instead of duplicating `topBarHeight + offset` calculations.
6. **Surface identity:** shared tokens and list primitives do not imply one universal panel silhouette. Navigation, Dashboard, Sidebar, Settings, HakuMenu and Wallpaper keep distinct mockup-approved forms.

### 1.1 TopBar baseline

- **Left:** Logo → Workspaces → WindowTitle.
- **Center:** Dynamic Center / MPRIS / Cava / level state according to the stable baseline.
- **Right:** Tray → Settings group → Recorder → Clock → Notification.
- The abandoned P3 center-collar/notch/shoulder redesign is cancelled. Do not restore it.
- P3 may fix physical centering, input ownership and HakuMenu triggering without changing the fallback center silhouette.

### 1.2 Typography rules for dense modules

- **Clock:** keep the existing compact stacked time / weekday / date presentation unless a later approved mockup replaces it.
- **Settings group:** icon-dense, values belong in tooltips/secondary surfaces.
- Use `Theme.fontFamily`; existing module labels use the current weight rules unless a mockup explicitly calls for a different hierarchy.

### 1.3 RoundedScreen — shell chassis

Reference: `base.png`.

RoundedScreen is the persistent visual chassis:

- follows the physical screen perimeter;
- left/right/bottom visually reach the output edges;
- corners are continuous;
- top frame remains visible with TopBar ON;
- top rail may be visually thicker/stronger than side/bottom;
- TopBar and RoundedScreen are separate layers; never hide the frame merely to fake TopBar shape continuity.

Shared per-output geometry should expose equivalent values:

```text
frameTopY
frameTopThickness
frameInnerTopY
frameInnerLeftX
frameInnerRightX
frameInnerBottomY
cornerRadius
roundedEnabled
```

### 1.4 Navigation — radial Logo controller

Reference: `navigation.png`.

Navigation is **not HakuMenu**.

Visible regions:

```text
Dashboard
Sidebar
Settings
```

Style contract:

- circular/radial controller at the Logo origin;
- three visible regions read as one controller;
- do not substitute a rectangular menu;
- interaction hitboxes may be simpler than the visible wedge geometry for reliability;
- keyboard/focus access remains available.

### 1.5 Dashboard

Reference: `dashboard.png`.

> [!NOTE] 2026-10-10 Dashboard layout & style override:
> - final envelope remains 45% output width × 45% output height;
> - outer background uses the shared HakuSpace Flare language (top-edge attached Flare surface);
> - shell-level child inset is exactly 10 logical px;
> - Avatar target is inset 10 px (final x=10, y=10);
> - Navigation ↔ Dashboard uses one reversible morph driven by `dashboardMorphProgress` instead of instant visibility swap;
> - lower-left region is a dynamic widget host (`DashboardWidgetHost`);
> - Calendar is the first/default widget, not a shell-level fixed card.

Dashboard contains the 45×45 upper-left attached cluster:

- circular avatar at the Navigation origin while Dashboard is active;
- Clock card;
- MPRIS card with controls + thumbnail;
- Dynamic Widget Slot (`DashboardWidgetHost`, first widget: Calendar);
- monitor card with `ROM`, `RAM`, `CPU`, `GPU`.

The area outside the 45×45 shell remains transparent and pass-through.

Avatar interaction contract:
- Left-click avatar: leave Dashboard and return to radial Navigation (Navigation remains open on the same monitor).
- Right-click avatar: open avatar file chooser without leaving Dashboard.
- Chooser cancel: Dashboard remains open, avatar unchanged.
- Chooser accepted: persist selected image into managed storage and update avatar in-place without reopening.
- Escape while Dashboard is active: return to radial Navigation.

Avatar data belongs under:

```text
~/.local/share/hakuspace/user/
```

Persisted filename scheme:
- Manifest: `~/.local/share/hakuspace/user/avatar.path` storing strictly the basename (e.g. `avatar.png`, `avatar.jpg`, `avatar.jpeg`, `avatar.webp`).
- Active image: `~/.local/share/hakuspace/user/<basename>`.
Only one managed avatar image is active at any time. Persistence backend recognizes PNG, JPEG/JPG and WebP. A selected image is persisted only if the running Qt image stack can decode it.

Card rules:

- one radius family;
- consistent gaps;
- stable bounds when dynamic text/data changes;
- thumbnail has a bounded slot;
- calendar month changes do not resize the card;
- monitor updates do not reflow card geometry.

### 1.6 Sidebar

Reference: `sidebar.png`.

Sidebar is a left-edge expansion from the Navigation Sidebar region.

- opens immediately on Sidebar-region hover;
- pointer handoff from Navigation to Sidebar must not flicker-collapse;
- use an invisible interaction bridge/union if needed;
- visible body is an elongated rounded lobe, not a generic drawer;
- option controls are circles;
- plus action is circular;
- the mockup defines shape, not the semantics of each dot; do not invent unknown actions.

### 1.7 Settings

Reference: `setting.png`.

Settings is intentionally a **P3 stub**:

- centered inner rounded surface;
- consistent radii;
- small `Setting` header/control;
- stub content such as `still working rn...`;
- no theme/settings backend expansion during this milestone.

### 1.8 HakuMenu

Reference: `hakumenu.png`.

HakuMenu is a distinct top-center surface and must remain separate from Navigation.

Physical rule:

```text
menuCenterX = outputWidth / 2
```

Do not center it based on changing MPRIS/title width.

Tabs are exactly:

```text
General
Drun
Theme
```

Geometry rules:

- physical center X and height stay stable; General uses the approved compact width (95% of standard), while Drun/Theme use standard width and morph between widths;
- tab strip/list/state blocks use one radius family;
- vertical origin is derived from RoundedScreen/frame attachment;
- Theme alone shows the narrow right state region;
- General/Drun hide that region; the menu remains centered while width follows the approved tab-width morph.

Data/content rules:

- General parses the actual `hm_general.sh` output contract;
- Drun is the native Hikai launcher presentation equivalent to the old `rofi -show drun` interaction;
- Theme remains a stub in this revision.

### 1.9 Wallpaper selector — centered stacked carousel

Reference: `wallpaper-change.png`.

This **supersedes** the older full-width Flare/dual-front Wallpaper design.

Style model:

- no large generic panel background behind the carousel;
- current selected wallpaper is the prominent fixed center item;
- side wallpapers form stacked/overlapping left/right strips;
- physical carousel center never drifts while thumbnails load;
- Left/Right arrows and mouse wheel move selection;
- Enter applies the current selection;
- content/action execution remains in the existing wallpaper service/script boundary.

Motion is carousel movement around one `selectedIndex`, not a dual-front mask reveal.

### 1.10 Existing frame-attached shell surfaces

The new P3 mockups do not cancel these established style directions:

- **Notification popup:** borderless black Flare/toast; source X from Notification control, frame-derived Y; no generic card stroke.
- **Notification Center:** non-modal right-side shell surface, wider spacing, taller history viewport, `Clear` uses accent fill + black text; hover may grow label without changing allocated geometry.
- **Level OSD:** compact, physical-center stable, fixed percentage slot, same layout for volume/brightness, frame-derived attachment. Treat icon + level track + percentage as one optically centered group; do not let asymmetric slots bias the content to one side.
- **Tray / Tooltip:** X from source control, Y from shared frame geometry, body clamped inside safe bounds while source neck/origin may still point to the true trigger.

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
| `fast` / `normal` / `slow` | 100 / 220 / 400 ms | generic short/normal/slow transitions |
| `spatial` / `effects` | 350 / 200 ms | workspace/flare geometry and effect transitions |
| `trailFactor` | 1.5 | trailing edge duration multiplier (workspace worm, flare morph) |
| `moduleCurve` | `[0.16, 1.0, 0.3, 1.0]` | module motion |
| `tooltipCurve` | `[0.4, 0.0, 0.2, 1.0]` | tooltip-specific curve token |
| `shellCurve` | `[0.16, 1.0, 0.3, 1.0]` | drawers/layers |
| `spatialCurve` | `[0.5, 1.21, 0.22, 1, 1, 1]` | workspace/flare spatial overshoot |
| `effectsCurve` | `[0.56, 0.8, 0.34, 1, 1, 1]` | workspace/flare effects |
| `buttonHoverDuration` | 140 ms | ordinary hover transition |
| `buttonPressDuration` | 80 ms | press/compress feedback |
| `buttonReleaseDuration` | 170 ms | soft release/return |
| `buttonSelectDuration` | 220 ms | selected-state and moving-pill morph |
| `buttonFocusDuration` | 160 ms | focus/search-field transition |
| `buttonHoverCurve` | `[0.20, 0.80, 0.20, 1.0, 1, 1]` | restrained hover |
| `buttonPressCurve` | `[0.40, 0.00, 0.20, 1.0, 1, 1]` | quick press |
| `buttonReleaseCurve` | `[0.16, 1.08, 0.30, 1.0, 1, 1]` | very small release overshoot |
| `buttonSelectCurve` | `[0.16, 1.00, 0.30, 1.0, 1, 1]` | calm selection morph |
| `buttonFocusCurve` | `[0.20, 0.80, 0.20, 1.0, 1, 1]` | focus transition |

HakuMenu shell-open motion remains a separate profile: ordinary controls must not reuse the bouncy HakuMenu opening curve.

---

## 4. Component style notes

- **Workspaces:** retain the existing dot/worm model and status semantics from the stable baseline. Geometry/animation uses shared tokens rather than ad-hoc per-screen values.
- **Tooltip / Flare:** body uses `Theme.barColor`, text uses the approved accent treatment, and Flare geometry remains centralized in the shared Flare library. P3 attachment is frame-derived.
- **MPRIS / Center:** keep the stable fallback TopBar-center silhouette. Dashboard MPRIS reuses media data but has its own card layout. Do not revive the cancelled center-collar redesign.
- **RoundedScreen:** permanent chassis. Frame edge values come from rounded-screen config/theme and shared geometry; with TopBar visible, keep the top frame instead of deleting it.
- **Navigation:** radial Logo-origin controller from `navigation.png`; Dashboard/Sidebar/Settings only.
- **Dashboard:** avatar + four mockup-defined cards; reserved empty space stays empty.
- **Sidebar:** left-attached rounded lobe with circular options; immediate hover handoff from Navigation.
- **Settings:** large centered stub only; no settings framework in P3.
- **HakuMenu:** physical-center shell surface with General/Drun/Theme; stable center/height with approved width morph (General 95% of standard width); Theme-only state rail. Tabs use a moving selection pill and shared button motion. Its layer-shell is split: Top owns the visual-only Flare/background; Overlay owns the rounded body, content, input and keyboard focus so the menu remains usable over fullscreen clients.
- **Wallpaper:** centered selected item with stacked side carousel; no large background panel and no dual-front reveal.
- **Notification popup:** native P2 model, borderless HakuSpace/Flare visual treatment.
- **Notification Center:** native P2 behavior, P3 spacing/height/primary-Clear polish.
- **Level OSD:** compact body, fixed percentage slot, optical/physical center stability.
- **Picker:** retains the current generic picker styling for workflows that still use it; do not force Wallpaper/HakuMenu into the generic Picker silhouette.
- **Tray icons:** retain application artwork colours; shell hover/background follows existing Tray exception rules.

## 5. Rules for new components

- **No instant interactive state changes:** visible hover, press, selection, focus and toggle changes in Hikai use the shared motion tokens/primitives unless correctness or accessibility requires an immediate response.
- **Motion must not move layout:** hover/press/select effects stay inside stable control bounds and must not change implicit size or push neighboring controls. Surface resize is reserved for explicit shell morphs such as the approved HakuMenu width transition.
- Prefer `components/motion/ButtonMotion.qml`, `MorphButton.qml`, `MorphIconButton.qml` and `SelectionPill.qml` over copy-pasted per-component hover/press `Behavior` blocks.
- Take colours from `Theme` and durations/curves from `HAnimation` unless an existing documented hard-coded exception applies.
- Centralize Flare geometry in the shared Flare library; do not reimplement flare maths in each panel.
- For split-layer shell surfaces, keep one geometry/morph source of truth. Visual-only Top layers must use an empty input mask; interactive Overlay layers own content/focus and must not duplicate Flare geometry.
- Centralize RoundedScreen/frame geometry per output; do not copy frame-offset arithmetic into individual surfaces.
- Paint outlines define silhouette/grouping unless the mockup explicitly calls for a visible border.
- Preserve surface-specific shape identity: do not replace Navigation/Sidebar/HakuMenu/Wallpaper with a generic black rounded card simply for code reuse.
- Shared primitives may own focus, input mask, lifecycle, list cells and tokens while still allowing distinct visible geometry.
- One accepted visual/functional unit becomes one Git commit before the next dependent unit begins.
- If a visual review reaches two failed metric-only tuning rounds, stop and revise the local geometry model instead of continuing trial-and-error.
- Do not invent behavior where a mockup is silent. Use a stub/disabled action or request a separate spec.
- Keep Classic behavior isolated from Hikai-native rewrites unless the plan explicitly changes both modes.

## 6. Known exceptions to "no hard-coded colours"
| Where | Value | Why |
|---|---|---|
| `TopModule.qml` | `#ff3333` (urgent text) | no urgent-text token yet |
| `LevelOsdOverlay.qml` | `#000000` (OSD body) | matches fixed background policy |
| `RoundedScreen.qml` | `#000000` fill and stroke | frame is always black |

Suggested token if the urgent colour is centralized later: `Theme.urgentText`.

---

## 7. Observations

- Opaque mode currently keeps the bar at black because both `bg` and `inkBg` are black.
- The current token file is flat; older nested-schema/shadow descriptions are obsolete.
- The P3 mockups deliberately leave several semantic areas unspecified (for example Sidebar dot meanings and the real Theme tab). Those omissions are scope boundaries, not invitations to invent product behavior.
- The latest Wallpaper mockup invalidates the earlier dual-front/wide-Flare implementation direction.
- The latest P3 plan keeps the stable fallback TopBar center; only HakuMenu triggering/anchoring is added around it.
