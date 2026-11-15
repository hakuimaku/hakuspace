#!/usr/bin/env bash

# Public compatibility facade for the safe session-exit flow.
# Classic confirmation lives in exit_rofi.sh; cleanup/WM quit is headless.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
SESSION_EXIT_CTL="$HAKU_BIN_DIR/session_exit_ctl.sh"
EXIT_ROFI="$HAKU_BIN_DIR/exit_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: exit.sh [OPTION]

Interactive:
    Classic                 Show process report and ask for confirmation with Rofi
    Hikai                   Open native Exit layer with interactive process list

Headless API:
    --process-report        Print the side-effect-free process report
    --execute               Execute cleanup and quit the current WM immediately
    -h, --help              Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$EXIT_ROFI"
        fi
        haku_qs_ipc actionMenu openDefault exit
        ;;
    --process-report)
        shift
        exec "$SESSION_EXIT_CTL" process-report "$@"
        ;;
    --execute)
        shift
        exec "$SESSION_EXIT_CTL" execute "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'exit.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
