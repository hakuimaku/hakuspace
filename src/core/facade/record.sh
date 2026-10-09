#!/usr/bin/env bash

# Public compatibility facade for screen recording.
# No args preserves the old keybind behavior: stop when active, otherwise open
# the Classic picker. Explicit commands provide a headless API for Hikai.

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
    printf 'record.sh: required script not found: %s\n' "$name" >&2
    return 1
}

RECORD_CTL="$(resolve_script record_ctl.sh ../backend/media/record_ctl.sh)" || exit 1
RECORD_ROFI="$(resolve_script record_rofi.sh ../frontend/classic/record_rofi.sh)" || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: record.sh [OPTION]

Compatibility:
    record.sh                         Stop active recording, otherwise open Classic picker

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
        exec "$RECORD_ROFI"
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
