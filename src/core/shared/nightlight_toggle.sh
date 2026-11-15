#!/usr/bin/env bash

# This script toggles the night light mode
# hyprsunset (hyprland) or gammastep (other WM)

# Include NIGHT_LIGHT_TEMPERATURE variable from setting.sh
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

# Fallback temperature if NIGHT_LIGHT_TEMPERATURE is not set
NIGHT_LIGHT_TEMPERATURE=${NIGHT_LIGHT_TEMPERATURE:-4000}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: nightlight_toggle.sh [OPTION]
Toggle the night light for the current window manager.

Options:
    --check             Report whether night light is enabled
    -h, --help          Show this help message
EOF
        exit 0
fi

run_nightlight() {
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        hyprsunset --temperature $NIGHT_LIGHT_TEMPERATURE &
        echo "Night light mode enabled with hyprsunset at $NIGHT_LIGHT_TEMPERATURE K"
    else
        gammastep -O $NIGHT_LIGHT_TEMPERATURE &
        echo "Night light mode enabled with gammastep at $NIGHT_LIGHT_TEMPERATURE K"
    fi
}

check_status() {
    if pgrep "hyprsunset" > /dev/null || pgrep "gammastep" > /dev/null > /dev/null; then
        echo "Night light mode is currently enabled"
        exit 0
    else
        echo "Night light mode is currently disabled"
        exit 1
    fi
}

# Check for --check argument
if [[ "$1" == "--check" ]]; then
    check_status
fi

# Toggle
if pgrep "hyprsunset" > /dev/null || pgrep "gammastep" > /dev/null > /dev/null; then
    pkill hyprsunset
    pkill gammastep
    echo "Night light mode disabled"
else
    run_nightlight
    echo "Night light mode enabled"
fi