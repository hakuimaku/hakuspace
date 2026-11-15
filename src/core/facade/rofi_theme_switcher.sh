#!/usr/bin/env bash

# Public compatibility facade for presentation-theme switching.
# No-arg behavior remains the Classic picker; explicit commands are headless.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
ROFI_THEME_CTL="$HAKU_BIN_DIR/rofi_theme_ctl.sh"
ROFI_THEME_ROFI="$HAKU_BIN_DIR/rofi_theme_rofi.sh"

print_help() {
    cat <<'EOF_HELP'
Usage: rofi_theme_switcher.sh [OPTION]
Open the Classic theme picker or use the headless theme-selection API.

Options:
    --list              List available theme ids
    --current           Print current theme id
    --set THEME_ID      Select an explicit theme id
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$ROFI_THEME_ROFI" menu
        ;;
    --list|list)
        exec "$ROFI_THEME_CTL" list
        ;;
    --current|current)
        exec "$ROFI_THEME_CTL" current
        ;;
    --set|set)
        exec "$ROFI_THEME_CTL" set "${2:-}"
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
