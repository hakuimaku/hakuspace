#!/usr/bin/env bash

# Include WALL_DIR, WALL_MPV_DIR & ACCENT_COLOR_BASED_ON_WALLPAPER
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
WALL_MPV_DIR=${WALL_MPV_DIR:-$HOME/Videos/Wallpapers}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}
ACCENT_COLOR_MODE=${ACCENT_COLOR_MODE:-vivid}

PREVIEW_DIR="$WALL_MPV_DIR/.thumbnails"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SET_WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper_set.sh"
GET_ACCENT_COLOR_SCRIPT="$HOME/.local/bin/get_accent_color.py"
source "$SCRIPT_DIR/accent_color.sh"

ROFI_THEME="wallpaper-select.rasi"

generate_thumbnails() {
    mkdir -p "$PREVIEW_DIR"
    cd "$WALL_MPV_DIR" || exit
    
    for file in *.mp4; do
        [[ -e "$file" ]] || continue
        filename="${file%.*}"
        
        # Check if any preview format already exists
        if [[ ! -f "$PREVIEW_DIR/$filename.gif" && ! -f "$PREVIEW_DIR/$filename.jpg" && ! -f "$PREVIEW_DIR/$filename.png" ]]; then
            # Extract the first frame [0] using ImageMagick
            if command -v magick >/dev/null 2>&1; then
                magick "$file[0]" "$PREVIEW_DIR/$filename.jpg" 2>/dev/null
            elif command -v convert >/dev/null 2>&1; then
                convert "$file[0]" "$PREVIEW_DIR/$filename.jpg" 2>/dev/null
            fi
        fi
    done
}

set_wallpaper() {
    local choice="$1"
    local mode="$2"
    
    if [ "$mode" = "static" ]; then
        local wall="$WALL_DIR/$choice"
        
        # Set the wallpaper
        "$SET_WALLPAPER_SCRIPT" "$wall"
        
        # Check if accent color should be based on wallpaper
        if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
            ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$wall" "$ACCENT_COLOR_MODE")
            ACCENT="$(accent_color_or_fallback "$ACCENT")"

            "$HOME/.local/bin/gen_style.sh" "$ACCENT" && \
                "$HOME/.local/bin/apply_style.sh"
        fi
    elif [ "$mode" = "lively" ]; then
        local wall="$WALL_MPV_DIR/$choice"
        local filename="${choice%.*}"

        # Pick preview image for color (not video)
        local preview=""
        if [[ -f "$PREVIEW_DIR/$filename.gif" ]]; then
            preview="$PREVIEW_DIR/$filename.gif"
        elif [[ -f "$PREVIEW_DIR/$filename.jpg" ]]; then
            preview="$PREVIEW_DIR/$filename.jpg"
        elif [[ -f "$PREVIEW_DIR/$filename.png" ]]; then
            preview="$PREVIEW_DIR/$filename.png"
        fi

        "$SET_WALLPAPER_SCRIPT" "$wall"

        # Check if accent color should be based on wallpaper
        if [ "$ACCENT_COLOR_BASED_ON_WALLPAPER" = true ]; then
            if [[ -n "$preview" ]]; then
                ACCENT=$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$preview" "$ACCENT_COLOR_MODE")
            else
                ACCENT="#ffffff"
            fi

            ACCENT="$(accent_color_or_fallback "$ACCENT")"

            "$HOME/.local/bin/gen_style.sh" "$ACCENT" && \
                "$HOME/.local/bin/apply_style.sh"
        fi
    fi
}

list_static() {
    cd "$WALL_DIR" || exit
    for file in *.{jpg,jpeg,png,gif}; do
        [[ -e "$file" ]] || continue
        echo -e "$file\0icon\x1f$WALL_DIR/$file"
    done
}

list_lively() {
    generate_thumbnails
    cd "$WALL_MPV_DIR" || exit
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

        echo -e "$file\0icon\x1f$thumb"
    done
}

# Handle rofi script modes
if [ "$1" = "--static" ]; then
    shift
    if [ -n "$1" ]; then
        ( set_wallpaper "$1" "static" ) >/dev/null 2>&1 &
        exit 0
    fi
    list_static
    exit 0
fi

if [ "$1" = "--lively" ]; then
    shift
    if [ -n "$1" ]; then
        ( set_wallpaper "$1" "lively" ) >/dev/null 2>&1 &
        exit 0
    fi
    list_lively
    exit 0
fi

# Main logic
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: wallpaper_select.sh [OPTION]
Select and manage wallpaper (Static and Lively).

Options:
    --exit              Stop the running video wallpaper
    -e, --extend ...    Set position of rofi window
    -h, --help          Show this help message
EOF
    exit 0
fi

if [[ "$1" == "--exit" ]]; then
    if ! pgrep "mpvpaper" > /dev/null; then
        notify-send "Lively Wallpaper is not running"
        exit 1
    fi
    pkill mpvpaper
    notify-send "Lively Wallpaper exited"
    exit 1
fi

# argument --extend to set position of rofi window
if [[ "$1" == "--extend" || "$1" == "-e" ]]; then
  shift
  EXTEND=("$@")
else
  EXTEND=()
fi

rofi -show "Wallpaper" \
    -p "Wallpaper" \
    -i \
    "${EXTEND[@]}" \
    -theme "$ROFI_THEME" \
    -modes "Wallpaper:$0 --static,Lively Wallpaper:$0 --lively"