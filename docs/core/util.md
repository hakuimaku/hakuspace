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

### `record.sh`
Your built-in screen recorder.
- **What it does:** Hooks into `wl-screenrec` to capture high-framerate MP4s of your desktop.
- **Features:** Usually triggered via a keybind, it begins recording your screen (with or without audio) and saves the output to your `~/Videos` folder. Pressing the keybind again safely sends an interrupt signal to terminate the recording and encode the file.

## Quality of Life Toggles

### `clipboard_menu.sh`
Never lose copied text again.
- **What it does:** Checks if `wl-paste` is running in the background. If not, it starts watching your clipboard and silently stores everything you copy (both text and images) into a `cliphist` database. 
- **The Menu:** When you trigger the script, it opens a sleek Rofi interface displaying your clipboard history, allowing you to instantly copy old items back to your active clipboard. You can also run it with the `--wipe` flag to nuke your history for privacy.

### `nightlight_toggle.sh`
Saves your eyes during late-night coding sessions.
- **What it does:** Detects your current Window Manager and turns on a blue-light filter. It natively uses `hyprsunset` if you are on Hyprland, and intelligently falls back to `gammastep` for Niri, Labwc, and Mango. 
- **Customization:** It reads the `NIGHT_LIGHT_TEMPERATURE` variable from your `~/hakucfg/setting.sh` file, allowing you to define exactly how warm you want your screen to be (defaulting to 4000K).

### `warp_toggle.sh`
A quick VPN switch.
- **What it does:** Uses the Cloudflare `warp-cli` to toggle your WARP connection on and off, routing your internet traffic through their private network for privacy and speed directly from a keybind or a Waybar module.

### `waybar_manager.sh`
The control center for your status bar.
- **What it does:** Instead of manually restarting Waybar when things go wrong, this script safely terminates and relaunches it. It's also responsible for switching between different structural layouts (like `top`, `island`, `minimal`, `coredge`) and making sure the theming engine's CSS files are correctly linked to the active layout.

### `gen_shortcut.sh`
A desktop shortcut generator.
- **What it does:** Scans common system directories (like `/usr/share/applications` and your Flatpak/Snap folders) for `.desktop` files. You can use it to query available system apps (`-q`), quickly copy an app's shortcut (`-a`) to your `~/Desktop` directory, or interactively select and add a shortcut using a Rofi menu (`-m`). Since HakuSpace has a built-in desktop icon renderer, this gives you functional app icons right on your wallpaper!


---
**Previous:** [System Management](sys.md) | **Next:** [Haku Menu](menu.md)
