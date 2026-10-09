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
- **The Math:** When you pass a Hex color code to this function (e.g., `#1a1a1a`), it converts the Hex values into raw Red, Green, and Blue (RGB) integers. It then calculates the total brightness (`red + green + blue`). 
- **The Fallback:** If the total brightness is less than `180` (meaning the color is dangerously dark and would make your text unreadable against dark backgrounds), the script rejects the color and returns a safe fallback (usually solid white `#ffffff`).

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

