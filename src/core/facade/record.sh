#!/usr/bin/env bash

# Public compatibility facade for screen recording.
# No args preserves the old keybind behavior: stop when active, otherwise open
# the Classic picker. Explicit commands provide a headless API for Hikai.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
RECORD_CTL="$HAKU_BIN_DIR/record_ctl.sh"
RECORD_ROFI="$HAKU_BIN_DIR/record_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: record.sh [OPTION]

Interactive:
    Classic                           Stop active recording, otherwise open Classic picker
    Hikai                             Stop active recording, otherwise open native Action Layer

Headless API:
    --status [--json]                 Show recorder state
    --list-modes [--json]             List stable recording mode IDs
    --list-sources [--json]           List physical microphone/source IDs
    --start MODE [--source ID]        Start an explicit recording mode
    --stop                            Stop the active recording
    -h, --help                        Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if [[ "$("$RECORD_CTL" status)" == recording ]]; then
            exec "$RECORD_CTL" stop
        fi
        if haku_backend_is "classic"; then
            exec "$RECORD_ROFI"
        fi
        haku_qs_ipc actionMenu openDefault record
        ;;
    --status)
        shift
        exec "$RECORD_CTL" status "$@"
        ;;
    --list-modes)
        shift
        exec "$RECORD_CTL" list-modes "$@"
        ;;
    --list-sources)
        shift
        exec "$RECORD_CTL" list-sources "$@"
        ;;
    --start)
        shift
        exec "$RECORD_CTL" start "$@"
        ;;
    --stop)
        shift
        exec "$RECORD_CTL" stop "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'record.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
