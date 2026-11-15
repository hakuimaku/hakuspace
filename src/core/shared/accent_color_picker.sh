#!/usr/bin/env bash

# Public color-picker helper. The picker remains presentation; canonical theme
# mutation/render/apply is delegated to theme_ctl.sh.

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
THEME_CTL="$HAKU_BIN_DIR/theme_ctl.sh"

if ! command -v hyprpicker >/dev/null 2>&1; then
    echo "hyprpicker is not installed."
    notify-send "hyprpicker is not installed" "Please install hyprpicker to pick a color" 2>/dev/null || true
    exit 1
fi

sleep 0.5
COLOR="$(hyprpicker)"
[[ -z "$COLOR" ]] && exit 0

exec "$THEME_CTL" set-accent "$COLOR"
