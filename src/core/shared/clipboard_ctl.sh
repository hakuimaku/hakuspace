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
    preview [ENTRY]             Decode ENTRY to a cached preview file and print its path;
                                reads the raw cliphist row from stdin when omitted
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

preview_dir() {
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        printf '%s/hakuspace/clipboard-previews\n' "$XDG_RUNTIME_DIR"
    elif [[ -d "/run/user/$(id -u)" ]]; then
        printf '/run/user/%s/hakuspace/clipboard-previews\n' "$(id -u)"
    else
        printf '%s/hakuspace-%s/clipboard-previews\n' "${TMPDIR:-/tmp}" "$(id -u)"
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

preview_entry() {
    [[ $# -le 1 ]] || {
        printf 'clipboard_ctl.sh: preview accepts at most one ENTRY argument.\n' >&2
        return 2
    }
    require_command cliphist || return 1

    local entry
    if [[ $# -eq 1 ]]; then
        entry=$1
    else
        IFS= read -r entry || true
    fi
    [[ -n "$entry" ]] || return 1

    local entry_id=${entry%%$'\t'*}
    entry_id=${entry_id//[[:space:]]/}
    if [[ -z "$entry_id" || "$entry_id" == "$entry" || ! "$entry_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
        return 1
    fi

    local cache_dir
    cache_dir=$(preview_dir)
    local out_file="$cache_dir/$entry_id"
    if [[ -s "$out_file" ]]; then
        printf '%s\n' "$out_file"
        return 0
    fi

    mkdir -p "$cache_dir" || return 1
    local tmp_file="$cache_dir/.${entry_id}.$$.tmp"
    if printf '%s\n' "$entry" | cliphist decode > "$tmp_file" && [[ -s "$tmp_file" ]]; then
        mv -f "$tmp_file" "$out_file" || {
            rm -f "$tmp_file"
            return 1
        }
        printf '%s\n' "$out_file"
        return 0
    fi

    rm -f "$tmp_file"
    return 1
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
    local status=$?
    rm -rf -- "$(preview_dir)" 2>/dev/null || true
    return "$status"
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
    preview)
        shift
        preview_entry "$@"
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
