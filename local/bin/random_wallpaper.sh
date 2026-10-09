#!/bin/bash

WALL_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=300 # 5 mins
PID_FILE="/tmp/random_wallpaper.pid"

trap "rm -f $PID_FILE; exit" INT TERM EXIT

if [ "$1" = "toggle" ]; then
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        kill $(cat "$PID_FILE")
        rm -f "$PID_FILE"
        if command -v notify-send >/dev/null; then
            notify-send -u low "Wallpaper Automation" "Turned OFF automatic wallpaper changing"
        fi
        exit 0
    else
        "$0" &
        if command -v notify-send >/dev/null; then
            notify-send -u low "Wallpaper Automation" "Turned ON automatic wallpaper changing"
        fi
        exit 0
    fi
fi

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    notify-send -u low "Wallpaper Automation" "Already running with PID $(cat "$PID_FILE")"
    exit 1
fi

echo $$ > "$PID_FILE"

if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 1
fi

while true; do
    WALL=$(find "$WALL_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" \) | shuf -n 1)
    
    if [ -n "$WALL" ]; then
        awww img "$WALL" \
            --transition-type random \
            --transition-step 90 \
            --transition-fps 60
        
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
        if [ $((r + g + b)) -lt 180 ]; then
            ACCENT="#ffffff"
        fi

        ~/.local/bin/gen-style.sh "$ACCENT"
        sleep 0.1
        ~/.local/bin/apply-style.sh
    fi
    
    sleep $INTERVAL
done
