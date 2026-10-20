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
    CAVA_STATUS=$([[ -f /tmp/cava-layer.pid ]] && kill -0 "$(cat /tmp/cava-layer.pid 2>/dev/null)" 2>/dev/null && echo "1" || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

    CAVA_TOP_STATUS=$(cat "$STATE_DIR/cava_top_state" 2>/dev/null || echo "0")
    IS_TOP=""
    [[ "$CAVA_TOP_STATUS" == "1" ]] && IS_TOP="[Top]" || IS_TOP=""

    # Taskbar
    TASKBAR_STATUS=$(cat "$STATE_DIR/taskbar_manual_state" 2>/dev/null || echo "0")
    TASKBAR_TEXT="OFF"
    [[ "$TASKBAR_STATUS" == "1" ]] && TASKBAR_TEXT="ON"

    # Desktop Icons
    DESKTOP_ICONS_STATUS=$(cat "$STATE_DIR/desktop_icons_state" 2>/dev/null || echo "0")
    DESKTOP_ICONS_TEXT="OFF"
    [[ "$DESKTOP_ICONS_STATUS" == "1" ]] && DESKTOP_ICONS_TEXT="ON"

    # Backend switch label follows the active shell mode.
    BACKEND_STATUS=$(cat "$STATE_DIR/shell_backend" 2>/dev/null || echo "classic")
    BACKEND_LABEL="Explore the Abyss"
    [[ "$BACKEND_STATUS" == "hikai" ]] && BACKEND_LABEL="Go back to Surface"

    # Haku Space Mode
    HAKU_LEGACY_STATUS=$(cat "$STATE_DIR/haku_space_state" 2>/dev/null || echo "0")
    HAKU_LEGACY_TEXT="OFF"
    [[ "$HAKU_LEGACY_STATUS" == "1" ]] && HAKU_LEGACY_TEXT="ON"

    cat <<EOF
  Change Theme
󰝚  Cava Underbar ($CAVA_TEXT) $IS_TOP
  Desktop Icons ($DESKTOP_ICONS_TEXT)
󰐃  Taskbar ($TASKBAR_TEXT)
󰤕  Niri Animation
󰏜  Change Wallpaper
󱛹  Kill Lively Wallpaper
  Auto Random Wallpaper ($WALL_TEXT)
󰆧  Haku Legacy Space :) ($HAKU_LEGACY_TEXT)
󰆧  $BACKEND_LABEL
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Change Theme"*) spawn $HOME/.local/bin/change_theme.sh ;;
    *"Go back to Surface"*|*"Explore the Abyss"*) spawn $HOME/.local/bin/haku_backend.sh --toggle ;;
    *"Cava Underbar"*) spawn $HOME/.local/bin/cava_manager.sh ;;
    *"Desktop Icons"*) spawn $HOME/.local/bin/desktop_icons_manager.sh --toggle ;;
    *"Dockbar"*)
        if [[ "$(cat "$STATE_DIR/shell_backend" 2>/dev/null)" == hikai && "$(cat "$STATE_DIR/taskbar_manual_state" 2>/dev/null)" != 1 ]]; then
            spawn "$HOME/.local/bin/dockbar_manager.sh" --toggle
        fi ;;
    *"Taskbar Mode"*|*"Taskbar"*) spawn $HOME/.local/bin/taskbar_manager.sh --toggle ;;
    *"Niri Animation"*) spawn $HOME/.local/bin/niri_animation_switcher.sh ;;
    *"Change Wallpaper"*) spawn $HOME/.local/bin/wallpaper_select.sh ;;
    *"Kill Lively Wallpaper"*) spawn $HOME/.local/bin/wallpaper_select.sh --exit ;;
    *"Haku Legacy Space :)"*) spawn $HOME/.local/bin/haku_space_mode.sh --toggle ;;
    *"Auto Random Wallpaper"*) spawn $HOME/.local/bin/random_wallpaper.sh --toggle ;;
esac

exit 0