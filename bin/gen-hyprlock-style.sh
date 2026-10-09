#!/bin/sh
set -eu
envsubst < "$HOME/.config/hypr/hyprlock.conf.in" > "$HOME/.config/hypr/hyprlock.conf"