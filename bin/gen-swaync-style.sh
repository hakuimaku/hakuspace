#!/bin/sh
set -eu
envsubst < "$HOME/.config/swaync/style.css.in" > "$HOME/.config/swaync/style.css"