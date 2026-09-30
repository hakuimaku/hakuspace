#!/usr/bin/env bash

# This script is used to resume the wallpaper after startup.
# Only video wallpapers are resumed, cause normal wallpapers are managed by awww daemon

CACHE_DIR="$HOME/.cache"
CURRENT_WALL="$CACHE_DIR/current_wallpaper"

pkill mpvpaper 2>/dev/null || true
awww kill -a 2>/dev/null || true

# Flag to indicate if the current wallpaper is a video file
local is_mpvpaper = false
if [[ -f "$CURRENT_WALL" ]]; then
    WALLPAPER=$(cat "$CURRENT_WALL")
    if [[ -f "$WALLPAPER" ]]; then
        MIME_TYPE=$(file -b --mime-type "$WALLPAPER")
        # Resume video wallpaper if the MIME type indicates a video file
        if [[ "$MIME_TYPE" == video/* ]]; then
            is_mpvpaper=true
            echo "Detected video wallpaper: $WALLPAPER"
        fi
    fi
fi

# Satrtup awww daemon
if [[ "$is_mpvpaper" == true ]]; then
    awww-daemon --no-cache &
    echo "Resumed awww daemon without cache"
else
    awww-daemon &
    echo "Resumed awww daemon"
fi

# Niri specific resume for awww backdrop daemon
if [[ "${XDG_CURRENT_DESKTOP:-}" == "niri" ]]; then
    awww-daemon -n awww-daemon-backdrop &
    echo "Resumed awww backdrop daemon for Niri."
fi

# Start mpvpaper if the current wallpaper is a video file
if [[ -f "$CURRENT_WALL" ]]; then
    WALLPAPER=$(cat "$CURRENT_WALL")
    if [[ -f "$WALLPAPER" ]]; then
        MIME_TYPE=$(file -b --mime-type "$WALLPAPER")
        # Resume video wallpaper if the MIME type indicates a video file
        if [[ "$MIME_TYPE" == video/* ]]; then
            sleep 0.4
            "$HOME/.local/bin/wallpaper_set.sh" "$WALLPAPER"
            echo "Resumed mpvpaper"
        fi
    fi
fi
