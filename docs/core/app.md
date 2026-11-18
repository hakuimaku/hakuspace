# HakuSpace Mini-Apps

HakuSpace includes custom mini-applications and desktop widgets built by combining existing Linux tools with custom bash and Python scripts in `src/core/`.

Currently, the following mini-apps are available:
- [**Taskbar (Hikai), Classic AppBar & Shared Pins**](#the-taskbar)
- [**Desktop Icons**](#desktop-icons)
- [**Cava Underbar**](#cava-underbar)

---

## The Taskbar

Taskbar control separates the compatibility facade, controller, and shared pin/icon helpers used by Hikai's dock/taskbar and Classic's standalone AppBar.

### Taskbar control split
The public command remains `taskbar_manager.sh`, so existing keybinds and HakuMenu actions stay intact.

- **`taskbar_manager.sh` (compatibility facade):** preserves `--startup`, `--reload`, `--toggle`, `--app-name`, and `--icon-size` and routes operations to `taskbar_ctl.sh`.
- **`taskbar_ctl.sh` (controller):** owns `[desktop].taskbar.requested` for Hikai (and updates `[cava].position` when `cava.dynamic-position` is enabled). In Classic mode, `--startup`, `--reload`, `--toggle`, `--set`, and `--status` route to `appbar_ctl.sh` (`[desktop].appbar.enabled`), keeping Classic and Hikai preferences separate.

State lives under `~/.local/state/hakuspace/state/`: `[desktop].taskbar.requested` stores Hikai's preference and `[desktop].appbar.enabled` stores Classic AppBar's preference. See [Hikai](../hikai.md) for shell architecture.

### Classic AppBar (`appbar_layer.py`, `wlr_toplevel.py`, `appbar_ctl.sh`)
In Classic mode, HakuSpace provides a standalone vertical left-edge application bar built with GTK3 and `GtkLayerShell`, separate from Waybar:
- **Cross-WM Toplevels:** `wlr_toplevel.py` speaks `zwlr_foreign_toplevel_manager_v1` directly over the Wayland socket, tracking open windows and issuing activate/close requests uniformly across Hyprland, Niri, MangoWM, and Labwc.
- **Shared Pin Sync:** Watches `~/hakucfg/config/taskbar-pin-apps` and mutates pins through `pinned_apps_ctl.py` so pinned apps stay synchronized with Hikai's Dock.
- **Retro Styling & Hot Reload:** Reads Classic `palette.css` and `fonts.css`; `apply_style.sh` invokes `appbar_ctl.sh reload-style` (`SIGUSR1`) to refresh colors and fonts live without restarting the bar. When Waybar is toggled back on, `waybar_ctl.sh` reloads AppBar afterwards so Waybar retains the full-width top edge.

### `taskbar_geticon.sh` (The Icon Fetcher)
The Taskbar needs to display the correct icons for your pinned applications.
- **What it does:** It reads your personal list of pinned apps from `~/hakucfg/config/taskbar-pin-apps`. 
- **Icon Resolution:** Since Linux apps don't always have straightforward icon paths, this script hunts through your `/usr/share/icons/`, `~/.local/share/icons/`, and current GTK icon theme to find the highest resolution SVG or PNG that matches the app's desktop entry, ensuring your dock always looks crisp. 
- **Caching & Theme Detection:** It intelligently caches the resolved icons and accurately detects your current GTK theme to speed up fetching times and provide better matching for dynamically changing themes.

---

## Desktop Icons

One of the biggest sacrifices when moving from traditional Desktop Environments (like XFCE or KDE) to modern Wayland compositors (like Hyprland or Niri) is losing your desktop icons. HakuSpace solves this by bringing them back with a fully native, Wayland-compatible desktop icon renderer!

### `desktop_icons.py` (The Engine)
This is a surprisingly powerful Python application built on top of `GtkLayerShell` and `Cairo`. Instead of being a normal window, it draws itself directly onto the background layer of your screen, sitting quietly beneath all your other windows.

- **Full Interactivity:** It isn't just a static picture! It supports double-clicking to launch apps, dragging boxes to multi-select, holding `Ctrl` to select specific files, and even keyboard shortcuts like `Ctrl+C` (Copy) and `Ctrl+X` (Cut). Added interactive options enhance how HakuSpace elements are managed.
- **Drag & Drop:** It natively integrates with Wayland's Drag and Drop API. 
  - You can drag files from Thunar (or any file manager) straight onto your desktop. 
  - You can freely drag icons around to rearrange them. The grid positions are automatically saved to a `positions.json` file so they stay exactly where you left them after a reboot!
- **Auto Arrange:** Tired of messy desktops? The application now features an Auto Arrange mode (enabled by default) that automatically snaps your icons into a neat grid, ensuring your desktop always looks organized.
- **Customizable Actions:** By default, dragging a file *onto* the desktop copies it, while dragging a file *off* the desktop cuts it. You can change this behavior (e.g., creating symlinks instead of copying) in its configuration file.

### `desktop_icons_manager.sh` (The Launcher)
Just like the Taskbar, the Desktop Icons app has its own manager script that links to the Haku Menu.
- **What it does:** It tracks the ON/OFF state of the desktop icons in `~/.local/state/hakuspace/state/[desktop].icons.enabled`.
- **Shell independence:** Desktop Icons is a standalone Wayland app. Its manager owns the process lifecycle regardless of the selected shell mode.
- **Usage:** You can use `--toggle` to instantly show or hide all your icons, `--reload` to refresh the grid (useful if you just pasted a new file via the terminal), or `--startup` to automatically launch the python engine when you log in.

### Configuration
You can customize almost everything about how your icons look and behave.
- **Where:** Check `~/hakucfg/config/desktop-icons/desktop-icons.conf`.
- **Options:** You can change the icon size, sorting method (by name, date, size), whether to show hidden files, or toggle the visibility of special system folders like `Home`, `Trash`, and `Computer`.

---

## Cava Underbar

If you like having an audio visualizer on your desktop, HakuSpace embeds `cava` across both backends: in Hikai as a native Quickshell visualizer (`cava_manager.sh --run-hikai`), and in Classic as a standalone transparent layer-shell bar (`cava_layer.py`).

### `cava_layer.py` (Classic VTE Wrapper)
This Python script uses `GtkLayerShell` and standard `VTE` (Virtual Terminal Emulator):
- **Layer Shell Embedding:** Creates a borderless, transparent, click-through VTE terminal anchored to the top of the screen on the `BOTTOM` layer with `exclusive_zone = 0`, so it respects exclusive zones of other layers (such as Waybar) without pushing tiled windows.
- **Scheme Palette Syncing:** Reads the active Classic scheme token (`select_bg`, falling back to `title_bg`) directly from `~/.local/state/hakuspace/theme/classic/palette.css` and maps it across the VTE ANSI palette without any dependency on Kitty.
- **Running Cava:** Spawns `cava -p <config>` inside the VTE terminal (`orientation = top` in Classic).

### `cava_manager.sh` (The Process Controller)
Because the Classic Python script runs as a background daemon and Hikai consumes raw audio frames, `cava_manager.sh` coordinates both modes:

**Developer Note on CLI conventions:** Unlike manager scripts that use long flags only, `cava_manager.sh` combines positional sub-commands (`start`, `stop`, `toggle`, `reload`) with flags (`--position [top|bottom]`, `-H`/`--height`, `-d`/`--toggle-dynamic`, `-c`/`--color-switch`).

- **Toggling:** `cava_manager.sh toggle` starts or stops the visualizer and persists the request in `~/.local/state/hakuspace/state/[cava].enabled`.
- **Position, Dynamic Mode & Color Mode (Hikai only):** `--position`, `--toggle-dynamic`, and `--color-switch` manage Hikai visualizer layout and color preferences (`[cava].position`, `[cava].dynamic-position`, `[cava].color-mode`). In Classic, position is always top under existing exclusive zones and the color always tracks the active Classic scheme.
- **Live Reloading:** Calling `cava_manager.sh reload` sends `SIGUSR1` to `cava_layer.py`, which re-reads `classic/palette.css` and updates VTE colors immediately without restarting `cava`.



---
**Previous:** [Haku Menu](menu.md) | **Home:** [Architecture Overview](../architecture.md)
