#!/usr/bin/env bash

# This script handles DPMS commands for different window managers.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: dpms_handler.sh ACTION
Turn monitors on or off for the current window manager.

Arguments:
    on                  Turn monitors on
    off                 Turn monitors off
    -h, --help          Show this help message
EOF
        exit 0
fi

WM=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

if [ "$WM" = "hyprland" ]; then
    hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = \"$1\" }))"
elif [ "$WM" = "niri" ]; then
    if [ "$1" = "on" ]; then
        niri msg action power-on-monitors
    else
        niri msg action power-off-monitors
    fi
elif [ "$WM" = "mango" ]; then
    if [ "$1" = "on" ]; then
        mmsg dispatch wakeup_monitor
    else
        mmsg dispatch sleep_monitor
    fi
elif [ "$WM" = "labwc" ]; then
    # Dynamically extract the first active display name (e.g., eDP-1)
    MONITOR=$(wlr-randr | awk '/^[a-zA-Z0-9-]+/ {print $1; exit}')
    
    if [ -n "$MONITOR" ]; then
        if [ "$1" = "on" ]; then
            wlr-randr --output "$MONITOR" --on
        else
            wlr-randr --output "$MONITOR" --off
        fi
    fi
fi