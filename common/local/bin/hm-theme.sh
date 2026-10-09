#!/bin/bash
set -euo pipefail
spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    WALL_STATUS=$(cat "/tmp/random_wallpaper_status" 2>/dev/null || echo "0")
    WALL_TEXT="OFF"
    [[ "$WALL_STATUS" == "1" ]] && WALL_TEXT="ON"

    CAVA_STATUS=$(cat "/tmp/cava_underbar_status" 2>/dev/null || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

  cat <<EOF
  Cava Underbar ($CAVA_TEXT)
󰁪  Auto Random Wallpaper ($WALL_TEXT)
󰸉  Change Wallpaper
  Change Lively Wallpaper
󰃾  Kill Lively Wallpaper
  Waybar Left & Top Toggle
  Change Theme (Font/Size/Color)
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Cava Underbar"*) spawn ~/.local/bin/cava_manager.sh --toggle ;;
    *"Auto Random Wallpaper"*) spawn ~/.local/bin/random_wallpaper.sh --toggle ;;
    *"Change Wallpaper"*) spawn ~/.local/bin/wallselect.sh ;;
    *"Change Lively Wallpaper"*) spawn ~/.local/bin/wallmpvselect.sh ;;
    *"Kill Lively Wallpaper"*) spawn ~/.local/bin/wallmpvselect.sh --exit ;;
    *"Waybar Left & Top Toggle"*) spawn ~/.local/bin/waybar_toggle.sh ;;
    *"Change Theme"*) spawn ~/.local/bin/changetheme.sh ;;
esac

exit 0