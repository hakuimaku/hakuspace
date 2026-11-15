#!/usr/bin/env bash

# Headless clipboard-history controller.
# Owns cliphist watcher lifecycle and explicit history actions.

set -uo pipefail

usage() {
    cat <<'EOF_HELP'
Usage: clipboard_ctl.sh <COMMAND> [ARGS]

Commands:
    ensure-watchers             Start text/image cliphist watchers when absent
    list                        Print cliphist history rows unchanged
    copy [ENTRY]                Decode ENTRY into the Wayland clipboard;
                                reads the raw cliphist row from stdin when omitted
    wipe                        Clear clipboard history
    -h, --help                  Show this help message
EOF_HELP
}

require_command() {
    local command_name=$1
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'clipboard_ctl.sh: missing dependency: %s\n' "$command_name" >&2
        return 1
    fi
}

ensure_watchers() {
    require_command wl-paste || return 1
    require_command cliphist || return 1

    # Preserve the existing lifecycle contract: if no wl-paste process exists,
    # start one text watcher and one image watcher backed by cliphist.
    if ! pgrep -x wl-paste >/dev/null 2>&1; then
        wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
        wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
    fi
}

list_history() {
    [[ $# -eq 0 ]] || {
        printf 'clipboard_ctl.sh: list accepts no arguments.\n' >&2
        return 2
    }
    require_command cliphist || return 1
    cliphist list
}

copy_entry() {
    [[ $# -le 1 ]] || {
        printf 'clipboard_ctl.sh: copy accepts at most one ENTRY argument.\n' >&2
        return 2
    }
    require_command cliphist || return 1
    require_command wl-copy || return 1

    if [[ $# -eq 1 ]]; then
        [[ -n "$1" ]] || return 0
        printf '%s\n' "$1" | cliphist decode | wl-copy
        return $?
    fi

    # stdin is the preferred contract because a cliphist row may contain tabs
    # or other preview characters that should not be re-parsed by this layer.
    cliphist decode | wl-copy
}

wipe_history() {
    [[ $# -eq 0 ]] || {
        printf 'clipboard_ctl.sh: wipe accepts no arguments.\n' >&2
        return 2
    }
    require_command cliphist || return 1
    cliphist wipe
}

case "${1:-}" in
    ensure-watchers)
        shift
        [[ $# -eq 0 ]] || {
            printf 'clipboard_ctl.sh: ensure-watchers accepts no arguments.\n' >&2
            exit 2
        }
        ensure_watchers
        ;;
    list)
        shift
        list_history "$@"
        ;;
    copy)
        shift
        copy_entry "$@"
        ;;
    wipe)
        shift
        wipe_history "$@"
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'clipboard_ctl.sh: unknown command: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
