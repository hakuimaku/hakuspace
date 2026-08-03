#!/usr/bin/env bash

# This script locks the screen using hyprlock, with different configurations based on the monitor resolution.

WIDTH=""
HEIGHT=""

# Check dependencies
if ! command -v hyprlock &> /dev/null; then
    echo "hyprlock is not installed. Please install it to use this script."
    exit 1
fi

if ! command -v wlr-randr &> /dev/null; then
    echo "wlr-randr is not installed. Some WMs may use sysfs detection instead."
fi

get_resolution() {
    # Hyprland
    if [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
        read -r WIDTH HEIGHT <<< $(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')
    # Niri
    elif [[ "$XDG_CURRENT_DESKTOP" = "niri" ]]; then
        read -r WIDTH HEIGHT <<< $(niri msg --json outputs | jq -r 'to_entries | .[0].value | .modes[.current_mode] | "\(.width) \(.height)"')
    # MangoWM
    elif [[ "$XDG_CURRENT_DESKTOP" = "mango" ]]; then
        read -r WIDTH HEIGHT <<< $(mmsg get all-monitors | jq -r '.monitors[] | select(.active == true) // .[0] | "\(.width) \(.height)"')
    # Labwc
    elif [[ "$XDG_CURRENT_DESKTOP" = "labwc" ]]; then
        read -r WIDTH HEIGHT <<< $(wlr-randr | grep -i "current" | head -n 1 | sed -E 's/.* ([0-9]+)x([0-9]+) px.*/\1 \2/')
    # Fallback to sysfs detection
    else
        for mode_file in /sys/class/drm/card*-*/modes; do
            if [ -f "$mode_file" ] && [ -s "$mode_file" ]; then
                read -r MODE < "$mode_file"
                if [[ "$MODE" =~ ([0-9]+)x([0-9]+) ]]; then
                    WIDTH="${BASH_REMATCH[1]}"
                    HEIGHT="${BASH_REMATCH[2]}"
                fi
            fi
        done
    fi
}

# Main execution
get_resolution

echo "Monitor resolution: ${WIDTH}x${HEIGHT}"
sleep 0.2

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
    echo "Could not determine monitor resolution. How it could be..."
fi

echo "executing hyprlock with appropriate configuration..."
if [[ "$WIDTH" -ge 1920 && "$HEIGHT" -ge 1080 ]]; then
    hyprlock
else
    hyprlock -c ~/.config/hypr/hyprlock_tiny.conf
fi