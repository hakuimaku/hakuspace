#!/bin/bash

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    cat <<'EOF'
󰖩  Wifi
󰂯  Bluetooth
  Disk Manager
󰋊  Storage Manager
󰓃  Audio Control
󱂩  Dockbar Exclusive Mode Toggle
󱂩  Dockbar Icon Size Change
󱁤  Open Overall Configuration
  HakuMenu General Tab
  HakuMenu Theme Tab
  HakuMenu Setting Tab
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
    *"Dockbar Exclusive Mode Toggle"*) spawn $HOME/.local/bin/dockbar_manager.sh --exclusive ;;
    *"Dockbar Icon Size Change"*) spawn $HOME/.local/bin/dockbar_manager.sh --icon-size ;;
    *"Open Overall Configuration"*) spawn $HOME/.local/bin/open_config.sh ;;
    *"HakuMenu General Tab"*) spawn code $HOME/.local/bin/hm_general.sh ;;
    *"HakuMenu Theme Tab"*) spawn code $HOME/.local/bin/hm_theme.sh ;;
    *"HakuMenu Setting Tab"*) spawn code $HOME/.local/bin/hm_setting.sh ;;
esac

exit 0