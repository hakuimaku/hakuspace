#!/usr/bin/env bash

# Classic presentation-theme frontend. Owns picker UX only and delegates all
# discovery/current/set behavior to the headless controller.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
ROFI_THEME_CTL="$HAKU_BIN_DIR/rofi_theme_ctl.sh"

notify_error() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Rofi Theme Switcher" "$message"
    fi
}

open_picker() {
    local themes selected_theme
    themes="$("$ROFI_THEME_CTL" list)" || return $?

    if [[ -z "$themes" ]]; then
        printf 'No theme files found!\n'
        notify_error "No theme files found in default or user directory."
        return 1
    fi

    selected_theme="$(printf '%s\n' "$themes" | rofi -dmenu -p "Select Theme:" -theme option-menu.rasi -i)"
    [[ -z "$selected_theme" ]] && return 0

    printf 'Selected theme: %s\n' "$selected_theme"
    if ! "$ROFI_THEME_CTL" set "$selected_theme"; then
        notify_error "Failed to apply theme '$selected_theme'."
        return 1
    fi
}

print_help() {
    cat <<'EOF_HELP'
Usage: rofi_theme_rofi.sh [menu]
Classic picker frontend for presentation-theme selection.
EOF_HELP
}

case "${1:-menu}" in
    menu|--menu)
        open_picker
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
