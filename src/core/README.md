# HakuSpace Scripts

This directory (`~/.local/share/hakuspace`) serves as the true source and categorized storage for all HakuSpace shell and python scripts.

## Deployment Mechanism

HakuSpace uses a hybrid **"copy for source, symlink for runtime"** approach to manage scripts:
1. **Source Storage**: All scripts are stored here in categorized directories to keep the source tree organized and maintainable.
2. **Flat Symlinking**: During deployment (`install.sh` or `update.sh`), HakuSpace creates a flat symbolic link for every script directly into `~/.local/bin`. 
3. **User-Owned `~/.local/bin`**: By using symlinks, HakuSpace respects your `~/.local/bin` directory. HakuSpace only manages (and cleans up) its own symlinks, ensuring your personal binaries are never interfered with or unnecessarily backed up.
4. **Global Execution**: Thanks to the symlinks, commands, keybinds, and window managers can execute scripts globally (e.g., `hakumenu.sh` or `wallpaper_select.sh`) without needing to specify the full categorized path.

> **Tip:** If any symlinks are missing or broken, you can run `./doctor.sh` from the root of the repository to automatically audit and repair them.

## Directory Structure

Scripts are grouped into the following categories:

* **`lib/`**: Core library scripts (e.g., `haku_theme.sh`) that provide shared functions and variables to be sourced by other scripts.
* **`app/`**: Application-specific managers and logic layers.
  * **`desktop-icons/`**: Scripts for rendering and managing desktop icons.
  * **`cava-layer/`**: Background audio visualizer management.
  * **`dockbar/`**: Dockbar launcher utilities and auto-hide logic.
* **`sys/`**: System-level operations, including power management (shutdown, exit, lock), idle inhibition, and the startup welcome script.
* **`util/`**: General-purpose utilities such as screen recording, screenshot tools, Waybar mode management, and the clipboard menu.
* **`theme/`**: Appearance and styling scripts, including wallpaper selection, accent color generation, and Rofi theme switching.
* **`menu/`**: Scripts powering the HakuMenu interface and its various sub-menus (general, settings, theme).

