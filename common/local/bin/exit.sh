#!/bin/bash

if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action quit
fi