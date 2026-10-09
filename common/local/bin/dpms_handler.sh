#!/bin/bash

# This script handles DPMS (Display Power Management Signaling) commands for different window managers.

WM=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

if [ "$WM" = "hyprland" ]; then
    hyprctl dispatch dpms "$1"
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
fi