#!/usr/bin/env bash

WALL_DIR="$HOME/Videos/Wallpapers"
BACKDROP_DIR="/tmp"
PREVIEW_DIR="$WALL_DIR/Preview"
MONITOR="eDP-1" #Custom your monitor name

if [[ $1 == "--exit" ]]; then
    if ! pgrep -x "mpvpaper" > /dev/null; then
        notify-send "Lively Wallpaper is not running"
        exit 1
    fi
    pkill mpvpaper
    # Reset accent to default
    ~/.local/bin/gen_style.sh "#ffffff"
    ~/.local/bin/apply_style.sh
    notify-send "Lively Wallpaper exited"
    exit 1
fi

set_wallpaper() {
    local wall="$1"
    pkill mpvpaper
    sleep 0.2
    mpvpaper -v -s -o "no-audio loop" "$MONITOR" "$wall" > /dev/null 2>&1 &
    if pgrep -x "niri" > /dev/null; then
        magick "${wall}[0]" -background black -alpha remove -set option:filter:blur 1.0 -blur 0x15 "$BACKDROP_DIR/backdrop.jpg"
        awww img -n "awww-daemon-backdrop" $BACKDROP_DIR/backdrop.jpg
    fi
}

list_walls() {
    cd "$WALL_DIR" || exit
    for file in *.mp4; do
        [[ -e "$file" ]] || continue

        filename="${file%.*}"

        if [[ -f "$PREVIEW_DIR/$filename.gif" ]]; then
            thumb="$PREVIEW_DIR/$filename.gif"
        elif [[ -f "$PREVIEW_DIR/$filename.jpg" ]]; then
            thumb="$PREVIEW_DIR/$filename.jpg"
        elif [[ -f "$PREVIEW_DIR/$filename.png" ]]; then
            thumb="$PREVIEW_DIR/$filename.png"
        else
            thumb="video-x-generic"
        fi

        echo -en "$file\0icon\x1f$thumb\n"
    done
}

CHOICE=$(list_walls | rofi -dmenu -i -p "Wallpaper" -theme-str "
    window { width: 65%; height: 80%; }
        listview { columns: 4; lines: 2; spacing: 5px; padding: 5px;}
        element { orientation: vertical; padding: 5px; border-radius: 15px; }
        element-icon { size: 250px; horizontal-align: 0.5; }
")

if [ -n "$CHOICE" ]; then
    WALL="$WALL_DIR/$CHOICE"
    filename="${CHOICE%.*}"

    # Pick preview image for color (not video)
    if [[ -f "$PREVIEW_DIR/$filename.gif" ]]; then
        PREVIEW="$PREVIEW_DIR/$filename.gif"
    elif [[ -f "$PREVIEW_DIR/$filename.jpg" ]]; then
        PREVIEW="$PREVIEW_DIR/$filename.jpg"
    elif [[ -f "$PREVIEW_DIR/$filename.png" ]]; then
        PREVIEW="$PREVIEW_DIR/$filename.png"
    else
        PREVIEW=""
    fi

    set_wallpaper "$WALL"

    # 2. Pick accent from PREVIEW image
    if [[ -n "$PREVIEW" ]]; then
        ACCENT=$(python3 -c '
            from colorthief import ColorThief
            import sys
            def brightness(c): return sum(v*v for v in c)
            colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
            brightest = max(colors,key=brightness)
            print("#%02x%02x%02x" % brightest)
        ' "$PREVIEW")
    else
        ACCENT="#ffffff"
    fi

    # 3. If accent too dark -> fallback
    r=$(printf "%d" 0x${ACCENT:1:2})
    g=$(printf "%d" 0x${ACCENT:3:2})
    b=$(printf "%d" 0x${ACCENT:5:2})
    if [ $((r + g + b)) -lt 180 ]; then
        ACCENT="#ffffff"
    fi

    # 4. Generate theme files with the new accent color
    ~/.local/bin/gen_style.sh "$ACCENT"

    sleep 0.5
    ~/.local/bin/apply_style.sh
fi

exit 1