#!/usr/bin/env bash

# Headless power/session action controller.
# Presentation and action selection belong in frontend/classic.

set -u
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: power_ctl.sh <COMMAND>

Commands:
    list        Print stable action IDs, one per line
    suspend     Suspend the system
    reboot      Reboot the system
    poweroff    Power off the system
    hibernate   Hibernate the system
    lock        Lock the current session
    logout      Start the safe session-exit confirmation flow
    -h, --help  Show this help message
EOF_HELP
}

list_actions() {
    printf '%s\n' suspend reboot poweroff hibernate lock logout
}

require_no_extra_args() {
    if [[ $# -ne 0 ]]; then
        printf 'power_ctl.sh: this command does not accept extra arguments.\n' >&2
        return 2
    fi
}

command_name="${1:-}"
if [[ -n "$command_name" ]]; then
    shift
fi

case "$command_name" in
    list)
        require_no_extra_args "$@" || exit $?
        list_actions
        ;;
    suspend)
        require_no_extra_args "$@" || exit $?
        exec systemctl suspend
        ;;
    reboot)
        require_no_extra_args "$@" || exit $?
        exec systemctl reboot
        ;;
    poweroff)
        require_no_extra_args "$@" || exit $?
        exec systemctl poweroff
        ;;
    hibernate)
        require_no_extra_args "$@" || exit $?
        exec systemctl hibernate
        ;;
    lock)
        require_no_extra_args "$@" || exit $?
        exec "$HAKU_BIN_DIR/lock.sh"
        ;;
    logout)
        require_no_extra_args "$@" || exit $?
        # Keep logout behind the stable public facade so Classic confirmation
        # remains the default interactive behavior. Headless callers that truly
        # intend immediate cleanup can invoke session_exit_ctl.sh execute.
        exec "$HAKU_BIN_DIR/exit.sh"
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'power_ctl.sh: unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac
