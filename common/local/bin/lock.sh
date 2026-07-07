#!/bin/bash

if pgrep -x "Hyprland" > /dev/null; then
    hyprlock
elif pgrep -x "niri" > /dev/null; then
    swaylock
fi