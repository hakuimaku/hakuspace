#!/usr/bin/env bash

# Public compatibility facade for emoji menu.
# No args preserves the Classic picker or opens the Hikai Action Layer menu.
# Explicit commands expose the headless controller for non-interactive callers.

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
    printf 'emoji_menu.sh: required script not found: %s\n' "$name" >&2
    return 1
}

EMOJI_CTL="$(resolve_script emoji_ctl.sh ../backend/desktop/emoji_ctl.sh)" || exit 1
LAUNCHER_ROFI="$(resolve_script launcher_rofi.sh ../frontend/classic/launcher_rofi.sh)" || exit 1
HAKU_BACKEND_LIB="$(resolve_script haku_backend_lib.sh ../lib/haku_backend_lib.sh)" || exit 1
# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

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
