#!/usr/bin/env bash

# This script toggles the night light mode
# hyprsunset (hyprland) or gammastep (other WM)

TEMPERATURE=4000

run_nightlight() {
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        hyprsunset --temperature $TEMPERATURE &
        echo "Night light mode enabled with hyprsunset at $TEMPERATURE K"
    else
        gammastep -O $TEMPERATURE &
        echo "Night light mode enabled with gammastep at $TEMPERATURE K"
    fi
}

# Toggle
if pgrep -x "hyprsunset" > /dev/null || pgrep -x "gammastep" > /dev/null; then
    pkill hyprsunset
    pkill gammastep
    echo "Night light mode disabled"
else
    run_nightlight
    echo "Night light mode enabled"
fi