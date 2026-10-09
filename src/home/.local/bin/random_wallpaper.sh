#!/usr/bin/env bash

# Include WALL_DIR & WALL_INTERVAL & ACCENT_COLOR_BASED_ON_WALLPAPER
[ -f "$HOME/hakuspace-control/main_setting.sh" ] && source "$HOME/hakuspace-control/main_setting.sh"

# Fallback WALL_DIR and WALL_INTERVAL if not set
WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
WALL_INTERVAL=${WALL_INTERVAL:-300}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}

SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"
source "$HOME/.local/bin/accent_color.sh"

STATE_FILE="/tmp/random_wallpaper_status"

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"

run_wallpaper() {
    while true; do
        for ((i=0; i<WALL_INTERVAL; i++)); do
            [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "0" ]] && exit 0
            echo "$((i))"
            sleep 1
        done

        [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "0" ]] && exit 0

        WALL=$(find "$WALL_DIR" \
            -path "$BACKDROP_DIR" -prune -o \
            -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) \
            -print | shuf -n 1)
        
        if [ -n "$WALL" ]; then
            "$SET_WALLPAPER_SCRIPT" "$WALL"

            if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
                ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL")
                ACCENT="$(accent_color_or_fallback "$ACCENT")"

                "$HOME/.local/bin/gen_style.sh" "$ACCENT" && \
                    "$HOME/.local/bin/apply_style.sh"
            fi
        fi
    done
}

toggle_wallpaper() {
    if [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "1" ]]; then
        echo "0" > "$STATE_FILE"
        [[ -x $(command -v notify-send) ]] && notify-send "Wallpaper Automation" "Turned OFF"
    else
        echo "1" > "$STATE_FILE"
        [[ -x $(command -v notify-send) ]] && notify-send "Wallpaper Automation" "Turned ON"
        run_wallpaper &
    fi
}

toggle_wallpaper