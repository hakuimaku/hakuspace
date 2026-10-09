#!/usr/bin/env bash

# This script is used to resume the wallpaper after startup.
# Only video wallpapers are resumed, cause normal wallpapers are managed by awww daemon

CACHE_DIR="$HOME/.cache"
CURRENT_WALL="$CACHE_DIR/current_wallpaper"

if [[ -f "$CURRENT_WALL" ]]; then
    WALLPAPER=$(cat "$CURRENT_WALL")
    if [[ -f "$WALLPAPER" ]]; then
        MIME_TYPE=$(file -b --mime-type "$WALLPAPER")
        if [[ "$MIME_TYPE" == video/* ]]; then
            # Small delay to ensure wayland is ready and not conflict with awww
            sleep 0.4
            "$HOME/.local/bin/wallpaper_set.sh" "$WALLPAPER"
        fi
    fi
fi
