#!/bin/bash

WALL_DIR="$HOME/Pictures/Wallpapers"

list_walls() {
    cd "$WALL_DIR" || exit
    for file in *.{jpg,jpeg,png,gif}; do
        [[ -e "$file" ]] || continue
        echo -en "$file\0icon\x1f$WALL_DIR/$file\n"
    done
}

set_wallpaper() {
    local wall="$1"
    awww img "$wall" \
        --transition-type random \
        --transition-step 90 \
        --transition-fps 60

    if pgrep -x "niri" > /dev/null; then
        mkdir -p "$WALL_DIR/temp"
        magick "$wall" -blur 0x15 "$WALL_DIR/temp/backdrop.jpg"
        awww img -n "awww-daemon-backdrop" "$WALL_DIR/temp/backdrop.jpg"
    fi
}

CHOICE=$(list_walls | rofi -dmenu -i -p "Wallpaper" \
-theme-str "
    window { width: 65%; height: 80%; }
    listview { columns: 4; lines: 2; spacing: 5px; padding: 5px;}
    element { orientation: vertical; padding: 5px; border-radius: 15px; }
    element-icon { size: 250px; horizontal-align: 0.5; }
")

if [ -n "$CHOICE" ]; then
    WALL="$WALL_DIR/$CHOICE"

    # Check if mpvpaper is running and kill it to prevent conflicts with awww
    if pgrep -x "mpvpaper" > /dev/null; then
        pkill mpvpaper
    fi
    
    # 1. Set awww
    set_wallpaper "$WALL"
    
    # 2. Get accent color from wallpaper using colorthief, fallback to a default if too dark
    ACCENT=$(python3 -c '
        from colorthief import ColorThief
        import sys
        def brightness(c): return sum(v*v for v in c)
        colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
        brightest = max(colors,key=brightness)
        print("#%02x%02x%02x" % brightest)
    ' "$WALL")

    # 3. If the accent color is too dark, use a lighter default
    r=$(printf "%d" 0x${ACCENT:1:2})
    g=$(printf "%d" 0x${ACCENT:3:2})
    b=$(printf "%d" 0x${ACCENT:5:2})
    if [ $((r + g + b)) -lt 180 ]; then
        ACCENT="#ffffff"
    fi

    # 4. Generate theme files with the new accent color
    ~/.local/bin/gen-style.sh "$ACCENT"

    sleep 0.1
    ~/.local/bin/apply-style.sh
fi