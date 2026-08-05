#!/usr/bin/env bash

set -euo pipefail

WALLPAPER="${1:-}"
BACKDROP_DIR="/tmp"

# Detect active monitor using wlr-randr
get_active_monitor() {
    local detected_monitor=""
    if command -v wlr-randr >/dev/null 2>&1; then
        detected_monitor=$(wlr-randr | awk '/^[^ ]/ {m=$1} /current/ {print m; exit}')
    fi

    # Fallback to eDP-1 if wlr-randr is missing or output is empty
    if [[ -z "$detected_monitor" ]]; then
        echo "eDP-1"
    else
        echo "$detected_monitor"
    fi
}

# Generate blurred backdrop image for Niri compositor
make_niri_backdrop() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" == "niri" ]] || pgrep -x "niri" >/dev/null 2>&1; then
        mkdir -p "$BACKDROP_DIR"
        if magick "${WALLPAPER}[0]" -background black -alpha remove -set option:filter:blur 1.0 -blur 0x15 "$BACKDROP_DIR/backdrop.jpg" 2>/dev/null; then
            awww img -n "awww-daemon-backdrop" "$BACKDROP_DIR/backdrop.jpg"
        else
            echo "Warning: Failed to generate backdrop via ImageMagick." >&2
        fi
    fi
}

# Input Validation
if [[ -z "$WALLPAPER" ]]; then
    echo "Error: No wallpaper path provided." >&2
    echo "Usage: $0 /path/to/wallpaper" >&2
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
        pkill -x mpvpaper 2>/dev/null || true

        # Set static/animated image background using awww
        if awww img "$WALLPAPER" --transition-type random --transition-step 90 --transition-fps 60; then
            make_niri_backdrop
        else
            echo "Error: Failed to set image wallpaper using awww." >&2
            exit 1
        fi
        ;;

    video/*)
        # Terminate previous mpvpaper instance before launching a new one
        pkill -x mpvpaper 2>/dev/null || true
        sleep 0.2

        MONITOR=$(get_active_monitor)
        echo "Setting video wallpaper on monitor: $MONITOR"

        # Launch mpvpaper in background for video playback on target monitor
        mpvpaper -v -s -o "no-audio loop" "$MONITOR" "$WALLPAPER" >/dev/null 2>&1 &
        MPV_PID=$!

        # Verify whether mpvpaper process started successfully
        sleep 0.3
        if kill -0 "$MPV_PID" 2>/dev/null; then
            make_niri_backdrop
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