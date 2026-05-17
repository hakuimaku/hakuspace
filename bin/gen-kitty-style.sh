#!/bin/sh
set -eu
envsubst '${FONT_FAMILY} ${FONT_SIZE}' \
  < "$HOME/.config/kitty/kitty.conf.in" \
  > "$HOME/.config/kitty/kitty.conf"