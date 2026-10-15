# The Haku Menu (src/core/menu)

If you've ever pressed the keybind for the "Haku Menu" (usually `SUPER + TAB`), you've seen the central command hub for your desktop. Classic presents it through Rofi, while Hikai provides a native Quickshell HakuMenu with **General**, **Drun**, and **Theme** tabs.

The scripts that power the shared menu actions are located in `src/core/menu/`. Classic uses Rofi script modes; Hikai reuses the same action/provider contracts where appropriate and renders its own native rows and state controls.

Here is a detailed breakdown of how the menu is built:

## The Main Hub

### `hakumenu.sh`
This is the stable public entry-point script. It is now a UI-free routing wrapper that delegates the Classic presentation to `frontend/classic/hakumenu_rofi.sh` while preserving the deployed `hakumenu.sh` basename used by keybinds and Waybar.

### `hakumenu_rofi.sh`
This is the Classic presentation adapter. It launches Rofi and binds the three custom bash scripts to their respective tabs.
- **What it does:** Runs the HakuMenu Rofi mode and defines the custom modes:
  - `General` -> `hm_general.sh`
  - `Theme` -> `hm_theme.sh`
  - `Setting` -> `hm_setting.sh`

## The Tabs

### `hm_general.sh` (The General Tab)
This tab is meant for your daily drivers and frequently used applications.
- **What it does:** By default, it provides quick shortcuts to launch your App Menu, Code Editor, Browser, Screen Recorder, Local Send, File Manager, and the Shutdown menu. It incorporates improved spawn functions to ensure better background process management (removing risky `disown` calls that could orphan tasks).
- **User Customization:** This script is intentionally designed to be overridden! Before loading the default list, it checks if a file named `~/hakucfg/general-menu.sh` exists. If you've created that file, the script validates its syntax and executes it instead. This means you can build your own custom application launcher tab without ever touching the core repository files!

### `hm_theme.sh` (The Theme Tab)
This is the shared action provider/control panel for aesthetics and desktop widgets.
- **Current actions:** Change Theme, Cava Underbar, Desktop Icons, Taskbar, Niri Animation, Change Wallpaper, Kill Lively Wallpaper, Auto Random Wallpaper, and the shell-backend switch. The backend switch is always the final row: Hikai shows **Go back to Surface**, while Classic shows **Explore the Abyss**.
- **Classic state rendering:** Classic keeps inline `(ON)` / `(OFF)` text for Cava Underbar, Desktop Icons, Taskbar, and Auto Random Wallpaper.
- **Hikai state rendering:** Native HakuMenu renders those four stateful rows with the Theme-tab state pill. Cava Underbar, Desktop Icons, and Taskbar are direct toggles and keep HakuMenu open. The backend switch intentionally has **no state pill** even though it toggles the active backend.
- **State sources:** Cava uses `~/.local/state/hakuspace/state/cava_layer_state`, Desktop Icons uses `state/desktop_icons_state`, Taskbar uses `state/taskbar_manual_state`, and Auto Random Wallpaper uses `/tmp/random_wallpaper_status`.

### `hm_setting.sh` (The Setting Tab)
This tab acts as a bridge to both your system hardware settings and HakuSpace's internal configurations.
- **What it does:** It gives you quick access to essential GUI tools like `nm-connection-editor` (Wifi), `blueman-manager` (Bluetooth), `gparted` (Disk Manager), `ncdu` (Storage Manager), and `pavucontrol` (Audio Control).
- **HakuSpace Configs:** It also provides toggles specifically for the Taskbar (App Name, Icon Size), Cava Modes (Color Switch, Dynamic Mode), Rounded Screen Dynamic Mode, and the Opaque Theme Mode. It offers direct shortcuts to open your `~/hakucfg` folder or edit your custom `general-menu.sh` script in VS Code. Like the Theme tab, it reads local configuration variables to dynamically display the current states of these settings.


---
**Previous:** [Utilities](util.md) | **Next:** [Mini-Apps](app.md)
