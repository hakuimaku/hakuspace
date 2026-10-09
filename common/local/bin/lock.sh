#!/bin/bash

WIDTH=""
HEIGHT=""

# Hyprland
if [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] || [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    read -r WIDTH HEIGHT <<< $(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')
fi

# Niri
if [ "$XDG_CURRENT_DESKTOP" = "niri" ] || [ -n "$NIRI_SOCKET" ]; then
    read -r WIDTH HEIGHT <<< $(niri msg --json outputs | jq -r 'to_entries | .[0].value | .modes[.current_mode] | "\(.width) \(.height)"')
fi

# MangoWM
if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
    read -r WIDTH HEIGHT <<< $(mmsg get all-monitors | jq -r '.monitors[] | select(.active == true) // .[0] | "\(.width) \(.height)"')
fi

WIDTH=${WIDTH:-1920}
HEIGHT=${HEIGHT:-1080}

echo "Monitor resolution: ${WIDTH}x${HEIGHT}"

# Main
sleep 0.5

if [ "$WIDTH" -ge 1920 ] && [ "$HEIGHT" -ge 1080 ]; then
    hyprlock
else
    hyprlock -c ~/.config/hypr/hyprlock_tiny.conf
fi