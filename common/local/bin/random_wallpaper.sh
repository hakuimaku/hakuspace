#!/bin/bash

WALL_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=300
STATE_FILE="/tmp/random_wallpaper_status"

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"

run_wallpaper() {
    if ! pgrep -x "awww-daemon" > /dev/null; then
        awww-daemon &
        sleep 1
    fi

    while true; do
        for ((i=0; i<INTERVAL; i++)); do
            [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "0" ]] && exit 0
            sleep 1
        done

        [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "0" ]] && exit 0

        WALL=$(find "$WALL_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" \) | shuf -n 1)
        
        if [ -n "$WALL" ]; then
            awww img "$WALL" --transition-type random --transition-step 90 --transition-fps 60
            
            ACCENT=$(python3 -c '
                from colorthief import ColorThief
                import sys
                def brightness(c): return sum(v*v for v in c)
                colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
                brightest = max(colors,key=brightness)
                print("#%02x%02x%02x" % brightest)
            ' "$WALL")

            r=$(printf "%d" 0x${ACCENT:1:2})
            g=$(printf "%d" 0x${ACCENT:3:2})
            b=$(printf "%d" 0x${ACCENT:5:2})
            [[ $((r + g + b)) -lt 180 ]] && ACCENT="#ffffff"

            ~/.local/bin/gen-style.sh "$ACCENT"
            sleep 0.1
            ~/.local/bin/apply-style.sh
        fi
    done
}

toggle_wallpaper() {
    if [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "1" ]]; then
        echo "0" > "$STATE_FILE"
        [[ -x $(command -v notify-send) ]] && notify-send -u low "Wallpaper Automation" "Turned OFF"
    else
        echo "1" > "$STATE_FILE"
        [[ -x $(command -v notify-send) ]] && notify-send -u low "Wallpaper Automation" "Turned ON"
        run_wallpaper &
    fi
}

if [[ "$1" == "--toggle" ]]; then
    toggle_wallpaper
    exit 0
fi

# Automatically restore wallpaper on boot
if [[ "$(cat "$STATE_FILE")" == "1" ]]; then
    run_wallpaper &
fi