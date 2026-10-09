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

    CAVA_TOP_STATUS=$(cat "$STATE_DIR/cava_top_state" 2>/dev/null || echo "0")
    IS_TOP=""
    [[ "$CAVA_TOP_STATUS" == "1" ]] && IS_TOP="(ON)" || IS_TOP="(OFF)"

    CAVA_COLOR_STATUS=$(cat "$STATE_DIR/cava_color_state" 2>/dev/null || echo "1")
    IS_COLOR=""
    [[ "$CAVA_COLOR_STATUS" == "1" ]] && IS_COLOR="(Accent)" || IS_COLOR="(Black)"

    cat <<INNEREOF
󱂩  Taskbar App Name ($DOCK_APP_NAME)
󱂩  Taskbar Icon Size Change ($DOCK_ICON_SIZE_TEXT)
󰝚  Cava Top Toggle $IS_TOP
󰝚  Cava Color Switch $IS_COLOR
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
    *"Cava Top Toggle"*) spawn $HOME/.local/bin/cava_manager.sh --top ;;
    *"Cava Color Switch"*) spawn $HOME/.local/bin/cava_manager.sh --color-switch ;;
    *"Settings Folder"*) spawn xdg-open "$HOME/hakucfg" ;;
    *"HakuMenu General Tab"*) spawn code $HOME/hakucfg/general-menu.sh ;;
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
esac

exit 0
