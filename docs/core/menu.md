# The Haku Menu (src/core/menu)

If you've ever pressed the keybind for the "Haku Menu" (usually `SUPER + TAB`), you've seen the multi-tabbed, customizable Rofi interface that serves as the central command hub for your desktop. 

The scripts that power this menu are located in `src/core/menu/`. Instead of a monolithic, hard-to-edit configuration, the Haku Menu is modular. It uses Rofi's custom script mode (`-modes`) to separate the menu into three distinct tabs: **General**, **Theme**, and **Setting**.

Here is a detailed breakdown of how the menu is built:

## The Main Hub

### `hakumenu.sh`
This is the entry-point script. It doesn't actually contain any of the menu items; it simply launches Rofi and binds the three custom bash scripts to their respective tabs.
- **What it does:** Runs `rofi -show "General"` and defines the custom modes: 
  - `General` -> `hm_general.sh`
  - `Theme` -> `hm_theme.sh`
  - `Setting` -> `hm_setting.sh`

## The Tabs

### `hm_general.sh` (The General Tab)
This tab is meant for your daily drivers and frequently used applications.
- **What it does:** By default, it provides quick shortcuts to launch your App Menu, Code Editor, Browser, Screen Recorder, Local Send, File Manager, and the Shutdown menu. It incorporates improved spawn functions to ensure better background process management (removing risky `disown` calls that could orphan tasks).
- **User Customization:** This script is intentionally designed to be overridden! Before loading the default list, it checks if a file named `~/hakucfg/general-menu.sh` exists. If you've created that file, the script validates its syntax and executes it instead. This means you can build your own custom application launcher tab without ever touching the core repository files!

### `hm_theme.sh` (The Theme Tab)
This is your control panel for aesthetics and desktop widgets.
- **What it does:** It provides a list of interactive toggles for HakuSpace's unique visual features. You can change your wallpaper, toggle the Cava Underbar, enable Auto Random Wallpapers, toggle the Taskbar, or show/hide Desktop Icons.
- **Dynamic State:** Notice how some options say `(ON)` or `(OFF)`? The script achieves this by reading local state files (like `/tmp/cava-layer.pid` or `/tmp/random_wallpaper_status`) before rendering the menu. When you click an option, it spawns the corresponding manager script in the background to execute your command.

### `hm_setting.sh` (The Setting Tab)
This tab acts as a bridge to both your system hardware settings and HakuSpace's internal configurations.
- **What it does:** It gives you quick access to essential GUI tools like `nm-connection-editor` (Wifi), `blueman-manager` (Bluetooth), `gparted` (Disk Manager), `ncdu` (Storage Manager), and `pavucontrol` (Audio Control).
- **HakuSpace Configs:** It also provides toggles specifically for the Taskbar (App Name, Icon Size), Cava Modes (Color Switch, Dynamic Mode), Rounded Screen Dynamic Mode, and the Opaque Theme Mode. It offers direct shortcuts to open your `~/hakucfg` folder or edit your custom `general-menu.sh` script in VS Code. Like the Theme tab, it reads local configuration variables to dynamically display the current states of these settings.


---
**Previous:** [Utilities](util.md) | **Next:** [Mini-Apps](app.md)
