#!/usr/bin/env bash

# This script reloads the configuration for 4 WMs: Hyprland, Niri, MangoWM and Labwc

XDG_CURRENT_DESKTOP=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

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

