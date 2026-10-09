#!/bin/sh
set -eu
envsubst '${FONT_FAMILY} ${FONT_SIZE}' \
  < "$HOME/.config/swaync/style.css.in" \
  > "$HOME/.config/swaync/style.css"