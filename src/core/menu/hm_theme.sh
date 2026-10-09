#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

if [[ $# -eq 0 ]]; then
    WALL_STATUS=$(cat "/tmp/random_wallpaper_status" 2>/dev/null || echo "0")
    WALL_TEXT="OFF"
    [[ "$WALL_STATUS" == "1" ]] && WALL_TEXT="ON"

    # Check if Cava is running by checking the PID file
    CAVA_STATUS=$([[ -f /tmp/cava-layer.pid ]] && echo "1" || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

    TASKBAR_STATUS=$(cat "$STATE_DIR/taskbar_manual_state" 2>/dev/null || echo "0")
    TASKBAR_TEXT="OFF"
    [[ "$TASKBAR_STATUS" == "1" ]] && TASKBAR_TEXT="ON"

    DESKTOP_ICONS_STATUS=$(cat "$STATE_DIR/desktop_icons_state" 2>/dev/null || echo "0")
    DESKTOP_ICONS_TEXT="OFF"
    [[ "$DESKTOP_ICONS_STATUS" == "1" ]] && DESKTOP_ICONS_TEXT="ON"

    cat <<EOF
  Change Theme
󰝚  Cava Underbar ($CAVA_TEXT)
  Auto Random Wallpaper ($WALL_TEXT)
󱂩  Toggle Taskbar ($TASKBAR_TEXT)
  Show Desktop Icons ($DESKTOP_ICONS_TEXT)
󰏜  Change Wallpaper
󱜏  Change Lively Wallpaper
󱛹  Kill Lively Wallpaper
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Change Theme"*) spawn $HOME/.local/bin/change_theme.sh ;;
    *"Cava Underbar"*) spawn $HOME/.local/bin/cava_manager.sh ;;
    *"Auto Random Wallpaper"*) spawn $HOME/.local/bin/random_wallpaper.sh --toggle ;;
    *"Toggle Taskbar"*) spawn $HOME/.local/bin/taskbar_manager.sh --toggle ;;
    *"Show Desktop Icons"*) spawn $HOME/.local/bin/desktop_icons_manager.sh --toggle ;;
    *"Change Wallpaper"*) spawn $HOME/.local/bin/wallpaper_select.sh ;;
    *"Change Lively Wallpaper"*) spawn $HOME/.local/bin/wallpaper_video_select.sh ;;
    *"Kill Lively Wallpaper"*) spawn $HOME/.local/bin/wallpaper_video_select.sh --exit ;;
esac

exit 0