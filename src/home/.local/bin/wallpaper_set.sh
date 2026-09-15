#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: wallpaper_set.sh WALLPAPER
Set the current wallpaper using the available wallpaper backend.

Arguments:
    WALLPAPER           Path to the wallpaper file
    -h, --help          Show this help message
EOF
        exit 0
fi

# Include AWWW_OPTS, GEN_HORI_OPTS, and GEN_VERT_OPTS from setting.sh if it exists
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

AWWW_OPTS=${AWWW_OPTS:-"--transition-type random --transition-step 90 --transition-fps 60"}

WALLPAPER="${1:-}"
CACHE_DIR="$HOME/.cache"

GEN_HORI_OPTS=${GEN_HORI_OPTS:-"-resize 800x250^ -gravity Center -crop 800x250+0+0 +repage"}
GEN_VERT_OPTS=${GEN_VERT_OPTS:-"-resize 600x800^ -gravity Center -crop 600x800+0+0 +repage"}

# Detect active monitor using wlr-randr
get_active_monitor() {
    local detected_monitor=""
    if command -v wlr-randr >/dev/null 2>&1; then
        detected_monitor=$(wlr-randr | awk '/^[^ ]/ {m=$1} /current/ {print m; exit}')
    else
        echo "Warning: wlr-randr not found. Defaulting to eDP-1." >&2
        notify-send "Warning: wlr-randr not found. Defaulting to eDP-1."
    fi

    # Fallback to eDP-1 if wlr-randr is missing or output is empty
    if [[ -z "$detected_monitor" ]]; then
        echo "eDP-1"
    else
        echo "$detected_monitor"
    fi
}

# Generate blurred backdrop image for Niri overview and imagebox
make_cache_img() {
    local is_successfull=1

    # Make Niri backdrop
    if command -v "niri" >/dev/null 2>&1; then
        mkdir -p "$CACHE_DIR"
        if magick "${WALLPAPER}[0]" -background black -alpha remove -set option:filter:blur 1.0 -blur 0x15 "$CACHE_DIR/backdrop.jpg" 2>/dev/null; then
            echo "Niri backdrop image generated at $CACHE_DIR/backdrop.jpg"
            if pgrep -x "niri" >/dev/null 2>&1; then
                awww img -n "awww-daemon-backdrop" "$CACHE_DIR/backdrop.jpg"
                echo "Niri is running. applied backdrop image to Niri."
            fi
        else
            is_successfull=0
        fi
    fi

    # Make wallpaper current image file
    # if magick "${WALLPAPER}[0]" "$CACHE_DIR/current_wallpaper.jpg" 2>/dev/null; then
    #     echo "Current wallpaper image generated at $CACHE_DIR/current_wallpaper.jpg"
    # else
    #     is_successfull=0
    # fi

    # Make wallpaper preview image for Rofi
    if magick "${WALLPAPER}[0]" $GEN_HORI_OPTS "$CACHE_DIR/walpaper_preview.jpg" 2>/dev/null && \
        magick "${WALLPAPER}[0]" $GEN_VERT_OPTS "$CACHE_DIR/walpaper_preview_vertical.jpg" 2>/dev/null; then
        echo "Wallpaper preview image generated at $CACHE_DIR/walpaper_preview.jpg and $CACHE_DIR/walpaper_preview_vertical.jpg"
    else
        is_successfull=0
    fi

    if [[ $is_successfull -eq 0 ]]; then
        echo "Set Wallpaper" "Failed to generate cache images wallpaper via ImageMagick" >&2
        notify-send "Set Wallpaper" "Failed to generate cache images wallpaper via ImageMagick"
    fi
}

# Input Validation
if [[ -z "$WALLPAPER" ]]; then
    echo "Error: No wallpaper path provided." >&2
        cat <<'EOF' >&2
Usage: wallpaper_set.sh WALLPAPER
Set the current wallpaper using the available wallpaper backend.

Arguments:
    WALLPAPER           Path to the wallpaper file
    -h, --help          Show this help message
EOF
    exit 1
fi

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: File '$WALLPAPER' does not exist." >&2
    exit 1
fi

# Determine file nature via MIME type
MIME_TYPE=$(file -b --mime-type "$WALLPAPER")

case "$MIME_TYPE" in
    image/*)
        # Kill any active mpvpaper instance to avoid layer overlapping
        pkill mpvpaper 2>/dev/null || true

        # Set static/animated image background using awww
        if awww img "$WALLPAPER" $AWWW_OPTS; then
            make_cache_img
        else
            echo "Error: Failed to set image wallpaper using awww." >&2
            exit 1
        fi
        ;;

    video/*)
        # Terminate previous mpvpaper instance before launching a new one
        pkill mpvpaper 2>/dev/null || true
        sleep 0.2

        MONITOR=$(get_active_monitor)
        echo "Setting video wallpaper on monitor: $MONITOR"

        # Launch mpvpaper in background for video playback on target monitor
        mpvpaper -v -s -o "no-audio loop" "$MONITOR" "$WALLPAPER" >/dev/null 2>&1 &
        MPV_PID=$!

        # Verify whether mpvpaper process started successfully
        sleep 0.3
        if kill -0 "$MPV_PID" 2>/dev/null; then
            make_cache_img
        else
            echo "Error: mpvpaper failed to render video '$WALLPAPER' on monitor '$MONITOR'." >&2
            exit 1
        fi
        ;;

    *)
        echo "Error: Unsupported file format ($MIME_TYPE)." >&2
        exit 1
        ;;
esac