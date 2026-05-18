#!/bin/sh
set -eu
envsubst < "$HOME/.config/kitty/kitty.conf.in" > "$HOME/.config/kitty/kitty.conf"