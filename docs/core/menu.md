# The Haku Menu (src/core/menu)

Haku Menu provides a public entry point for desktop actions. The scripts in `src/core/menu/` handle routing and shared action providers.

This document covers those scripts and the Classic Rofi adapter. See [Hikai](../hikai.md) for shell architecture.

The providers supply choices and dispatch actions through the relevant public commands.

## The Main Hub

### `hakumenu.sh`
This is the stable public entry point used by keybinds and other callers. It routes requests to the active shell frontend. The Classic adapter lives in `frontend/classic/hakumenu_rofi.sh`.

### `hakumenu_rofi.sh`
This is the Classic presentation adapter. It launches Rofi and binds the three custom bash scripts to their respective tabs.
- **What it does:** Runs the HakuMenu Rofi mode and defines the custom modes:
  - `General` -> `hm_general.sh`
  - `Theme` -> `hm_theme.sh`
  - `Setting` -> `hm_setting.sh`

## Action Providers

### `hm_general.sh`
This provider supplies shortcuts to frequently used applications and commands.
- **What it does:** By default, it provides quick shortcuts to launch your App Menu, Code Editor, Browser, Screen Recorder, Local Send, File Manager, and the Shutdown menu. It incorporates improved spawn functions to ensure better background process management (removing risky `disown` calls that could orphan tasks).
- **User Customization:** This script is intentionally designed to be overridden! Before loading the default list, it checks if a file named `~/hakucfg/general-menu.sh` exists. If you've created that file, the script validates its syntax and executes it instead. This means you can build your own custom application launcher tab without ever touching the core repository files!

### `hm_theme.sh`
This provider exposes theme and desktop controls and dispatches selections through their public commands. State belongs to the relevant controller; menu presentation does not own it. Read the provider source for the available actions and their labels.

### `hm_setting.sh`
This provider connects system tools and HakuSpace configuration commands.
- **What it does:** It gives you quick access to essential GUI tools like `nm-connection-editor` (Wifi), `blueman-manager` (Bluetooth), `gparted` (Disk Manager), `ncdu` (Storage Manager), and `pavucontrol` (Audio Control).
- **HakuSpace Configs:** It also provides toggles specifically for the Taskbar (App Name, Icon Size), Cava Modes (Color Switch, Dynamic Mode), Rounded Screen Dynamic Mode, and the Opaque Theme Mode. It offers direct shortcuts to open your `~/hakucfg` folder or edit your custom `general-menu.sh` script in VS Code. Like the Theme tab, it reads local configuration variables to dynamically display the current states of these settings.


---
**Previous:** [Utilities](util.md) | **Next:** [Mini-Apps](app.md)
