# The Utility Toolbelt (src/core/util)

While the theming engine makes HakuSpace look aesthetically pleasing, the scripts inside `src/core/util/` make it actually useful! This folder acts as your personal toolbelt, filled with handy shell scripts that automate daily tasks, manage background services, and interact with your Window Manager.

Here is a detailed breakdown of what each utility script does under the hood:

## System & Workspace Management

### `clean.sh` (The Housekeeper)
Over time, applications dump a lot of cache and system logs that silently eat up your storage space.
- **What it does:** It forcefully wipes out everything in your `~/.cache` folder, intelligently clears unneeded package files based on your distro (gracefully handling `yay`, `dnf`, and `nix-collect-garbage`), and vacuums up `systemd` journal logs that are older than two weeks.
- **Safety:** It prompts for your confirmation (`y/n`) in the terminal before nuking anything, ensuring you don't accidentally wipe data while you're working.

### `haku.sh` (Desktop Widgets)
Ever wanted some cool, floating widgets integrated directly into your desktop?
- **What it does:** It spawns instances of the Kitty terminal running purely aesthetic CLI tools (such as `cava` for audio visualization, `tty-clock` for a giant retro clock, and `lavat` for a lava lamp effect). 
- **Usage:** You can pass the `--clear` argument to gracefully hunt down and kill the PIDs of all these floating windows when you're done looking at them.

### `open_browser.sh` & `open_config.sh` (Quick Access)
Shortcuts designed to get you into your workflow faster.
- **`open_browser.sh`:** Queries your `xdg-mime` settings to find your default web browser and launches it. If it can't definitively find one, it falls back to a generic `xdg-open https:` command to let the system handle the routing.
- **`open_config.sh`:** Gathers the paths to all your crucial config folders (Waybar, Rofi, Kitty, SwayNC, Cava, etc.) and seamlessly opens them all simultaneously inside a single VS Code window (`code -n`). It intelligently detects your current Window Manager (Hyprland, Niri, Mango, or Labwc) and opens its specific config folder too!

### `fix_icon_theme.sh` (Icon Theme Fixer)
Keeps your file manager and application icons looking consistent.
- **What it does:** Scans your `~/.icons` directory for installed icon themes and automatically fixes missing or incorrectly named file type icons (like shell scripts, Python, or Ruby files) by creating the appropriate symlinks based on a predefined mapping. 
- **Cache Rebuilding:** Automatically rebuilds the icon cache using `gtk-update-icon-cache` for each processed theme so your system recognizes the new icons immediately.

## Media & Screen Capture

### `screenshot.sh`
A robust wrapper around your Wayland screen capture tools.
- **What it does:** Uses tools like `grim` and `slurp` to let you capture full screens, specific areas, or active windows. It automatically pipes the image directly to your clipboard while simultaneously saving a timestamped, high-res PNG into your `~/Pictures` folder.

### Screen recording
Screen recording keeps the long-standing `record.sh` keybind command, but selection and capture lifecycle are now separated.

- **`record.sh` (compatibility facade):** with no arguments it preserves the old toggle behavior: stop an active recording, otherwise open the Classic picker. It also exposes explicit `--status`, `--list-modes`, `--list-sources`, `--start`, and `--stop` commands for non-Rofi callers.
- **`record_ctl.sh` (headless backend):** owns `wl-screenrec`, PipeWire/Pulse setup, physical source discovery, virtual mic+system mixing, timer/state files, and stop/cleanup. Stable mode IDs are `system-audio`, `mic-system`, and `no-audio`.
- **`record_rofi.sh` (Classic frontend):** owns only the mode and microphone/source menus, then delegates the selected stable IDs to `record_ctl.sh`.

Recordings still default to `~/Videos`, and invoking the public facade again while recording still sends the normal interrupt/cleanup path.

## Quality of Life Toggles

### Clipboard history
Clipboard history is split into a headless controller and the Classic picker while keeping the existing public command stable.
- `clipboard_ctl.sh` owns `cliphist` history actions and the `wl-paste` watcher lifecycle. Its explicit commands are `ensure-watchers`, `list`, `copy`, and `wipe`; it does not own picker UI.
- `clipboard_rofi.sh` is the Classic picker. It asks the controller to ensure watchers, displays the raw history rows, then sends the selected row back to `copy`.
- `clipboard_menu.sh` remains the compatibility facade used by existing keybinds. No arguments open the Classic picker; `--wipe` preserves the old clear-history behavior. Headless callers may use `--ensure-watchers`, `--list`, and `--copy`.

### `nightlight_toggle.sh`
Saves your eyes during late-night coding sessions.
- **What it does:** Detects your current Window Manager and turns on a blue-light filter. It natively uses `hyprsunset` if you are on Hyprland, and intelligently falls back to `gammastep` for Niri, Labwc, and Mango. 
- **Customization:** It reads the `NIGHT_LIGHT_TEMPERATURE` variable from your `~/hakucfg/setting.sh` file, allowing you to define exactly how warm you want your screen to be (defaulting to 4000K).

### `warp_toggle.sh`
A quick VPN switch.
- **What it does:** Uses the Cloudflare `warp-cli` to toggle your WARP connection on and off, routing your internet traffic through their private network for privacy and speed directly from a keybind or a Waybar module.

### Waybar management
Waybar keeps the long-standing `waybar_manager.sh` public command, but its responsibilities are now split so Hikai can reuse the control logic without driving a Classic picker.

- **`waybar_manager.sh` (compatibility facade):** preserves the existing startup/keybind CLI (`--cycle`, `--select`, `--reload`, `--toggle`) and the current Hikai policy where only the `top` variant is supported.
- **`waybar_ctl.sh` (headless backend):** owns mode discovery, current-mode state, symlink changes, Waybar lifecycle, explicit `list/current/set/cycle/toggle/reload/startup` operations, and contains no picker UI.
- **`waybar_rofi.sh` (Classic frontend):** displays the Classic mode selector and passes the selected mode id to `waybar_ctl.sh set`.

Default and user modes still come from the existing Waybar directories plus `WAYBAR_MODE_USER` in `~/hakucfg/setting.sh`; source-tree organization does not change the flat `~/.local/bin` deployment contract.

### Login shell switching
Login-shell switching keeps the existing `shell_switcher.sh` public command while separating Classic picker/authentication UX from the mutation backend.

- **`shell_switcher.sh` (compatibility facade):** no arguments preserve the Classic picker and `--print` preserves the wrapper-friendly behavior. Headless callers can use `--list [--json]`, `--current`, and `--set <shell-id/path>`.
- **`shell_ctl.sh` (headless backend):** discovers supported `fish`/`zsh` installs, reports the passwd login shell, registers a selected binary in `/etc/shells` when required, and performs `chsh`. It never opens Rofi or asks for credentials. Non-interactive authorization that cannot proceed returns exit status `77`.
- **`shell_rofi.sh` (Classic frontend):** owns the Rofi shell picker and the existing Rofi sudo-password flow, then retries the explicit backend mutation. Terminal launches still start the selected shell after a successful change, while `--print` only returns its resolved path.

The NixOS guard remains in the backend: login shells on NixOS must still be configured declaratively.

### Desktop shortcut tools
Desktop-shortcut discovery and mutation are separated from the Classic picker while keeping `gen_shortcut.sh` compatible.

- **`gen_shortcut.sh` (compatibility facade):** preserves custom shortcut creation, `-a/--add`, legacy `-q/--query`, and `-m/--menu`. Headless callers can use `--list [keyword]` or explicit `--create <name> <exec> [icon]`.
- **`shortcut_ctl.sh` (headless backend):** discovers `.desktop` entries across the existing system/user Flatpak/Snap paths, copies/trusts an existing entry, or creates a new one. It has no Rofi/picker dependency.
- **`shortcut_rofi.sh` (Classic frontend):** owns the `Add Shortcut` Rofi menu and sends the selected `.desktop` path to the backend.

This keeps the desktop-icons `Add Shortcut` integration compatible while exposing shortcut operations independently of Classic UI.


---
**Previous:** [System Management](sys.md) | **Next:** [Haku Menu](menu.md)
