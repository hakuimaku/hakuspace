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

- `base/`: Reusable primitives (`LifecycleLoader`, `SafeZoneController`, `SafeZoneGeometry.js`).
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
