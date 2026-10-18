# The Core Libraries (src/core/lib)

The `src/core/lib/` directory is the foundational layer of HakuSpace. Unlike the utilities or menu scripts that you trigger directly, the files in this folder are **libraries**—they are designed to be sourced (included) by other scripts to share common functions, variables, and state management.

Think of them as the glue that holds the various pieces of the theming engine and window manager integrations together.

Here is a detailed breakdown of the libraries:

## Theming & State Management

### `haku_theme.sh` (The State Manager)
This is the single most important library for the HakuSpace theming engine. It defines the rules for how theme data is stored and retrieved.
- **The Source of Truth:** Instead of letting every script guess what the current accent color or font size is, this library establishes a strict state model. The canonical state is stored securely in `~/.local/state/hakuspace/state/state.env`.
- **Loading & Saving:** It provides `theme_load_state()` to load the current `ACCENT_COLOR`, `FONT_FAMILY`, and `FONT_SIZE` into memory, and `theme_save_state()` to write changes back to the disk atomically (using a temporary file and `mv` to prevent data corruption if the system crashes mid-write).
- **One-Way Rendering:** It strictly enforces that the generated `.css` and `.conf` files in the theme directory are *output only*. Scripts must never read those files to figure out the theme; they must always query the state manager.
- **Defaults:** It acts as the fallback mechanism. If a variable is missing or corrupted, it automatically provides safe defaults (e.g., `#ffffff` for accent color, `monospace` for fonts).

### `accent_color.sh` (The Color Validator)
A small but critical mathematical utility used during the wallpaper color extraction process.
- **What it does:** It provides a single function: `accent_color_or_fallback`.
- **The Math:** When you pass a Hex color code to this function (e.g., `#1a1a1a`), it calculates the WCAG relative luminance to accurately determine the visual brightness of the color (accounting for how the human eye perceives different wavelengths).
- **The Fallback:** If the perceived luminance is too low (meaning the color is dangerously dark and would make your text unreadable against dark backgrounds), the script rejects the color and returns a safe fallback (usually solid white `#ffffff`). This WCAG-based calculation is vastly superior to naive RGB addition!

### `haku_appearance.sh` (The Appearance Loader)
While `haku_theme.sh` tracks dynamic runtime state (like the current wallpaper's hex color), `haku_appearance.sh` handles your personal choices for GTK, Icon, and Cursor themes.
- **What it does:** It checks if you have a custom `~/.config/hakuspace/appearance.env` file and loads your settings. If you haven't configured anything, it provides the default HakuSpace look: `Hikaide` for GTK, `Hikaide-Symbols` for icons, and `Haku-Dark` (size 24) for your mouse cursor.
- **Why it matters:** Keeping your theme choices separate from `state.env` means changing your wallpaper or accent color will never accidentally reset your favorite cursor or icon pack!

## Shell Backend & Picker Abstraction

### `haku_backend_lib.sh` (The Shell Switchboard)
Because HakuSpace lets you switch between **Classic** (Waybar/Rofi/SwayNC) and **Hikai** (Quickshell), scripts need an easy way to know which shell is currently active.
- **What it does:** Reads and manages the `~/.local/state/hakuspace/state/shell_backend` file, and provides simple helper functions like `haku_backend_get()`, `haku_qs_mode()`, and `haku_qs_alive()`.
- **Talking to Quickshell:** It also provides `haku_qs_ipc`, a handy wrapper around `qs -c hakuspace ipc call` that lets bash scripts trigger Quickshell menus and panels directly while logging any errors to `${XDG_RUNTIME_DIR}/hakuspace/qs.log`.

### `haku_pick.sh` (The Universal Menu Prompt)
Ever wondered how a single script can pop up a Rofi menu in Classic mode, but open a native Quickshell picker when you're in Hikai mode?
- **What it does:** Acts as a universal `dmenu` replacement. You pipe a list of options into `haku_pick.sh`, and it prints whatever the user clicked back out to `stdout`.
- **How it works:** In Classic mode, it simply launches `rofi -dmenu`. In Hikai mode, it packs the options into a temporary JSON file, opens a named pipe (`FIFO`), and asks Quickshell's native picker to display the list and send back your choice!

## Window Manager Abstraction

### `reload_config.sh` (The Universal Reloader)
HakuSpace supports four different Window Managers (Hyprland, Niri, MangoWM, and Labwc), which means applying a configuration change normally requires four different commands. This script abstracts that complexity away.
- **What it does:** It intelligently detects your current active Window Manager using the `XDG_CURRENT_DESKTOP` environment variable.
- **Execution:** 
  - If you're on Hyprland, it runs `hyprctl reload`.
  - On Niri, it runs `niri msg action load-config-file`.
  - On MangoWM, it triggers `mmsg -d reload_config`.
  - On Labwc, it executes `labwc --reconfigure`.
- **Why it matters:** Because of this library, other scripts (like theme switchers or setting toggles) don't need to care about which Window Manager you are using. They just call `reload_config.sh` and trust that the system will handle it correctly!

---
**Previous:** [Management](../management.md) | **Next:** [Theming Engine](theme.md)
