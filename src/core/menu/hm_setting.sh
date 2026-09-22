#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

if [[ $# -eq 0 ]]; then
    DOCK_APP_NAME="OFF"
    if grep -qE '"format":\s*"\{icon\} \{name\}"' $HOME/.local/state/hakuspace/taskbar-theme 2>/dev/null; then
        DOCK_APP_NAME="ON"
    fi

    DOCK_ICON_SIZE=$(grep -oP '"icon-size":\s*\K\d+' $HOME/.local/state/hakuspace/taskbar-theme 2>/dev/null)
    DOCK_ICON_SIZE_TEXT="$DOCK_ICON_SIZE"
    DOCK_ICON_SIZE_TEXT+="px"

    cat <<INNEREOF
󱂩  Taskbar App Name ($DOCK_APP_NAME)
󱂩  Taskbar Icon Size Change ($DOCK_ICON_SIZE_TEXT)
󱁤  Settings Folder
󱁤  HakuMenu General Tab
󰖩  Wifi
󰂯  Bluetooth
󰋊  Disk Manager
󰃢  Storage Manager
  Audio Control
INNEREOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Taskbar App Name"*) spawn $HOME/.local/bin/taskbar_manager.sh --app-name ;;
    *"Taskbar Icon Size Change"*) spawn $HOME/.local/bin/taskbar_manager.sh --icon-size ;;
    *"Settings Folder"*) spawn xdg-open "$HOME/hakucfg" ;;
    *"HakuMenu General Tab"*) spawn code $HOME/hakucfg/general-menu.sh ;;
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
esac

exit 0
