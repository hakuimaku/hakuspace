#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
BACKDROP_DIR="$WALL_DIR/temp"
INTERVAL=300
STATE_FILE="/tmp/random_wallpaper_status"

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"

set_wallpaper() {
    local wall="$1"
    awww img "$wall" \
        --transition-type random \
        --transition-step 90 \
        --transition-fps 60

    if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
        mkdir -p "$BACKDROP_DIR"
        magick "${wall}[0]" -background black -alpha remove -set option:filter:blur 1.0 -blur 0x15 "$BACKDROP_DIR/backdrop.jpg"
        awww img -n "awww-daemon-backdrop" "$BACKDROP_DIR/backdrop.jpg"
    fi
}

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
            set_wallpaper "$WALL"

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

            ~/.local/bin/gen_style.sh "$ACCENT"
            sleep 0.1
            ~/.local/bin/apply_style.sh
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

toggle_wallpaper