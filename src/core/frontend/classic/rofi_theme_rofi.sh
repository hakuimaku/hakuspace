#!/usr/bin/env bash

# Classic presentation-theme frontend. Owns picker UX only and delegates all
# discovery/current/set behavior to the headless controller.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'rofi_theme_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

ROFI_THEME_CTL="$(resolve_script rofi_theme_ctl.sh ../../backend/theme/rofi_theme_ctl.sh)" || exit 1

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
