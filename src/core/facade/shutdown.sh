#!/usr/bin/env bash

# Public compatibility facade for the power menu.
# Classic presentation lives in power_rofi.sh; explicit actions are headless.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
POWER_CTL="$HAKU_BIN_DIR/power_ctl.sh"
POWER_ROFI="$HAKU_BIN_DIR/power_rofi.sh"

usage() {
    cat <<'EOF_HELP'
Usage: shutdown.sh [OPTIONS]

Interactive:
    Classic                  Open the Classic power menu
    Hikai                    Open the native centered Power layer

Classic compatibility:
    -e, --extend <ARG...>    Pass placement arguments to the Classic menu
    -v, --vertical          Use the vertical shutdown theme

Headless API:
    --list                  Print stable action IDs
    --suspend               Suspend the system
    --reboot                Reboot the system
    --poweroff              Power off the system
    --hibernate             Hibernate the system
    --lock                  Lock the current session
    --logout                Start the existing safe session-exit flow
    -h, --help              Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$POWER_ROFI"
        fi
        haku_qs_ipc actionMenu openDefault power
        ;;
    -e|--extend|-v|--vertical)
        if haku_backend_is "classic"; then
            exec "$POWER_ROFI" "$@"
        fi
        haku_qs_ipc actionMenu openDefault power
        ;;
    --list)
        shift
        exec "$POWER_CTL" list "$@"
        ;;
    --suspend)
        shift
        exec "$POWER_CTL" suspend "$@"
        ;;
    --reboot)
        shift
        exec "$POWER_CTL" reboot "$@"
        ;;
    --poweroff)
        shift
        exec "$POWER_CTL" poweroff "$@"
        ;;
    --hibernate)
        shift
        exec "$POWER_CTL" hibernate "$@"
        ;;
    --lock)
        shift
        exec "$POWER_CTL" lock "$@"
        ;;
    --logout)
        shift
        exec "$POWER_CTL" logout "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'shutdown.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
