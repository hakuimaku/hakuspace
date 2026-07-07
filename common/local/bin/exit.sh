#!/bin/bash

if pgrep -x "Hyprland" > /dev/null; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif pgrep -x "niri" > /dev/null; then
    pkill niri
fi