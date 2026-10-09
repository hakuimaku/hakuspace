#!/bin/bash

# Check dependencies
if ! command -v hyprpicker >/dev/null 2>&1; then
    echo "hyprpicker is not installed."
    notify-send "hyprpicker is not installed" "Please install hyprpicker to pick a color"
    exit 1
fi

# Main
COLOR="$(hyprpicker)"

~/.local/bin/gen-style.sh "$COLOR"
~/.local/bin/apply-style.sh