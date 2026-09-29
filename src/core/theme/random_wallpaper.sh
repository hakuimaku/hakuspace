#!/usr/bin/env bash

# Include WALL_DIR & WALL_MPV_DIR & WALL_INTERVAL & ACCENT_COLOR_BASED_ON_WALLPAPER
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

# Fallback WALL_DIR and WALL_INTERVAL if not set
WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
WALL_MPV_DIR=${WALL_MPV_DIR:-$HOME/Videos/Wallpapers}
WALL_INTERVAL=${WALL_INTERVAL:-300}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}
ACCENT_COLOR_MODE=${ACCENT_COLOR_MODE:-vivid}

PREVIEW_DIR="$WALL_MPV_DIR/.thumbnails"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"
source "$SCRIPT_DIR/accent_color.sh"

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

        if pgrep "mpvpaper" > /dev/null; then
            WALL=$(find "$WALL_MPV_DIR" -type f -iname "*.mp4" -print | shuf -n 1)
            IS_LIVELY=true
        else
            WALL=$(find "$WALL_DIR" \
                -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) \
                -print | shuf -n 1)
            IS_LIVELY=false
        fi
        
        if [ -n "$WALL" ]; then
            "$SET_WALLPAPER_SCRIPT" "$WALL"

            if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
                if [ "$IS_LIVELY" = true ]; then
                    filename=$(basename "${WALL%.*}")
                    preview=""
                    if [[ -f "$PREVIEW_DIR/$filename.gif" ]]; then
                        preview="$PREVIEW_DIR/$filename.gif"
                    elif [[ -f "$PREVIEW_DIR/$filename.jpg" ]]; then
                        preview="$PREVIEW_DIR/$filename.jpg"
                    elif [[ -f "$PREVIEW_DIR/$filename.png" ]]; then
                        preview="$PREVIEW_DIR/$filename.png"
                    fi

                    if [[ -n "$preview" ]]; then
                        ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$preview" "$ACCENT_COLOR_MODE")
                    else
                        ACCENT="#ffffff"
                    fi
                else
                    ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL" "$ACCENT_COLOR_MODE")
                fi
                
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