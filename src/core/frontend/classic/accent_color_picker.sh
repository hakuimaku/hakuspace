#!/usr/bin/env bash

# Public color-picker helper. The picker remains presentation; canonical theme
# mutation/render/apply is delegated to theme_ctl.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_theme_ctl() {
    local candidate
    for candidate in \
        "$SCRIPT_DIR/theme_ctl.sh" \
        "$SCRIPT_DIR/../backend/theme/theme_ctl.sh" \
        "$HOME/.local/bin/theme_ctl.sh"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'accent_color_picker.sh: theme_ctl.sh not found.\n' >&2
    return 1
}

THEME_CTL="$(resolve_theme_ctl)" || exit 1

if ! command -v hyprpicker >/dev/null 2>&1; then
    echo "hyprpicker is not installed."
    notify-send "hyprpicker is not installed" "Please install hyprpicker to pick a color" 2>/dev/null || true
    exit 1
fi

sleep 0.5
COLOR="$(hyprpicker)"
[[ -z "$COLOR" ]] && exit 0

exec "$THEME_CTL" set-accent "$COLOR"
