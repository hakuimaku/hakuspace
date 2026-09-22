# HakuSpace Scripts

This directory (`src/core/`) serves as the true source and categorized storage for all HakuSpace shell and python scripts.

## Deployment Mechanism

HakuSpace uses a flexible deployment approach to manage scripts:
1. **Source Storage**: All scripts are stored here in categorized directories to keep the source tree organized and maintainable.
2. **Flattened Deployment**: During deployment (`install.sh`), HakuSpace iterates through all files in this directory and its subdirectories, placing them directly into `~/.local/bin`.
3. **Deployment Mode (Symlink or Copy)**: By default, HakuSpace symlinks scripts into `~/.local/bin`, respecting your existing files and allowing changes to reflect immediately. Alternatively, it can copy the files. HakuSpace tracks this deployment state to keep operations consistent.
4. **Global Execution**: Because the scripts are placed directly in `~/.local/bin`, commands, keybinds, and window managers can execute them globally (e.g., `hakumenu.sh` or `wallpaper_select.sh`) without needing the full categorized path.

> **Tip:** If any symlinks are missing or broken, you can run `./doctor.sh` from the root of the repository to automatically audit them, and use `./update.sh` to repair them.

## Directory Structure

Scripts are grouped into the following categories:

* **`lib/`**: Core library scripts (e.g., `haku_theme.sh`) that provide shared functions and variables to be sourced by other scripts.
* **`app/`**: Application-specific managers and logic layers.
  * **`desktop-icons/`**: Scripts for rendering and managing desktop icons.
  * **`cava-layer/`**: Background audio visualizer management.
  * **`taskbar/`**: Taskbar launcher and management utilities.
* **`sys/`**: System-level operations, including power management (shutdown, exit, lock), idle inhibition, and the startup welcome script.
* **`util/`**: General-purpose utilities such as screen recording, screenshot tools, Waybar mode management, and the clipboard menu.
* **`theme/`**: Appearance and styling scripts, including wallpaper selection, accent color generation, and Rofi theme switching.
* **`menu/`**: Scripts powering the HakuMenu interface and its various sub-menus (general, settings, theme).
