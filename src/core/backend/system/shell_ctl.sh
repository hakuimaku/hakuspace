#!/usr/bin/env bash

# Headless login-shell controller.
# Owns supported-shell discovery, /etc/shells registration and chsh mutation.
# It never opens a picker or credential UI.

set -uo pipefail

SUPPORTED_SHELLS=(fish zsh)
AUTH_REQUIRED=77

usage() {
    cat <<'EOF_HELP'
Usage: shell_ctl.sh <COMMAND> [ARGS]

Commands:
    list [--json]           List installed supported shells
    current                 Print the current login-shell path
    set <SHELL_ID|PATH>     Set the login shell and print its resolved path
    -h, --help              Show this help message

Non-interactive authorization:
    If root authorization is required and cached sudo credentials are not
    available, `set` exits 77. A frontend may retry with
    HAKUSPACE_SUDO_STDIN=1 and provide one sudo password line on stdin.
EOF_HELP
}

fail() {
    printf 'shell_ctl.sh: %s\n' "$*" >&2
    return 1
}

is_nixos() {
    [[ -e /etc/NIXOS ]] && return 0
    ( . /etc/os-release 2>/dev/null; [[ ${ID:-} == nixos ]] )
}

same_bin() {
    [[ -n ${1:-} && -n ${2:-} ]] || return 1
    [[ $(readlink -f "$1" 2>/dev/null) == "$(readlink -f "$2" 2>/dev/null)" ]]
}

current_shell() {
    local user
    user=$(id -un) || return 1
    getent passwd "$user" | awk -F: 'NR == 1 { print $7 }'
}

find_shell_path() {
    local value=$1 bin line

    if [[ $value == */* ]]; then
        [[ -x $value ]] || return 1
        bin=$value
    else
        case "$value" in
            fish|zsh) ;;
            *) return 1 ;;
        esac
        bin=$(command -v "$value" 2>/dev/null) || return 1
    fi

    if grep -qxF "$bin" /etc/shells 2>/dev/null; then
        printf '%s\n' "$bin"
        return 0
    fi

    while IFS= read -r line; do
        [[ $line == /* ]] || continue
        if same_bin "$line" "$bin"; then
            printf '%s\n' "$line"
            return 0
        fi
    done < /etc/shells

    printf '%s\n' "$bin"
}

shell_id_for_path() {
    local path=$1 name candidate
    for name in "${SUPPORTED_SHELLS[@]}"; do
        candidate=$(command -v "$name" 2>/dev/null) || continue
        if same_bin "$candidate" "$path"; then
            printf '%s\n' "$name"
            return 0
        fi
    done
    basename "$path"
}

json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

list_shells() {
    local json=0
    if [[ ${1:-} == --json ]]; then
        json=1
        shift
    fi
    [[ $# -eq 0 ]] || {
        printf 'shell_ctl.sh: list accepts only --json.\n' >&2
        return 2
    }

    local current name path first=1 is_current
    current=$(current_shell) || return 1

    if (( json )); then
        printf '['
    fi

    for name in "${SUPPORTED_SHELLS[@]}"; do
        path=$(find_shell_path "$name" 2>/dev/null) || continue
        is_current=false
        same_bin "$path" "$current" && is_current=true

        if (( json )); then
            (( first )) || printf ','
            printf '{"id":"%s","path":"%s","current":%s}' \
                "$(json_escape "$name")" "$(json_escape "$path")" "$is_current"
            first=0
        else
            printf '%s\t%s\t%s\n' "$name" "$path" "$is_current"
        fi
    done

    if (( json )); then
        printf ']\n'
    fi
}

authorize_interactive_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        printf 'shell_ctl.sh: root authorization is required but sudo is unavailable.\n' >&2
        return 1
    }

    # Direct backend/facade use from a terminal owns terminal authentication.
    # Never open Rofi here; let sudo prompt on the controlling TTY.
    sudo -v
}

authorize_noninteractive_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        printf 'shell_ctl.sh: root authorization is required but sudo is unavailable.\n' >&2
        return "$AUTH_REQUIRED"
    }

    if sudo -n true >/dev/null 2>&1; then
        return 0
    fi

    if [[ ${HAKUSPACE_SUDO_STDIN:-0} == 1 ]]; then
        local password
        IFS= read -r password || password=''
        if [[ -z $password ]] || ! printf '%s\n' "$password" | sudo -S -p '' -v >/dev/null 2>&1; then
            printf 'shell_ctl.sh: authorization failed.\n' >&2
            return "$AUTH_REQUIRED"
        fi
        unset password
        return 0
    fi

    printf 'shell_ctl.sh: authorization required.\n' >&2
    return "$AUTH_REQUIRED"
}

run_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

set_shell() {
    [[ $# -eq 1 ]] || {
        printf 'shell_ctl.sh: set requires exactly one shell id or path.\n' >&2
        return 2
    }

    if is_nixos; then
        fail 'NixOS detected - set users.users.<name>.shell in the NixOS configuration instead.'
        return 1
    fi

    command -v chsh >/dev/null 2>&1 || { fail 'missing dependency: chsh'; return 1; }

    local requested=$1 new current user needs_registration=0 needs_change=0
    new=$(find_shell_path "$requested") || {
        fail "unsupported or unavailable shell: $requested"
        return 1
    }
    current=$(current_shell) || { fail 'could not read current login shell'; return 1; }
    user=$(id -un) || return 1

    grep -qxF "$new" /etc/shells 2>/dev/null || needs_registration=1
    same_bin "$new" "$current" || needs_change=1

    # Authentication policy is intentionally split by launch context:
    # - terminal/direct backend call: authenticate in the terminal with sudo;
    # - non-interactive/Rofi call: never prompt here, return 77 so the Classic
    #   frontend can own its Rofi password dialog and retry through stdin.
    if [[ $EUID -ne 0 && ( $needs_registration -eq 1 || $needs_change -eq 1 ) ]]; then
        if [[ -t 0 && -t 1 ]]; then
            authorize_interactive_root || return $?
        else
            authorize_noninteractive_root || return $?
        fi
    fi

    if (( needs_registration )); then
        if [[ $EUID -eq 0 ]]; then
            printf '%s\n' "$new" >> /etc/shells || return 1
        else
            run_root sh -c 'printf "%s\\n" "$1" >> /etc/shells' _ "$new" || return 1
        fi
    fi

    if (( needs_change )); then
        if [[ $EUID -eq 0 ]]; then
            chsh -s "$new" "$user" >&2 || return 1
        else
            run_root chsh -s "$new" "$user" >&2 || return 1
        fi
    fi

    printf '%s\n' "$new"
}

case "${1:-}" in
    list)
        shift
        list_shells "$@"
        ;;
    current)
        shift
        [[ $# -eq 0 ]] || { printf 'shell_ctl.sh: current accepts no arguments.\n' >&2; exit 2; }
        current_shell
        ;;
    set)
        shift
        set_shell "$@"
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'shell_ctl.sh: unknown command: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
