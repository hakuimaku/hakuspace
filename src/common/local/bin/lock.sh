#!/usr/bin/env bash

# This script locks the screen using hyprlock, with different configurations based on the monitor resolution.

WIDTH=""
HEIGHT=""

# Check dependencies
if ! command -v hyprlock &> /dev/null; then
    echo "hyprlock is not installed. Please install it to use this script."
    notify-send "Lock screen" "hyprlock is not installed. Please install it to use this script."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed"
    notify-send "Lock screen" "Warning: jq is not installed"
fi

if ! command -v wlr-randr &> /dev/null; then
    echo "wlr-randr is not installed. Some WMs may use sysfs detection instead."
fi

fallback_resolution() {
    read -r WIDTH HEIGHT <<< $(wlr-randr | grep -i "current" | head -n 1 | sed -E 's/.* ([0-9]+)x([0-9]+) px.*/\1 \2/')
    if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
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

get_resolution() {
    XDG_CURRENT_DESKTOP=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

    case "$XDG_CURRENT_DESKTOP" in
        "hyprland")
            read -r WIDTH HEIGHT <<< $(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')
            ;;
        "niri")
            read -r WIDTH HEIGHT <<< $(niri msg --json outputs | jq -r 'to_entries | .[0].value | .modes[.current_mode] | "\(.width) \(.height)"')
            ;;
        "mango")
            read -r WIDTH HEIGHT <<< $(mmsg get all-monitors | jq -r '.monitors[] | select(.active == true) // .[0] | "\(.width) \(.height)"')
            ;;
        *)
            fallback_resolution
            ;;
    esac
}

# Main execution
get_resolution

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
    fallback_resolution
    if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
        echo "Could not determine monitor resolution. How it could be..."
        notify-send "Lock screen" "Could not determine monitor resolution. How it could be..."
        exit 1
    fi
fi

echo "Monitor resolution: ${WIDTH}x${HEIGHT}"
sleep 0.2

echo "Executing hyprlock with appropriate configuration..."
if [[ "$WIDTH" -ge 1920 && "$HEIGHT" -ge 1080 ]]; then
    hyprlock
else
    hyprlock -c ~/.config/hypr/hyprlock_tiny.conf
fi