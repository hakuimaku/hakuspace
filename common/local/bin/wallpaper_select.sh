#!/usr/bin/env bash

# Include WALL_DIR
source "$HOME/hakuspace-control/main_setting.sh"

# Fallback WALL_DIR if not set
WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}

SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"

list_walls() {
    cd "$WALL_DIR" || exit
    for file in *.{jpg,jpeg,png,gif}; do
        [[ -e "$file" ]] || continue
        echo -en "$file\0icon\x1f$WALL_DIR/$file\n"
    done
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
    
    # 1. Set the selected wallpaper
    "$SET_WALLPAPER_SCRIPT" "$WALL"
    
    # 2. Get accent color from the selected wallpaper
    ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL")
    [[ -z "$ACCENT" ]] && ACCENT="#ffffff"

    # 3. If the accent color is too dark, use a lighter default
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