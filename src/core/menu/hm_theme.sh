#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/haku_theme.sh"
elif [[ -f "$SCRIPT_DIR/../lib/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/../lib/haku_theme.sh"
elif [[ -f "$HOME/.local/bin/haku_theme.sh" ]]; then
    source "$HOME/.local/bin/haku_theme.sh"
fi

if [[ $# -eq 0 ]]; then
    # Random Wallpaper
    WALL_STATUS=$(cat "/tmp/random_wallpaper_status" 2>/dev/null || echo "0")
    WALL_TEXT="OFF"
    [[ "$WALL_STATUS" == "1" ]] && WALL_TEXT="ON"

    # Cava Layer
    CAVA_STATUS=$([[ -f /tmp/cava-layer.pid ]] && kill -0 "$(cat /tmp/cava-layer.pid 2>/dev/null)" 2>/dev/null && echo "1" || echo "0")
    CAVA_TEXT="OFF"
    [[ "$CAVA_STATUS" == "1" ]] && CAVA_TEXT="ON"

    CAVA_COLOR_STATUS=$(cat "$(haku_state_path cava.color-mode)" 2>/dev/null || echo "1")
    IS_COLOR=""
    [[ "$CAVA_COLOR_STATUS" == "0" || "$CAVA_COLOR_STATUS" == "surface" || "$CAVA_COLOR_STATUS" == "black" ]] && IS_COLOR="Surface" || IS_COLOR="Accent"

    # Taskbar
    TASKBAR_STATUS=$(cat "$(haku_state_path desktop.taskbar.requested)" 2>/dev/null || echo "0")
    TASKBAR_TEXT="OFF"
    [[ "$TASKBAR_STATUS" == "1" ]] && TASKBAR_TEXT="ON"

    # Desktop Icons
    DESKTOP_ICONS_STATUS=$(cat "$(haku_state_path desktop.icons.enabled)" 2>/dev/null || echo "0")
    DESKTOP_ICONS_TEXT="OFF"
    [[ "$DESKTOP_ICONS_STATUS" == "1" ]] && DESKTOP_ICONS_TEXT="ON"

    # Backend switch label follows the active shell mode.
    BACKEND_STATUS=$(cat "$(haku_state_path shell.backend)" 2>/dev/null || echo "classic")
    BACKEND_LABEL="Explore the Abyss"
    [[ "$BACKEND_STATUS" == "hikai" ]] && BACKEND_LABEL="Go back to Surface"

    # Haku Space Mode
    HAKU_LEGACY_STATUS=$(cat "$(haku_state_path shell.haku-space.enabled)" 2>/dev/null || echo "0")
    HAKU_LEGACY_TEXT="OFF"
    [[ "$HAKU_LEGACY_STATUS" == "1" ]] && HAKU_LEGACY_TEXT="ON"

    cat <<EOF
  Change Theme
󰝚  Cava Underbar ($CAVA_TEXT)
󰝚  Cava Color Mode ($IS_COLOR)
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
    *"Cava Dynamic Position"*|*"Cava Dynamic"*) spawn $HOME/.local/bin/cava_manager.sh --toggle-dynamic ;;
    *"Cava Position"*) spawn $HOME/.local/bin/cava_manager.sh --position ;;
    *"Cava Color Mode"*|*"Cava Color Switch"*) spawn $HOME/.local/bin/cava_manager.sh --color-switch ;;
    *"Cava Underbar"*) spawn $HOME/.local/bin/cava_manager.sh ;;
    *"Desktop Icons"*) spawn $HOME/.local/bin/desktop_icons_manager.sh --toggle ;;
    *"Dockbar"*)
        if [[ "$(cat "$(haku_state_path shell.backend)" 2>/dev/null)" == hikai && "$(cat "$(haku_state_path desktop.taskbar.requested)" 2>/dev/null)" != 1 ]]; then
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