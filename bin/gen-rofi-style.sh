#!/bin/sh
set -eu
envsubst < "$HOME/.config/rofi/config.rasi.in" > "$HOME/.config/rofi/config.rasi"
envsubst < "$HOME/.config/rofi/mytheme.rasi.in" > "$HOME/.config/rofi/mytheme.rasi"