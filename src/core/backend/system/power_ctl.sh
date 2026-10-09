#!/usr/bin/env bash

# Headless power/session action controller.
# Presentation and action selection belong in frontend/classic.

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
    printf 'power_ctl.sh: required script not found: %s\n' "$name" >&2
    return 1
}

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
        LOCK_SCRIPT="$(resolve_script lock.sh ../../sys/lock.sh)" || exit 1
        exec "$LOCK_SCRIPT"
        ;;
    logout)
        require_no_extra_args "$@" || exit $?
        # Keep logout behind the stable public facade so Classic confirmation
        # remains the default interactive behavior. Headless callers that truly
        # intend immediate cleanup can invoke session_exit_ctl.sh execute.
        EXIT_SCRIPT="$(resolve_script exit.sh ../../facade/exit.sh)" || exit 1
        exec "$EXIT_SCRIPT"
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
