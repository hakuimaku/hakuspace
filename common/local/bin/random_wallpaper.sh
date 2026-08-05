#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=300

SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"

STATE_FILE="/tmp/random_wallpaper_status"

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"

run_wallpaper() {
    while true; do
        for ((i=0; i<INTERVAL; i++)); do
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

            ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL")
            [[ -z "$ACCENT" ]] && ACCENT="#ffffff"

            r=$(printf "%d" 0x${ACCENT:1:2})
            g=$(printf "%d" 0x${ACCENT:3:2})
            b=$(printf "%d" 0x${ACCENT:5:2})
            [[ $((r + g + b)) -lt 180 ]] && ACCENT="#ffffff"

            "$HOME/.local/bin/gen_style.sh" "$ACCENT"
            sleep 0.2
            "$HOME/.local/bin/apply_style.sh"
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