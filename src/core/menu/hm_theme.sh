#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

if [[ $# -eq 0 ]]; then
    # Random Wallpaper
    WALL_STATUS=$(cat "/tmp/random_wallpaper_status" 2>/dev/null || echo "0")
    WALL_TEXT="OFF"
    [[ "$WALL_STATUS" == "1" ]] && WALL_TEXT="ON"

    # Cava Layer
    CAVA_STATUS=$([[ -f /tmp/cava-layer.pid ]] && echo "1" || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

    CAVA_TOP_STATUS=$(cat "$STATE_DIR/cava_top_state" 2>/dev/null || echo "0")
    IS_TOP=""
    [[ "$CAVA_TOP_STATUS" == "1" ]] && IS_TOP="[Top]" || IS_TOP=""

    # Taskbar
    TASKBAR_STATUS=$(cat "$STATE_DIR/taskbar_manual_state" 2>/dev/null || echo "0")
    TASKBAR_TEXT="OFF"
    [[ "$TASKBAR_STATUS" == "1" ]] && TASKBAR_TEXT="ON"

    # Waybar
    WAYBAR_STATUS=$(cat "$STATE_DIR/waybar_manual_state" 2>/dev/null || echo "0")
    WAYBAR_TEXT="OFF"
    [[ "$WAYBAR_STATUS" == "1" ]] && WAYBAR_TEXT="ON"

    # Desktop Icons
    DESKTOP_ICONS_STATUS=$(cat "$STATE_DIR/desktop_icons_state" 2>/dev/null || echo "0")
    DESKTOP_ICONS_TEXT="OFF"
    [[ "$DESKTOP_ICONS_STATUS" == "1" ]] && DESKTOP_ICONS_TEXT="ON"

    # Rounded Screen
    ROUNDED_SCREEN_STATUS=$(cat "$STATE_DIR/rounded_screen_state" 2>/dev/null || echo "0")
    ROUNDED_SCREEN_TEXT="OFF"
    [[ "$ROUNDED_SCREEN_STATUS" == "1" ]] && ROUNDED_SCREEN_TEXT="ON"

    # Edge Trigger
    EDGE_TRIGGER_STATUS=$(cat "$STATE_DIR/edge_trigger_state" 2>/dev/null || echo "0")
    EDGE_TRIGGER_TEXT="OFF"
    [[ "$EDGE_TRIGGER_STATUS" == "1" ]] && EDGE_TRIGGER_TEXT="ON"

    cat <<EOF
  Change Theme
  Desktop ($DESKTOP_ICONS_TEXT)
󰅹  Waybar ($WAYBAR_TEXT)
󰐃  Taskbar ($TASKBAR_TEXT)
  Rounded Screen ($ROUNDED_SCREEN_TEXT)
  Edge Trigger ($EDGE_TRIGGER_TEXT)
󰝚  Cava Underbar ($CAVA_TEXT) $IS_TOP
  Auto Random Wallpaper ($WALL_TEXT)
󰏜  Change Wallpaper
󱜏  Change Lively Wallpaper
󱛹  Kill Lively Wallpaper
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Change Theme"*) spawn $HOME/.local/bin/change_theme.sh ;;
    *"Desktop"*) spawn $HOME/.local/bin/desktop_icons_manager.sh --toggle ;;
    *"Waybar"*) spawn $HOME/.local/bin/waybar_manager.sh --toggle ;;
    *"Taskbar"*) spawn $HOME/.local/bin/taskbar_manager.sh --toggle ;;
    *"Rounded Screen"*) spawn $HOME/.local/bin/rounded_screen_manager.sh --toggle ;;
    *"Edge Trigger"*) spawn $HOME/.local/bin/edge_trigger_manager.sh --toggle ;;
    *"Cava Underbar"*) spawn $HOME/.local/bin/cava_manager.sh ;;
    *"Auto Random Wallpaper"*) spawn $HOME/.local/bin/random_wallpaper.sh --toggle ;;
    *"Change Wallpaper"*) spawn $HOME/.local/bin/wallpaper_select.sh ;;

esac

exit 0