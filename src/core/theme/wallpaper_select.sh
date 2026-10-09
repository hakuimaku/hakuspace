#!/usr/bin/env bash

# Include WALL_DIR & ACCENT_COLOR_BASED_ON_WALLPAPER
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}
ACCENT_COLOR_MODE=${ACCENT_COLOR_MODE:-vivid}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"
source "$SCRIPT_DIR/accent_color.sh"

ROFI_THEME="wallpaper-select.rasi"


# argument --extend to set position of rofi window
if [[ "$1" == "--extend" || "$1" == "-e" ]]; then
  shift
  EXTEND=("$@")
else
  EXTEND=()
fi

list_walls() {
    cd "$WALL_DIR" || exit
    for file in *.{jpg,jpeg,png,gif}; do
        [[ -e "$file" ]] || continue
        echo -e "$file\0icon\x1f$WALL_DIR/$file"
    done
}

CHOICE=$(list_walls | rofi -dmenu -i "${EXTEND[@]}" -p "Wallpaper" -theme "$ROFI_THEME")

if [ -n "$CHOICE" ]; then
    WALL="$WALL_DIR/$CHOICE"
    
    # Set the wallpaper
    "$SET_WALLPAPER_SCRIPT" "$WALL"
    
    # Check if accent color should be based on wallpaper
    if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
        ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$WALL" "$ACCENT_COLOR_MODE")
        ACCENT="$(accent_color_or_fallback "$ACCENT")"

        "$HOME/.local/bin/gen_style.sh" "$ACCENT" && \
            "$HOME/.local/bin/apply_style.sh"
    fi
fi