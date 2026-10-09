#!/usr/bin/env bash

# Public compatibility facade for the safe session-exit flow.
# Classic confirmation lives in exit_rofi.sh; cleanup/WM quit is headless.

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
    printf 'exit.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SESSION_EXIT_CTL="$(resolve_script session_exit_ctl.sh ../backend/system/session_exit_ctl.sh)" || exit 1
EXIT_ROFI="$(resolve_script exit_rofi.sh ../frontend/classic/exit_rofi.sh)" || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: exit.sh [OPTION]

Classic compatibility:
    exit.sh                 Show process report and ask for confirmation

Headless API:
    --process-report        Print the side-effect-free process report
    --execute               Execute cleanup and quit the current WM immediately
    -h, --help              Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$EXIT_ROFI"
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
