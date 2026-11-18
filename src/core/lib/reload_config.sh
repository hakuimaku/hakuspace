#!/usr/bin/env bash

# This script reloads the configuration for 4 WMs: Hyprland, Niri, MangoWM and Labwc

XDG_CURRENT_DESKTOP=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
HAKU_BIN_DIR="${HAKU_BIN_DIR:-$HOME/.local/bin}"

nightlight_was_active=0
if pgrep -x "hyprsunset" >/dev/null 2>&1 || pgrep -x "gammastep" >/dev/null 2>&1; then
    nightlight_was_active=1
fi

case "$XDG_CURRENT_DESKTOP" in
    hyprland)
        hyprctl reload
        ;;
    niri)
        niri msg action load-config-file
        ;;
    mango)
        mmsg -d reload_config
        mmsg dispatch reload_config
        ;;
    labwc)
        labwc --reconfigure
        ;;
esac

if (( nightlight_was_active )); then
    if [[ -x "$HAKU_BIN_DIR/nightlight_toggle.sh" ]]; then
        "$HAKU_BIN_DIR/nightlight_toggle.sh" --on >/dev/null 2>&1 || true
    fi
fi

