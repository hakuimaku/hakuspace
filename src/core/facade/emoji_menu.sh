#!/usr/bin/env bash

# Public compatibility facade for emoji menu.
# No args preserves the Classic picker or opens the Hikai Action Layer menu.
# Explicit commands expose the headless controller for non-interactive callers.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
EMOJI_CTL="$HAKU_BIN_DIR/emoji_ctl.sh"
LAUNCHER_ROFI="$HAKU_BIN_DIR/launcher_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: emoji_menu.sh [OPTION]

No arguments:
    Classic             Open the Classic Rofi emoji picker
    Hikai               Open the native centered Emoji Action Layer menu

Headless API:
    --list                          Print raw emoji database rows
    --history                       Print recent emojis from cache
    --copy [EMOJI]                  Copy EMOJI into clipboard; stdin when omitted

Options:
    -h, --help                      Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$LAUNCHER_ROFI" emoji
        fi
        haku_qs_ipc actionMenu openDefault emoji
        ;;
    --list)
        shift
        exec "$EMOJI_CTL" list "$@"
        ;;
    --history)
        shift
        exec "$EMOJI_CTL" history "$@"
        ;;
    --copy)
        shift
        if "$EMOJI_CTL" copy "$@"; then
            notify-send "Emoji" "Copied to clipboard" -t 2000
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'emoji_menu.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
