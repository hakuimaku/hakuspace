#!/bin/bash

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    WALL_STATUS=$(cat "/tmp/random_wallpaper_status" 2>/dev/null || echo "0")
    WALL_TEXT="OFF"
    [[ "$WALL_STATUS" == "1" ]] && WALL_TEXT="ON"

    CAVA_STATUS=$(cat "/tmp/cava_underbar_status" 2>/dev/null || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

    DOCKBAR_STATUS=$(pgrep -x "dockbar" >/dev/null && echo "1" || echo "0")
    DOCKBAR_TEXT="OFF"
    [[ "$DOCKBAR_STATUS" == "1" ]] && DOCKBAR_TEXT="ON"

    cat <<EOF
󰝚  Cava Underbar ($CAVA_TEXT)
  Auto Random Wallpaper ($WALL_TEXT)
󱂩  Toggle Dockbar ($DOCKBAR_TEXT)
󰏜  Change Wallpaper
󱜏  Change Lively Wallpaper
󱛹  Kill Lively Wallpaper
  Switch Waybar Theme
  Switch Rofi Theme
  Change Theme
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Cava Underbar"*) spawn $HOME/.local/bin/cava_manager.sh --toggle ;;
    *"Auto Random Wallpaper"*) spawn $HOME/.local/bin/random_wallpaper.sh --toggle ;;
    *"Toggle Dockbar"*) spawn $HOME/.local/bin/dockbar_manager.sh --toggle ;;
    *"Switch Waybar Theme"*) spawn $HOME/.local/bin/waybar_manager.sh --select ;;
    *"Switch Rofi Theme"*) spawn $HOME/.local/bin/rofi_theme_switcher.sh ;;
    *"Change Wallpaper"*) spawn $HOME/.local/bin/wallpaper_select.sh ;;
    *"Change Lively Wallpaper"*) spawn $HOME/.local/bin/wallpaper_video_select.sh ;;
    *"Kill Lively Wallpaper"*) spawn $HOME/.local/bin/wallpaper_video_select.sh --exit ;;
    *"Change Theme"*) spawn $HOME/.local/bin/change_theme.sh ;;
esac

exit 0