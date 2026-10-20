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

## Post-P3 Settings surface and geometry ownership

This addition supersedes the fixed surface/radius assumptions in the historical
baseline below. It does not change the accent/font flow or the P3 motion contract.

`~/hakucfg/hikai/hikai-shell.json` (schema version 6) stores appearance,
RoundedScreen geometry, TopBar module preferences and shared app artwork/Dockbar
preferences. The `dock` section contains `visibilityMode`, `exclusiveSpace`,
`iconSize`, `hoverLift`, `hoverScale`, `showTrash` and `showDevices`. There is no style
selector. Icons range from 32–72 px in 4 px steps (default 36); explicit legacy sizes
survive migration. Shared pins remain in `~/hakucfg/config/taskbar-pin-apps`.

`taskbar_manual_state` enables Taskbar Mode; `dockbar_manual_state` independently
requests the compact Dockbar. `ChromeLayout` derives effective owners:

| Taskbar Mode | Dockbar requested | Effective chrome | Default / top-edge HakuMenu |
|---|---|---|---|
| OFF | OFF | TopBar | topFlare |
| OFF | ON | TopBar + compact Dockbar | topFlare |
| ON | either | Taskbar only | bottomFlare / no top trigger |

`Taskbar.qml` owns one full-width bottom surface, status lanes and a physically
centered app viewport. It stays visible and reserves its full height. Its App Menu
opens `bottomFlare`. TopBar and compact Dockbar are suppressed while their stored
preferences remain intact. Center/Cava are absent from the bottom status lane.

`DockBar.qml` owns only the compact dock inside TopBar mode. It keeps autohide/always
and optional exclusive-space behavior. Its App Menu explicitly opens `dockFloating`;
keyboard/IPC calls always use the topology default. Both hosts reuse
`appbar/AppBarContent.qml` for app actions, pins, dragging, devices and Trash.

The compact surface remains a borderless trapezoid with straight slanted sides,
rounded upper corners and concave bottom flares. Content follows RoundedScreen's
side/bottom insets; its 20% activation strip stays at the physical bottom edge.
Visuals and input use Top, so fullscreen clients may cover the Dockbar and its trigger.
It has 24 px horizontal padding, zero bottom padding and a 2 px artwork-to-dot gap.

`ScreenGeometry` separates Taskbar's fixed reservation from per-output Dockbar
reservations. RoundedScreen terminates above Taskbar and returns to the physical
bottom in TopBar mode, regardless of Dockbar presence. Tooltip, tray, Notification Center,
Navigation, Dashboard, Sidebar and Settings motion follow Taskbar vs TopBar attachment.
Level OSD and notification popups always use the top center, below TopBar when it
exists and at the inner top edge of RoundedScreen in Taskbar Mode. They retain Top Flare visuals and
Overlay content. Only background Flare geometry reflects; content stays upright.

The supervisor runs `hikai_chrome_state_ctl.py migrate` before every Quickshell start,
covering both login and backend switching. A journal makes the v5 state split
restartable and idempotent; settings migrate directly from v1–v5 to v6. Legacy
shared ON + bar becomes Taskbar ON/Dockbar OFF, ON + dock becomes OFF/ON, and OFF
becomes OFF/OFF. Later toggles never erase the other requested state.

Hikai ignores `waybar_manual_state`; its Waybar toggle preserves Classic preferences.
Classic Taskbar process behavior remains unchanged. Dockbar control never launches
Waybar. Trash and mounted-device shortcuts can be hidden independently without
empty slots. Compact reservations appear on reveal and release on hide, per output.

Dock icons have no hover, pressed or focused background. Settings sliders control
hover lift from 0–48 px (default 14) and enlargement from 0–100% (default 0).
Zero disables each effect independently; 100% enlargement doubles artwork size.
Applying icon size also updates image modules in `~/hakucfg/config/taskbar-pin-apps`
while preserving comments and commands. Newly pinned apps inherit the group's size;
preview and Discard leave the shared file untouched.
Artwork grows upward with weaker effects on neighbors; slots and full-accent dots
stay fixed. The viewport, pointer headroom and captured anchors follow both effects.
Drag a pinned icon (including Applications) past the platform movement threshold,
or hold it for 250 ms, to reorder it.
The grabbed icon follows the pointer and an accent marker shows the drop position;
crowded docks scroll at their edges. Release commits one move to the shared
Classic/Hikai pin file. Escape, outside drops, manual OFF and external pin changes
cancel the gesture. Dragging leases autohide and suppresses tooltips and activation.
Pin/unpin results appear above the originating Dock for two seconds without system
notifications. Feedback briefly leases autohide and yields to dragging or termination.
Tooltips appear immediately and share the Dock's pointer/keyboard mode. Pointer
tooltips require the current shared pointer position inside that icon's slot;
restored window focus cannot create a keyboard tooltip. Tab selects one keyboard
tooltip, and pointer motion returns ownership to the hovered icon. HakuMenu hides
Dock tooltips while open. Escape dismisses them until the next hover/click.
Keyboard focus still exposes labels and keyboard-triggered warnings.
Right-click toggles pin/unpin directly. On
Niri/Hyprland/Mango, middle-click sends SIGTERM to compositor-reported app PIDs
and descendants. At or above Exit's saved `RAM_THRESHOLD_MB`, a tooltip requires
a second middle-click on the
same app; moving away, Escape or another action cancels confirmation. Process
identity is checked again before signalling; unavailable PIDs leave an error
tooltip instead of guessing from names.
Labwc uses native Wayland close requests because its Dock protocol exposes no
app PID/RAM metadata. It always asks for confirmation, rechecks the exact window
objects, and requests closing only those windows; it does not force-terminate
unresponsive apps. Dock activation restores minimized windows before focusing them.
Dock icons use one `dock_icon_watch.py` process while manual Dock state is ON.
It follows GTK settings/GSettings, active and inherited theme directories, and
resolved icon files with native GIO monitors. File URLs carry modification versions
and bypass the Qt image cache; icon refreshes leave app keys, focus and slots intact.
No timer polls or full shell reloads are used for icon edits or theme changes.
Dock open/close durations are 360/224 ms. HakuMenu uses 360/308 ms for `bottomFlare`
and 504/280 ms for `dockFloating`, reducing open time by 10% and close time by 30%.
The backend's [DEFAULTS](../../src/core/backend/user/hikai_settings_ctl.py) defines the complete schema. `ShellSettingsStore` previews
drafts live; Theme consumes them reactively. Generated `quickshell.json` owns
accent, surfaceHi, foreground colors and font/size, and cannot override these
shell tokens even if an older generated file still contains radius or surface.

| Token | Formula | Default |
|---|---|---|
| radius | R | 12 |
| largeRadius | R + 4 | 16 |
| hugRadius | R + 16 | 28 |
| giantRadius | R + 36 | 48 |

R is an integer in 4–24 px and controls component styling only. NotificationPopup
uses `largeRadius + 4` (20 px by default); the shared Flare ear radius uses
`largeRadius + 8` (24 px). Neither uses the physical screen radius.

RoundedScreen radius (0–24, default 20) and border (0–6, default 4) live in their
own schema section. TopBar adds 4 px below the unchanged content lane. The shared
`ScreenGeometry` contract supplies `flareTopY == Theme.topBarHeight`, independent
side/bottom insets, horizontal bounds, edge hug radius and anchor localization.
The Sidebar ear attaches inside Navigation's rounded contour as its width grows;
its interaction zone follows the same attachment position.

| Surface tone | surface | hoverMuted |
|---|---|---|
| ink | #000000 | #202020 |
| dark (default) | #0b0b0b | #2b2b2b |
| soft | #171717 | #333333 |

Hard-coded radius audit: CalendarGrid navigation, DashboardMonitorCard pill,
DashboardWidgetHost switchers, DashboardMediaCard transport controls,
TempNoteOverlay close button and ThemeAccentPage swatch are proportional/circular
geometry (B). Storage progress, BioWidget decorations, scrollbars, shortcut
badges, ActionMenu micro highlights, ExitPage table furniture and Sidebar morph
seeds are local micro-elements/geometry (C). Zero-radius attachment edges and
WallpaperCarousel cutouts stay zero (D). NotificationPopup chassis and the shared
Flare default are semantic surfaces (A) and now derive from Theme. Existing
semantic cards/panels already using Theme continue to use that family.

TopBar gates default on for workspaces, windowTitle, center, cava, tray,
quickControls, recorder, clock and notifications. Logo has no preference gate.
Workspace/Cava conditions still apply; active recording overrides the idle gate.
No opacity-only hiding is used. Preferences are global and never rewrite Classic.

## 1. General principles (Irunu Style)

1. **Two primary colours:** solid black `#000000` for shell surfaces and the dynamic **accent** for active/selected/hover states, text, icons and state indicators where defined.
2. **Background surfaces:** `Theme.surface` is the canonical opaque black UI surface in the current preset. `Theme.onAccentColor` is the semantic foreground color derived from `surface`. Transparent regions stay transparent when they are real shape cutouts or empty window space.
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

- **Clock & Calendar tooltip:** keep the existing compact stacked time / weekday / date presentation unless a later approved mockup replaces it. In the calendar grid (TopBar tooltip and Dashboard widget), the current day indicator follows the primary active treatment: solid accent background (`Theme.accent`) with black text (`Theme.onAccentColor` / `#000000`), preserving comfortable breathing room (~3–4px clearance) around the day text with no row overlap.
- **Settings group:** icon-dense, values belong in tooltips/secondary surfaces.
- Use `Theme.fontFamily`; existing module labels use the current weight rules unless a mockup explicitly calls for a different hierarchy.

### 1.3 RoundedScreen — shell chassis

Reference: `base.png`.

The post-P3 RoundedScreen refactor supersedes the original top-rail mockup:

- RoundedScreen draws four independent inverted corner masks and explicit left,
  right rails and the horizontal rail opposite the active bar: bottom in TopBar
  mode, top in Taskbar mode. Only that horizontal frame edge reserves space.
- Radius and border are independent, including 0/0, 0/6, 24/0 and 24/6.
- TopBar owns the upper chassis and reserves its total height, with 4 px of bottom
  padding below the unchanged module lane.
- TopBar draws in a full-width window that ignores reservations; an independent,
  input-transparent window reserves its height, keeping live anchors screen-local.
- RoundedScreen respects that exclusive zone: its top corners begin below a
  visible TopBar and return to the screen top when the bar hides. Its own
  side/bottom reservations and the optional Dock reservation are cancelled by
  visual-window margins so its rails remain at the physical output edges.
  Frame reservations use Top; the Dock reservation uses Bottom and follows the frame.
- `ScreenGeometry` owns `roundedRadius`, `leftInset`, `rightInset`, `topBorderThickness`, `bottomInset`,
  `flareTopY`, `edgeHugRadius`, `horizontalBounds()` and `localizeRect()`.
- All top-attached surfaces begin at `flareTopY`; side border changes cannot move
  them vertically. Captured anchors use full screen-local rects.
- Shared Flare rendering overlaps the attachment edge into its parent chassis
  to close antialiased seams. Short-body ears cannot intersect bottom rounding.
- Visual windows remain click-through; only side and active horizontal reservation windows reserve
  space, and all three disappear at border 0.

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

In Taskbar Mode, the radial controller occupies the physical bottom-left corner,
including the bar's Logo footprint. Its three sectors reflect vertically:
Sidebar upper-left, Settings upper-right, Dashboard below. Icon glyphs remain
upright; sector drawing, highlight and hit-testing use the same region angles.
The Sidebar rail gains 20 px through 30 px top/bottom padding in both layouts;
its control stack is centered across the painted attachment overlap.

### 1.5 Dashboard

Reference: `dashboard.png`.

> [!NOTE] 2026-10-10 D4.3 Dashboard runtime override (Superseded by Dashboard V2 - 2026-10-11):
> - final envelope is 50% output width × 50% output height;
> - outer background uses the shared HakuSpace Flare language (top-edge attached Flare surface);
> - shell-level child inset = 20 logical px;
> - Avatar final target = (20, 20) with hover visual enlargement (~1.08x scale);
> - profile rail below avatar displays username/display name;
> - Dashboard has a 200 logical px pointer safe zone beyond the 50% visual shell;
> - moving beyond that safe zone closes Dashboard/Navigation;
> - the safe-zone strip is interaction-owned while Dashboard is open;
> - areas beyond the safe zone remain pass-through;
> - Flare attaches to the RoundedScreen/TopBar seam using the shared edge geometry (4 px border seam attachment);
> - Navigation ↔ Dashboard uses one reversible morph driven by `dashboardMorphProgress` instead of instant visibility swap;
> - upper card cluster remains compact (Clock, MPRIS with background Cava waveform, Calendar host with day hover, Monitor card);
> - Monitor card features circular CPU/RAM or GPU/VRAM gauges switchable via left/right arrows, with persistent root and mounted storage rows underneath;
> - lower/right empty region is intentionally reserved — cards do not stretch across the entire 50% envelope;
> - scoped hover tooltips provide contextual information across Dashboard elements;
> - Dynamic Widget Host remains; Calendar is the first/default widget.

Dashboard contains the 50×50 upper-left attached cluster:

- circular avatar at the Navigation origin while Dashboard is active, with hover enlargement;
- profile rail below avatar with user identity;
- Clock card;
- MPRIS card with controls + thumbnail + subtle Cava audio waveform background while playing;
- Dynamic Widget Slot (`DashboardWidgetHost`, first widget: Calendar with day hover);
- monitor card (`DashboardMonitorCard`) with circular gauge pages and mounted storage:
  - System page: circular `CPU` gauge and circular `RAM` gauge
  - GPU page: circular `GPU` gauge and circular `VRAM` gauge (or `N/A` with neutral track if unavailable)
  - Left/right arrow buttons to switch between System and GPU gauge pages
  - Storage rows underneath remain fixed across page changes:
    - Root storage `/` (`df -P /`)
    - Additional mounted disks/partitions (`/dev/...` block devices)
- Scoped hover tooltips across interactive elements.

The area beyond the 50×50 shell and its 200px pointer safe zone remains transparent and pass-through.

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

Taskbar Dashboard uses one upright content plane inside the upward Flare body.
Avatar and first-row cards align at the top; profile text remains below the
avatar. The distal Flare reach is excluded from the content envelope so cards
cannot protrude through its upper rounded edge.

### 1.6 Sidebar

Reference: `sidebar.png`.

Sidebar is a left-edge expansion from the Navigation Sidebar region.

- opens immediately on Sidebar-region hover;
- pointer handoff from Navigation to Sidebar must not flicker-collapse;
- use an invisible interaction bridge/union if needed;
- visible body is an elongated rounded lobe, not a generic drawer;
- option controls are circles;
- the rail contains Quick Actions, Clipboard and Temp Note;
- the body height fits these three utility controls;
- opening Temp Note keeps keyboard focus and selection on its Sidebar button in both modes; its morph is input-transparent until settled, and Right transfers focus into the open note;
- Temp Note does not pin Sidebar: Escape and pointer exit still dismiss Sidebar without closing the note.

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

HakuMenu remains separate from Navigation. Taskbar uses a bottom-attached Flare. TopBar edge/default callers use a downward top Flare; an explicit compact Dockbar App Menu click uses a floating card.

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

- **Notification popup:** borderless, always horizontally centered at the top. A full-height Top Flare and a centered rounded Overlay share the revealed stack; no generic card stroke. TopBar mode attaches below TopBar; Taskbar mode attaches at the inner top edge of RoundedScreen.
- **Notification Center:** non-modal right-side shell surface, wider spacing, taller history viewport, `Clear` uses accent fill + black text; hover may grow label without changing allocated geometry.
- **Level OSD:** compact, always at the top center, fixed percentage slot, same layout for volume/brightness. It attaches below TopBar when present and at the inner top edge of RoundedScreen in Taskbar mode, with Top Flare and Overlay content. Treat icon + level track + percentage as one optically centered group; do not let asymmetric slots bias the content to one side.
### 1.11 Shared Action Layer (ActionMenu)

Shared modal action menu host replacing standalone Rofi dialogs in Hikai:

- **Host Window:** Single shared fullscreen `ActionMenuPanel` on `WlrLayer.Overlay` with dimmed backdrop, outside-click dismissal, and exclusive keyboard focus.
- **Surface geometry:** Screen-centered rectangle with `Theme.largeRadius` (16px), opaque `Theme.surface` (`#000000`) background, and subtle border stroke.
- **Motion language:**
  - Initial open: circular expanding mask reveal (`actionLayerOpenDuration`) centered on screen diagonal.
  - Close: smooth fade + scale zoom-out (`actionLayerCloseDuration`).
  - Forward morph: originating button seeds `ActionMenuMorphProxy` and expands into child page surface (`actionLayerMorphDuration`).
  - Reverse morph: child surface contracts back to originating button geometry on Back or Escape.
- **Navigation stack:** Dynamic page stack with unified Escape/Back navigation and `ActionMenuSelectionPill` target tracking.
- **Backend separation:** Hikai routes via Quickshell IPC directly to headless `*_ctl.sh` scripts, while Classic continues using standalone `*_rofi.sh` facades.

## 2. Token contract (`quickshell.json` → `Theme.qml`)

`gen_style.sh` → `render_quickshell` writes `~/.local/state/hakuspace/theme/quickshell.json` atomically (`jq` → `.tmp` → `mv`). The file is **flat**:

```json
{
  "preset": "irunu",
  "accent": "#c89a6a",
  "font": "JetBrainsMono Nerd Font",
  "fontSize": 14,
  "surface": "#000000",
  "surfaceHi": "#c89a6a",
  "border": "transparent",
  "fg": "#c89a6a",
  "fgDim": "<ACCENT_DIM>",
  "fgMuted": "rgba(255, 255, 255, 0.5)",
  "radius": 12,
  "largeRadius": 16,
  "hugRadius": 28,
  "giantRadius": 48,
  "borderWidth": 0,
  "gap": 4,
  "pad": 12
}
```
(`accent`, `font`, `fontSize`, `fgDim` come from `state.env`/the accent pipeline; the rest are constants of the preset.) `preset` is informational. The generated `surface` key documents the canonical black UI surface policy. `Theme.qml` keeps it read-only and ignores incoming values so an older generated file cannot restore translucent fills. `surfaceHi` is read-only and bound to `accent`; its JSON value is informational.

`Theme.qml` loads the file with `FileView` (`watchChanges`, `onFileChanged: reload()`), parses it in `apply()` inside `try/catch` (invalid or empty content keeps the previous values), and converts CSS `rgba(r, g, b, a)` strings to `#AARRGGBB` with `parseColor()`.

### Mapping JSON → `Theme`
| JSON key | `Theme` property | Notes |
|---|---|---|
| `fg` | `fg` | equals the accent |
| `fgDim` | `fgDim` | default `#aaaaaa` |
| `fgMuted` | `fgMuted` | `rgba(255,255,255,0.5)` → `#80ffffff` |
| `border` | `border` | `transparent` |
| `surface` | `surface` | fixed opaque `#000000`; canonical black UI surface |
| `surfaceHi` | `surfaceHi` | bound to `accent` for hover/selection; JSON value ignored |
| `accent` | `accent` | |
| `radius`, `largeRadius`, `hugRadius`, `giantRadius` | `radius` (12), `largeRadius` (16), `hugRadius` (28), `giantRadius` (48) | |
| `borderWidth`, `gap`, `pad` | same names | |
| `font` | `font` and `fontFamily` | |
| `fontSize` | `fontSize` | |

### `Theme`-only tokens (not in the JSON)
| Token | Default | Use |
|---|---|---|
| `onAccentColor` | `root.surface` (`#000000`) | black text/icons on accent fills |
| `hoverMuted` | `#2b2b2b` | dark grey hover fill for Tray and WindowTitle |
| `workspaceDot` | `#424242` | inactive workspace status dots |

### Token use
| Token | Used for |
|---|---|
| `surface` | canonical black UI surface; bar, module and card fills, tooltip/flare body, Settings and Picker |
| `surfaceHi` | accent fill on hovered/selected controls |
| `hoverMuted` | dark grey hover fill for Tray and WindowTitle |
| `fg` / `fgDim` / `fgMuted` | primary, dim and muted text/icons (including the WindowTitle class name) |
| `accent` | highlighted text/icons and borders; tooltip text; workspace indicator |
| `onAccentColor` | semantic black text/icons on accent fills, including hover, Settings and MPRIS |
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
- **Tooltip / Flare:** body uses `Theme.surface`, text uses the approved accent treatment, and Flare geometry remains centralized in the shared Flare library. P3 attachment is frame-derived.
- **MPRIS / Center:** keep the stable fallback TopBar-center silhouette. Dashboard MPRIS reuses media data but has its own card layout. Do not revive the cancelled center-collar redesign.
- **RoundedScreen:** permanent chassis. Frame edge values come from rounded-screen config/theme and shared geometry; with TopBar visible, keep the top frame instead of deleting it.
- **Navigation:** radial Logo-origin controller from `navigation.png`; Dashboard/Sidebar/Settings only.
- **Dashboard:** avatar + four mockup-defined cards; reserved empty space stays empty.
- **Sidebar:** left-attached rounded lobe with circular options; immediate hover handoff from Navigation.
- **Settings:** large centered stub only; no settings framework in P3.
- **HakuMenu:** three source-resolved presentations share `HakuMenuContent`. TopBar mode enables a centered 4 px × 20% top-edge hover trigger, with or without Dockbar. Edge/default callers use `topFlare`; Taskbar/default callers in Taskbar Mode use `bottomFlare`; explicit active Dockbar clicks use `dockFloating` with a real icon anchor and owner lease. Attached presentations share `HakuMenuAttachedFlare`, preserving split Top visual/Overlay input, focus, safe zones and tab motion. Taskbar menus remain physically centered despite off-center App Menu icons and use 40% of the output height, matching top-attached menus; Taskbar and Dockbar menus keep their tabs and settings row at the top. Only one logical menu owns focus at a time.
- **Wallpaper:** centered selected item with stacked side carousel; no large background panel and no dual-front reveal.
- **Notification popup:** native P2 model, always top-centered, with complete Top Flare and Overlay surfaces and a downward reveal in both shell modes.
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
| `RoundedScreen.qml` | `#000000` fill and stroke | frame is always black |

Suggested token if the urgent colour is centralized later: `Theme.urgentText`.

---

## 7. Observations

- Opaque mode keeps the bar at black using canonical `Theme.surface`.
- The current token file is flat; older nested-schema/shadow descriptions are obsolete.
- The P3 mockups deliberately leave several semantic areas unspecified (for example Sidebar dot meanings and the real Theme tab). Those omissions are scope boundaries, not invitations to invent product behavior.
- The latest Wallpaper mockup invalidates the earlier dual-front/wide-Flare implementation direction.
- The latest P3 plan keeps the stable fallback TopBar center; only HakuMenu triggering/anchoring is added around it.
