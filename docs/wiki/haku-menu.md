# Haku Menu

Haku Menu is the central menu for launching applications and toggling desktop features.

## Opening the menu

Press `SUPER + TAB` (`Mod + TAB` on Niri). The menu has three groups: `General`, `Theme`, and `Setting`. Use the mouse or arrow keys to choose an item.

## General

- `App Menu`: open the application launcher.
- `Code Editor`: open VS Code.
- `Browser`: open Firefox.
- `Screen Record`: start or stop screen recording.
- `Local Send`: open LocalSend for sending files over the local network.
- `File Manager`: open Thunar.
- `Quit`: open options to lock, log out, restart, or shut down.

## Theme

Use this group to change the active desktop appearance:

- Toggle Cava Underbar.
- Toggle automatic wallpaper changes.
- Toggle Dockbar and Desktop Icons.
- Choose a static or video wallpaper.
- Change the Waybar layout and Rofi theme.
- Change the font, font size, and accent color.

## Setting

This group contains system tools and Dockbar controls:

- Toggle Dockbar auto-hide.
- Toggle Dockbar exclusive mode.
- Change the Dockbar icon size.
- Open the personal settings folder at `~/hakucfg`.
- Open the Wi-Fi, Bluetooth, disk, storage, and audio managers.

## Customizing Haku Menu

### General tab

Edit `~/hakucfg/general-menu.sh` to add, remove, or rename General menu items.

1. Add the exact label to the output block near the top of the file.
2. Add a matching pattern to the `case` block below it.
3. Use `spawn` before the command so the menu can close while the application starts.

Example:

```bash
My App
```

```bash
*"My App"*) spawn my-app ;;
```

The text in the output block and the text matched in the `case` block must correspond. Reopen Haku Menu after saving the file.

### Theme and Setting tabs

The Theme and Setting tabs use the built-in HakuSpace scripts. Customize their values through `~/hakucfg/setting.sh` where an option is available. For example, wallpaper folders, recording locations, Waybar user modes, and font sizes are configured there.

The menu itself is launched by `~/.local/bin/hakumenu.sh`. Advanced users can change the Rofi prompt or tab names there, but updates may replace that deployed file.
