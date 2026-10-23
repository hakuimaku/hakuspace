#!/usr/bin/env bash

# Include wallpaper directories and interval
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

# Fallback WALL_DIR and WALL_INTERVAL if not set
WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
WALL_MPV_DIR=${WALL_MPV_DIR:-$HOME/Videos/Wallpapers}
WALL_INTERVAL=${WALL_INTERVAL:-300}
WALLPAPER_CTL="$HOME/.local/bin/wallpaper_ctl.sh"

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

        # Native Hikai selection comes from canonical state; Classic retains process detection.
        if [[ $(cat "$HOME/.local/state/hakuspace/state/[shell].backend" 2>/dev/null) == hikai ]]; then
            IS_LIVELY=$("$WALLPAPER_CTL" current --json | python3 -c 'import json,sys; print("true" if json.load(sys.stdin).get("kind") == "video" else "false")')
        elif pgrep "mpvpaper" > /dev/null; then
            IS_LIVELY=true
        else
            IS_LIVELY=false
        fi

        if [[ "$IS_LIVELY" == true ]]; then
            WALL=$(find "$WALL_MPV_DIR" -type f -iname "*.mp4" -print | shuf -n 1)
            IS_LIVELY=true
        else
            WALL=$(find "$WALL_DIR" \
                -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) \
                -print | shuf -n 1)
            IS_LIVELY=false
        fi
        
        if [ -n "$WALL" ]; then
            if [[ "$IS_LIVELY" == true ]]; then
                "$WALLPAPER_CTL" apply-lively "$WALL"
            else
                "$WALLPAPER_CTL" apply-static "$WALL"
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
