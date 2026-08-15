#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    DOCK_STATUS=$(cat "$HOME/.local/state/haku_theme/dockbar_autohide_state" 2>/dev/null || echo "0")
    DOCK_TEXT="OFF"
    [[ "$DOCK_STATUS" == "1" ]] && DOCK_TEXT="ON"

    DOCK_EXCLUSIVE=$(grep -oP '"exclusive":\s*\K(true|false)' ~/.config/waybar/dockbar/config 2>/dev/null)
    DOCK_EXCLUSIVE_TEXT="OFF"
    [[ "$DOCK_EXCLUSIVE" == "true" ]] && DOCK_EXCLUSIVE_TEXT="ON"

    DOCK_ICON_SIZE=$(grep -oP '"icon-size":\s*\K\d+' ~/.config/waybar/dockbar/config 2>/dev/null)
    DOCK_ICON_SIZE_TEXT="$DOCK_ICON_SIZE"
    DOCK_ICON_SIZE_TEXT+="px"

    cat <<EOF
󱂩  Dockbar Auto-hide Toggle ($DOCK_TEXT)
󱂩  Dockbar Exclusive Toggle ($DOCK_EXCLUSIVE_TEXT)
󱂩  Dockbar Icon Size Change ($DOCK_ICON_SIZE_TEXT)
󱁤  Open Settings Folder
󱁤  Open Config Menu General Tab
󰖩  Wifi
󰂯  Bluetooth
󰋊  Disk Manager
󰃢  Storage Manager
  Audio Control
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Dockbar Auto-hide Toggle"*) spawn $HOME/.local/bin/dockbar_manager.sh --auto-hide ;;
    *"Dockbar Exclusive Toggle"*) spawn $HOME/.local/bin/dockbar_manager.sh --exclusive ;;
    *"Dockbar Icon Size Change"*) spawn $HOME/.local/bin/dockbar_manager.sh --icon-size ;;
    *"Open Settings Folder"*) spawn thunar "$HOME/hakuspace-control" ;;
    *"Open Config Menu General Tab"*) spawn code $HOME/hakuspace-control/hakumenu-general-custom.sh ;;
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
esac

exit 0