# HakuSpace Quickshell Components Architecture

This directory contains the user interface surfaces, overlays, panels, and reusable components of HakuSpace Quickshell.

## 1. Global Hierarchy & Lifecycle

```
shell.qml (ShellRoot)
  │
  ├── ipc/                     ← External CLI/Process IPC Handlers (Scope - non-visual container)
  │     ├── NavigationIpc.qml  (navigation, hakumenu, actionMenu, launcher)
  │     ├── MediaIpc.qml       (wallpaper, imageEditor, cavaUnderbar)
  │     ├── SystemIpc.qml      (shell, shellTransition, lock, idle, level, windowNavigator, picker)
  │     └── UtilityIpc.qml     (settings, taskManager, tempNote, notif)
  │
  ├── System Bars & Chrome     ← Persistent/semi-persistent surface variants
  │     ├── TopBar.qml         (components/top/)
  │     ├── LeftBar.qml        (components/top/)
  │     ├── Taskbar.qml        (components/appbar/)
  │     ├── DockBar.qml        (components/dock/)
  │     └── RoundedScreen.qml
  │
  └── EphemeralSurfaces.qml    ← Lazy-loaded on-demand overlays (per screen)
        │
        ├── NavigationPanel.qml          (components/sidebar/, components/dashboard/)
        ├── HakuMenuPanel.qml            (components/hakumenu/)
        ├── SettingsPanel.qml            (components/settings/)
        ├── TaskManagerOverlay.qml       (components/taskmanager/)
        ├── ActionMenuPanel.qml          (components/actionmenu/)
        ├── NotificationCenterPanel.qml  (components/notification/)
        ├── NotificationPopup.qml        (components/notification/)
        ├── WallpaperQuickOverlay.qml    (components/wallpaper/)
        ├── WallpaperWorkspace.qml       (components/wallpaper/)
        ├── TempNoteOverlay.qml          (components/editor/)
        └── LevelOsdOverlay.qml          (components/osd/)
```

## 2. Where to Change Variables

| What you want to change | Where to edit | Notes |
| --- | --- | --- |
| Colors, surface tones, border thickness, base radius, fonts, TopBar height, Taskbar font factor, Dock baseline offset, Level OSD bounds | `../config/Design.qml` | Read dynamically by `Theme.qml`, `ScreenGeometry.qml`, and quickshell.json overrides |
| Animation speeds, easing bezier curves, fade timings | `../config/Motion.qml` | Sourced by `HAnimation.qml` |
| Menu lists, action menu items, sidebar tools, icons | `../config/UiCatalog.js` | Static catalog used by HakuMenu, ActionMenu, Sidebar |
| Default settings preferences (dock, idle, topbar modules) | `../config/Defaults.js` | Schema & defaults synced with backend python CLI |
| Settings search metadata, groups, descriptions | `../config/SettingsCatalog.js` | UI definitions for the Settings panel |

> **Note on Geometry Engines**: Low-level geometry libraries (`ScreenGeometry.js`, `HakuMenuGeometry.js`, `FlareGeometry.js`) operate with `.pragma library` as pure mathematical calculation functions (so they can be verified independently by Node.js unit tests without a running QML engine). Their output is consumed at runtime by QML components (`ScreenGeometry.qml`, `HakuMenuAttachedFlare.qml`).

## 3. Directory Layout by Feature Domain

- `base/`: Reusable primitives (`LifecycleLoader`, `SafeZoneController`, `SafeZoneGeometry.js`, `FlarePanelWindow.qml`).
- `flare/`: SVG/Canvas dynamic morphing flare surfaces (`FlareSurface.qml`, `FlareGeometry.js`).
- `top/`: Top bar modules, clock, workspace indicators, system monitors, tray.
- `dock/`: Bottom dockbar, dynamic app icon zooming, autohide trigger.
- `appbar/`: Bottom taskbar mode and window buttons.
- `hakumenu/`: Application launcher, Drun, General menu, Theme picker.
- `settings/`: System and shell settings pages, configuration file editor.
- `taskmanager/`: Process table, Glass grid, system resource cards, mini dashboard.
- `sidebar/`: Vertical utility rail, quick actions, clipboard picker.
- `dashboard/`: Media card, bio widget, calendar, cava visualizer, system gauges.
- `wallpaper/`: Wallpaper browser, video player surface, workspace view.
- `notification/`: Toast popups, notification center history panel.
- `osd/`: Volume and brightness on-screen display.
- `lock/`: Lock session screen, PAM auth, unlock motion.
- `motion/`: Selection pill, reveal animations, shell transition overlays.
- `editor/`: Plain text editor, scratchpad note.
- `cava/`: Audio visualizer bar renderers.

## 4. Workarea Flare Policy: 2-Layer Decoupled Architecture

Any panel, popup, or overlay attached to the workarea that renders a Flare effect (hugging ear curves connecting to `RoundedScreen` or bar edges) **MUST** implement the decoupled 2-layer pattern:

### Why Decouple?
Under Wayland Layer Shell (`zwlr_layer_shell_v1`), the z-order hierarchy is:
`Background (0) < Bottom (1) < Top (2) < [Fullscreen Window] < Overlay (3)`.
* System chrome (`RoundedScreen`, `TopBar`, `LeftBar`, `Taskbar`) resides on `WlrLayer.Top`.
* When any application enters **Fullscreen**, the compositor occludes all `Top` layer surfaces beneath the fullscreen window.
* If a popup renders Flare ears directly on `WlrLayer.Overlay`, those ears stick out into the fullscreen window without any connecting border ("flaring into thin air").

### The 2-Layer Contract
1. **Layer 1: Visual Flare Bed (`WlrLayer.Top`)**:
   - Contains ONLY the `FlareSurface` silhouette with hugging ears.
   - `mask: Region {}` (no input), `WlrKeyboardFocus.None`.
   - The `PanelWindow` is kept permanently mapped (`visible: true; mask: Region {}`) so dynamically opening a panel does not re-map and raise `Top` over an active fullscreen window in compositors like Hyprland.
   - The inner `FlareSurface` is gated with `visible: !root.hasFullscreen && ...` (queried via `ToplevelManager.toplevels`), guaranteeing that flare ears are never rendered into empty screen space when a window is fullscreen.
   - In tiled mode: Visually blends with `RoundedScreen` and screen rails.
   - In fullscreen mode: Naturally covered beneath the fullscreen window and suppressed by `hasFullscreen`.
2. **Layer 2: Interactive Content Core (`WlrLayer.Overlay` / `ShellTransitionState.chromeOverlayLayer`)**:
   - Contains a standalone self-contained rounded body (`Rectangle { radius: Theme.hugRadius; color: Theme.surface }`) with **NO flare ears**.
   - Contains all interactive content, `FlareHost` with `surfaceColor: "transparent"`, safe zones, pointer handlers, and keyboard focus.
   - In tiled mode: Sits directly over Layer 1, appearing as a single seamless flared panel.
   - In fullscreen mode: Floats cleanly over the fullscreen window as a clean rounded card without orphaned flare ears.

All new workarea flare surfaces should inherit from or model their window layout after `base/FlarePanelWindow.qml` or `hakumenu/HakuMenuAttachedFlare.qml`.
