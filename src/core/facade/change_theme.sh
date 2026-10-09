#!/usr/bin/env bash

# Public compatibility facade for theme changes.
# No-arg behavior remains the Classic menu. Explicit mutations are delegated to
# the headless theme_ctl.sh API so future Hikai UI can use the same backend.

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
    printf 'change_theme.sh: required script not found: %s\n' "$name" >&2
    return 1
}

THEME_CTL="$(resolve_script theme_ctl.sh ../backend/theme/theme_ctl.sh)" || exit 1
THEME_ROFI="$(resolve_script theme_rofi.sh ../frontend/classic/theme_rofi.sh)" || exit 1

print_help() {
    cat <<'EOF_HELP'
Usage: change_theme.sh [OPTION]
Open the Classic theme menu or mutate theme state explicitly.

Options:
    --accent HEX        Set accent color explicitly
    --font NAME         Set font family explicitly
    --size PX           Set font size explicitly
    --status            Print current theme state
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$THEME_ROFI" menu
        ;;
    --accent)
        exec "$THEME_CTL" set-accent "${2:-}"
        ;;
    --font)
        exec "$THEME_CTL" set-font "${2:-}"
        ;;
    --size)
        exec "$THEME_CTL" set-size "${2:-}"
        ;;
    --status)
        exec "$THEME_CTL" status
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
