#!/bin/sh
set -eu
envsubst '${FONT_FAMILY} ${FONT_SIZE}' \
  < "$HOME/.config/waybar/style.css.in" \
  > "$HOME/.config/waybar/style.css"
