#!/usr/bin/env bash

# Public compatibility facade for presentation-theme switching.
# No-arg behavior remains the Classic picker; explicit commands are headless.

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
    printf 'rofi_theme_switcher.sh: required script not found: %s\n' "$name" >&2
    return 1
}

ROFI_THEME_CTL="$(resolve_script rofi_theme_ctl.sh ../backend/theme/rofi_theme_ctl.sh)" || exit 1
ROFI_THEME_ROFI="$(resolve_script rofi_theme_rofi.sh ../frontend/classic/rofi_theme_rofi.sh)" || exit 1

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
