#!/usr/bin/env bash

# This script toggles the hypridle process on or off, which is responsible for managing idle states.

if pgrep -x hypridle >/dev/null 2>&1; then
    killall hypridle
    notify-send "Hypridle" "Disabled"
else
    hypridle &
    notify-send "Hypridle" "Enabled"
fi