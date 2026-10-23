#!/usr/bin/env bash

# This script is used to resume the wallpaper after startup.
# Classic restores the compatibility pointer after native Hikai releases ownership.

# Hikai coordinates awww images and native videos through its wallpaper service.
if [[ $(cat "$HOME/.local/state/hakuspace/state/[shell].backend" 2>/dev/null) == hikai ]]; then
    exit 0
fi

CACHE_DIR="$HOME/.cache"
CURRENT_WALL="$CACHE_DIR/current_wallpaper"

pkill mpvpaper 2>/dev/null || true
awww kill -a 2>/dev/null || true

# Flag to indicate if the current wallpaper is a video file
is_mpvpaper=false
if [[ -f "$CURRENT_WALL" ]]; then
    WALLPAPER=$(cat "$CURRENT_WALL")
    if [[ -f "$WALLPAPER" ]]; then
        MIME_TYPE=$(file -b --mime-type "$WALLPAPER")
        # Reapply native selections because the Classic daemon may cache an older image.
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

# Restore the latest native or Classic selection through the Classic setter
if [[ -f "$CURRENT_WALL" ]]; then
    WALLPAPER=$(cat "$CURRENT_WALL")
    if [[ -f "$WALLPAPER" ]]; then
        MIME_TYPE=$(file -b --mime-type "$WALLPAPER")
        # Resume video wallpaper if the MIME type indicates a video file
        if [[ "$MIME_TYPE" == video/* || "$MIME_TYPE" == image/* ]]; then
            sleep 0.4
            "$HOME/.local/bin/wallpaper_set.sh" "$WALLPAPER"
            echo "Resumed Classic wallpaper"
        fi
    fi
fi
