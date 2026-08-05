#!/usr/bin/env bash

WALL_DIR="$HOME/Videos/Wallpapers"
PREVIEW_DIR="$WALL_DIR/Preview"

SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"

if [[ $1 == "--exit" ]]; then
    if ! pgrep -x "mpvpaper" > /dev/null; then
        notify-send "Lively Wallpaper is not running"
        exit 1
    fi
    pkill mpvpaper
    "$HOME/.local/bin/gen_style.sh" "#ffffff"
    "$HOME/.local/bin/apply_style.sh"
    notify-send "Lively Wallpaper exited"
    exit 1
fi

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

    "$SET_WALLPAPER_SCRIPT" "$WALL"

    # 2. Pick accent from PREVIEW image
    if [[ -n "$PREVIEW" ]]; then
        ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$PREVIEW")
        [[ -z "$ACCENT" ]] && ACCENT="#ffffff"
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
    "$HOME/.local/bin/gen_style.sh" "$ACCENT"
    sleep 0.2
    "$HOME/.local/bin/apply_style.sh"
fi