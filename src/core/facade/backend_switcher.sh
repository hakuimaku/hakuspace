#!/usr/bin/env bash

# Public compatibility facade for shell backend selection and switching.
# Interactive mode routes Classic to Rofi and Hikai to the Action Layer;
# explicit subcommands delegate to the headless haku_backend.sh orchestrator.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
HAKU_BACKEND="$HAKU_BIN_DIR/haku_backend.sh"
BACKEND_ROFI="$HAKU_BIN_DIR/backend_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: backend_switcher.sh [OPTION]

Interactive:
    Classic                 Open the Classic Rofi backend selector
    Hikai                   Open the native centered Shell Backend layer

Headless API:
    set <classic|hikai>     Switch to the specified backend
    -t, --toggle            Toggle between classic and hikai
    -c, --check             Print active backend name
    --verify                Verify active backend health
    --recover               Recover to Classic backend
    -h, --help              Show this help message
EOF_HELP
}

open_menu() {
    if ! haku_backend_is "classic" && haku_qs_alive; then
        haku_qs_ipc actionMenu openDefault backend && return 0
    fi
    exec "$BACKEND_ROFI"
}

case "${1:-}" in
    ''|menu|--menu)
        open_menu
        ;;
    set|-t|--toggle|-c|--check|--verify|--recover)
        exec "$HAKU_BACKEND" "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'backend_switcher.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
