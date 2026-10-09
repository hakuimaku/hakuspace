#!/usr/bin/env bash

# Public compatibility facade for the power menu.
# Classic presentation lives in power_rofi.sh; explicit actions are headless.

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
    printf 'shutdown.sh: required script not found: %s\n' "$name" >&2
    return 1
}

POWER_CTL="$(resolve_script power_ctl.sh ../backend/system/power_ctl.sh)" || exit 1
POWER_ROFI="$(resolve_script power_rofi.sh ../frontend/classic/power_rofi.sh)" || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: shutdown.sh [OPTIONS]

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
        exec "$POWER_ROFI"
        ;;
    -e|--extend|-v|--vertical)
        exec "$POWER_ROFI" "$@"
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
