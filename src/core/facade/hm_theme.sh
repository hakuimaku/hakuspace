#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_theme.sh" || exit 1

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

    # Backend status is also used below to gate Hikai-only theme actions.
    BACKEND_STATUS=$(cat "$(haku_state_path shell.backend)" 2>/dev/null || echo "classic")

    cat <<EOF
  Change Theme
󰝚  Cava Underbar ($CAVA_TEXT)
EOF
    if [[ "$BACKEND_STATUS" == "hikai" ]]; then
        printf '󰝚  Cava Color Mode (%s)\n' "$IS_COLOR"
        printf '󰐃  Taskbar (%s)\n' "$TASKBAR_TEXT"
    fi
    cat <<EOF
  Desktop Icons ($DESKTOP_ICONS_TEXT)
󰤕  Niri Animation
󰏜  Change Wallpaper
󱛹  Kill Lively Wallpaper
  Auto Random Wallpaper ($WALL_TEXT)
󰆧  Shell Backend
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Change Theme"*) spawn "$HAKU_BIN_DIR/change_theme.sh" ;;
    *"Shell Backend"*) spawn "$HAKU_BIN_DIR/backend_switcher.sh" ;;
    *"Cava Dynamic Position"*|*"Cava Dynamic"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" --toggle-dynamic ;;
    *"Cava Position"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" --position ;;
    *"Cava Color Mode"*|*"Cava Color Switch"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" --color-switch ;;
    *"Cava Underbar"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" ;;
    *"Desktop Icons"*) spawn "$HAKU_BIN_DIR/desktop_icons_manager.sh" --toggle ;;
    *"Dockbar"*)
        if [[ "$(cat "$(haku_state_path shell.backend)" 2>/dev/null)" == hikai && "$(cat "$(haku_state_path desktop.taskbar.requested)" 2>/dev/null)" != 1 ]]; then
            spawn "$HAKU_BIN_DIR/dockbar_manager.sh" --toggle
        fi ;;
    *"Taskbar Mode"*|*"Taskbar"*)
        if [[ "$(cat "$(haku_state_path shell.backend)" 2>/dev/null)" == hikai ]]; then
            spawn "$HAKU_BIN_DIR/taskbar_manager.sh" --toggle
        fi ;;
    *"Niri Animation"*) spawn "$HAKU_BIN_DIR/niri_animation_switcher.sh" ;;
    *"Change Wallpaper"*) spawn "$HAKU_BIN_DIR/wallpaper_select.sh" ;;
    *"Kill Lively Wallpaper"*) spawn "$HAKU_BIN_DIR/wallpaper_select.sh" --exit ;;
    *"Auto Random Wallpaper"*) spawn "$HAKU_BIN_DIR/random_wallpaper.sh" --toggle ;;
esac

exit 0