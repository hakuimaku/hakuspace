#!/bin/sh
set -eu
envsubst '${FONT_FAMILY} ${FONT_SIZE}' \
  < "$HOME/.config/hypr/hyprlock.conf.in" \
  > "$HOME/.config/hypr/hyprlock.conf"