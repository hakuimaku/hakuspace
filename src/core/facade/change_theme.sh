#!/usr/bin/env bash

# Public compatibility facade for theme changes.
# No-arg behavior remains the Classic menu. Explicit mutations are delegated to
# the headless theme_ctl.sh API so future Hikai UI can use the same backend.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
THEME_CTL="$HAKU_BIN_DIR/theme_ctl.sh"
THEME_ROFI="$HAKU_BIN_DIR/theme_rofi.sh"

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
