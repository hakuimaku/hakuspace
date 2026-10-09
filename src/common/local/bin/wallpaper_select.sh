#!/usr/bin/env bash

# Include WALL_DIR & ACCENT_COLOR_BASED_ON_WALLPAPER
[ -f "$HOME/hakuspace-control/main_setting.sh" ] && source "$HOME/hakuspace-control/main_setting.sh"

WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}

SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"

list_walls() {
    cd "$WALL_DIR" || exit
    for file in *.{jpg,jpeg,png,gif}; do
        [[ -e "$file" ]] || continue
        echo -e "$file\0icon\x1f$WALL_DIR/$file"
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
    
    # Set the wallpaper
    "$SET_WALLPAPER_SCRIPT" "$WALL"
    
    # Check if accent color should be based on wallpaper
    if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
        ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL")
        [[ -z "$ACCENT" ]] && ACCENT="#ffffff"

        r=$(printf "%d" 0x${ACCENT:1:2})
        g=$(printf "%d" 0x${ACCENT:3:2})
        b=$(printf "%d" 0x${ACCENT:5:2})
        if [ $((r + g + b)) -lt 180 ]; then
            ACCENT="#ffffff"
        fi

        "$HOME/.local/bin/gen_style.sh" "$ACCENT"
        sleep 0.2
        "$HOME/.local/bin/apply_style.sh"
    fi
fi