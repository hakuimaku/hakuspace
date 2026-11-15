#!/usr/bin/env bash

# Public compatibility facade for clipboard history.
# No args preserves the Classic picker. Explicit commands expose the headless
# history controller for non-interactive callers.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
CLIPBOARD_CTL="$HAKU_BIN_DIR/clipboard_ctl.sh"
CLIPBOARD_ROFI="$HAKU_BIN_DIR/clipboard_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: clipboard_menu.sh [OPTION]

No arguments:
    Classic             Open the Classic clipboard picker
    Hikai               Open the native centered Clipboard layer

Headless API:
    --wipe                          Clear all clipboard history
    --ensure-watchers               Ensure clipboard history watchers are running
    --list                          Print raw cliphist history rows
    --copy [ENTRY]                  Copy one raw cliphist row; stdin when omitted

Options:
    -h, --help                      Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$CLIPBOARD_ROFI"
        fi
        haku_qs_ipc actionMenu openDefault clipboard
        ;;
    --wipe)
        shift
        [[ $# -eq 0 ]] || {
            printf 'clipboard_menu.sh: --wipe accepts no arguments.\n' >&2
            exit 2
        }
        if "$CLIPBOARD_CTL" wipe; then
            notify-send "Clipboard" "Clear All History" -t 2000
        fi
        ;;
    --ensure-watchers)
        shift
        exec "$CLIPBOARD_CTL" ensure-watchers "$@"
        ;;
    --list)
        shift
        exec "$CLIPBOARD_CTL" list "$@"
        ;;
    --copy)
        shift
        if "$CLIPBOARD_CTL" copy "$@"; then
            notify-send "Clipboard" "Copied to clipboard" -t 2000
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'clipboard_menu.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
