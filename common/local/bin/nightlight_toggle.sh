#!/usr/bin/env bash

# This script toggles the night light mode
# hyprsunset (hyprland) or gammastep (other WM)

# Include NIGHT_LIGHT_TEMPERATURE variable from main_setting.sh
[ -f "$HOME/hakuspace-control/main_setting.sh" ] && source "$HOME/hakuspace-control/main_setting.sh"

# Fallback temperature if NIGHT_LIGHT_TEMPERATURE is not set
NIGHT_LIGHT_TEMPERATURE=${NIGHT_LIGHT_TEMPERATURE:-4000}

run_nightlight() {
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        hyprsunset --temperature $NIGHT_LIGHT_TEMPERATURE &
        echo "Night light mode enabled with hyprsunset at $NIGHT_LIGHT_TEMPERATURE K"
    else
        gammastep -O $NIGHT_LIGHT_TEMPERATURE &
        echo "Night light mode enabled with gammastep at $NIGHT_LIGHT_TEMPERATURE K"
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