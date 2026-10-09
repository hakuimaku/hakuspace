#!/bin/bash
set -euo pipefail
spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    cat <<'EOF'
󰖩  Wifi
󰂯  Bluetooth
  Disk Manager
󰋊  Storage Manager
󰓃  Audio Control
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
    *"HakuMenu General Tab"*) spawn code ~/.local/bin/hm-general.sh ;;
    *"HakuMenu Theme Tab"*) spawn code ~/.local/bin/hm-theme.sh ;;
    *"HakuMenu Setting Tab"*) spawn code ~/.local/bin/hm-setting.sh ;;
esac

exit 0