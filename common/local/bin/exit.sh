#!/bin/bash

if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action quit
elif [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg dispatch quit
fi