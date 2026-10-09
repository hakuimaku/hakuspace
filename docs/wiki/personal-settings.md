# Personal settings

Personal changes should be placed in `~/hakucfg`. This is the user customization area provided by HakuSpace.

## Common settings

- `~/hakucfg/setting.sh`: wallpaper and video folders, screenshot and recording locations, wallpaper interval, and accent colors.
- `~/hakucfg/config/dockbar_pin_apps`: applications pinned to Dockbar.
- `~/hakucfg/config/waybar/`: custom Waybar layouts.
- `~/hakucfg/config/rofi/`: custom Rofi themes.
- `~/hakucfg/general-menu.sh`: applications shown in General Menu.
- `~/hakucfg/config/hypridle.conf`: idle timeouts.
- `~/hakucfg/wm/hyprland-custom.lua`: Hyprland customizations.
- `~/hakucfg/wm/niri-custom.kdl`: Niri customizations.
- `~/hakucfg/wm/mango-custom.conf`: MangoWM customizations.

## Customizing `setting.sh`

Open `~/hakucfg/setting.sh` in a text editor and change only the values you need. Common options include:

| Variable | Purpose |
|---|---|
| `SCREENSHOT_DIR` | Folder for screenshots made by the HakuSpace script. |
| `WALL_DIR` | Folder containing static wallpapers. |
| `WALL_MPV_DIR` | Folder containing video wallpapers. |
| `WALL_INTERVAL` | Automatic wallpaper interval in seconds. |
| `ACCENT_COLOR_BASED_ON_WALLPAPER` | Enable or disable wallpaper-based accent colors. |
| `ACCENT_COLOR_MODE` | Choose `vivid`, `dominant`, `brightest`, or `saturated`. |
| `SCREENREC_SAVE_DIR` | Folder for screen recordings. |
| `REC_OPTS` | Options passed to the screen recorder. |
| `WAYBAR_MODE_USER` | Names of custom Waybar layouts. |
| `HAKU_CLOCK_FONT_SIZE` | Clock size used by Haku scripts. |
| `HAKU_GENERAL_FONT_SIZE` | General Haku script font size. |
| `HAKU_TERMINAL_FONT_SIZE` | Terminal Haku script font size. |
| `RAM_THRESHOLD_MB` | RAM warning threshold during exit. |
| `EXIT_APP_LIST_USER` | Applications to close gracefully when exiting. |

For a custom Waybar layout, create matching `config` and `style.css` files in `~/hakucfg/config/waybar/<name>/`, then add `<name>` to `WAYBAR_MODE_USER`.

For a custom Rofi theme, place a `.rasi` file in `~/hakucfg/config/rofi/`; it will be available in the Rofi theme switcher.

## Applying changes

Use the relevant Haku Menu action after editing. For example, switch Waybar mode after adding a Waybar layout, or reopen the Rofi theme switcher after adding a Rofi theme. Restart the related component or log out and back in if a change is not visible.

You do not need to edit files in `~/.config` when an equivalent option exists in `~/hakucfg`.
