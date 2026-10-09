#!/usr/bin/env bash

# Public compatibility facade for clipboard history.
# No args preserves the Classic picker. Explicit commands expose the headless
# history controller for non-interactive callers.

set -u
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
    printf 'clipboard_menu.sh: required script not found: %s\n' "$name" >&2
    return 1
}

CLIPBOARD_CTL="$(resolve_script clipboard_ctl.sh ../backend/clipboard/clipboard_ctl.sh)" || exit 1
CLIPBOARD_ROFI="$(resolve_script clipboard_rofi.sh ../frontend/classic/clipboard_rofi.sh)" || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: clipboard_menu.sh [OPTION]

Compatibility:
    clipboard_menu.sh               Open the Classic clipboard picker
    --wipe                          Clear all clipboard history

Headless API:
    --ensure-watchers               Ensure clipboard history watchers are running
    --list                          Print raw cliphist history rows
    --copy [ENTRY]                  Copy one raw cliphist row; stdin when omitted

Options:
    -h, --help                      Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$CLIPBOARD_ROFI"
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
