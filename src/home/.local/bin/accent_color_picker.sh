#!/usr/bin/env bash

# Check dependencies
if ! command -v hyprpicker >/dev/null 2>&1; then
    echo "hyprpicker is not installed."
    notify-send "hyprpicker is not installed" "Please install hyprpicker to pick a color"
    exit 1
fi

# Main
COLOR="$(hyprpicker)"

$HOME/.local/bin/gen_style.sh "$COLOR" && \
    $HOME/.local/bin/apply_style.sh