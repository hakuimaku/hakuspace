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
HAKU_BACKEND_LIB="$(resolve_script haku_backend_lib.sh ../lib/haku_backend_lib.sh)" || exit 1

# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

print_help() {
    cat <<'EOF_HELP'
Usage: change_theme.sh [OPTION]
Manage appearance and themes.

No arguments:
    Classic             Open the Classic theme menu
    Hikai               Open the native centered Theme layer

Options:
    --accent HEX        Set accent color explicitly
    --font NAME         Set font family explicitly
    --size PX           Set font size explicitly
    --list-fonts        List installed monospace font families
    --status            Print current theme state
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$THEME_ROFI" menu
        fi
        haku_qs_ipc actionMenu openDefault theme
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
    --list-fonts)
        exec "$THEME_CTL" list-fonts
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
