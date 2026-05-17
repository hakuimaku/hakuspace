#!/bin/sh
set -eu
envsubst '${FONT_FAMILY} ${FONT_SIZE}' \
  < "$HOME/.config/rofi/config.rasi.in" \
  > "$HOME/.config/rofi/config.rasi"
