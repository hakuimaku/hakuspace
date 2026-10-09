#!/bin/sh
set -eu
envsubst < "$HOME/.config/waybar/style.css.in" > "$HOME/.config/waybar/style.css"
