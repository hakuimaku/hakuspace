#!/usr/bin/env bash

# Public compatibility facade for login-shell switching.
# Supports both:
# 1. Direct terminal mode: toggles/switches shells interactively in terminal with terminal auth.
# 2. Global switcher mode: opens layer (Rofi / Quickshell), layer auth, and restart session prompt.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2" candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'shell_switcher.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SHELL_CTL="$(resolve_script shell_ctl.sh ../backend/system/shell_ctl.sh)" || exit 1
SHELL_ROFI="$(resolve_script shell_rofi.sh ../frontend/classic/shell_rofi.sh)" || exit 1
HAKU_BACKEND_LIB="$(resolve_script haku_backend_lib.sh ../lib/haku_backend_lib.sh)" || exit 1

# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

usage() {
    cat <<'EOF_HELP'
Usage: shell_switcher.sh [OPTION] [SHELL]

Modes:
    Terminal Mode:
        shell_switcher.sh            In a terminal: toggle between supported shells (fish <-> zsh)
        shell_switcher.sh <SHELL>    Switch directly to <SHELL> in terminal
        --terminal, -t [SHELL]       Force terminal mode
        --toggle, -2                 Toggle between the 2 supported shells

    Global Switcher (Layer Mode):
        shell_switcher.sh            Outside a terminal (e.g. HakuMenu/keybind): open layer switcher
        --global, -g                 Force global layer switcher (Rofi / Quickshell)
        --print                      Pick shell via layer and print its path

    Headless API:
        --list [--json]              List installed supported shells
        --current                    Print current login-shell path
        --set <SHELL_ID|PATH>        Set shell explicitly

Options:
    --no-exec                        In terminal mode: do not enter new shell immediately
    -h, --help                       Show this help message
EOF_HELP
}

run_terminal_mode() {
    local target=""
    local no_exec=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-exec)
                no_exec=1
                shift
                ;;
            *)
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    local current_path current_id resolved
    current_path=$("$SHELL_CTL" current) || {
        printf 'shell_switcher.sh: failed to determine current shell.\n' >&2
        return 1
    }
    current_id=$(basename "$current_path")

    # If target is empty, toggle between the 2 supported shells (fish <-> zsh)
    if [[ -z "$target" ]]; then
        if [[ "$current_id" == "zsh" ]]; then
            target="fish"
        elif [[ "$current_id" == "fish" ]]; then
            target="zsh"
        else
            target="fish"
        fi
    fi

    if [[ "$current_id" == "$target" ]]; then
        printf 'Current login shell is already %s (%s).\n' "$current_id" "$current_path"
        return 0
    fi

    printf 'Changing login shell: %s -> %s\n' "$current_id" "$target"

    # In terminal mode, authenticate via sudo interactively if required
    if [[ $EUID -ne 0 ]] && ! sudo -n true >/dev/null 2>&1; then
        sudo -v || {
            printf 'shell_switcher.sh: terminal authorization failed.\n' >&2
            return 1
        }
    fi

    resolved=$("$SHELL_CTL" set "$target") || {
        printf 'shell_switcher.sh: failed to change shell to %s.\n' "$target" >&2
        return $?
    }

    [[ -n "$resolved" ]] || {
        printf 'shell_switcher.sh: backend returned no shell path.\n' >&2
        return 1
    }

    printf 'Successfully changed login shell to %s (%s).\n' "$target" "$resolved"
    printf 'Note: Session restart (logout/reboot) is required for system-wide effect.\n'

    if (( no_exec == 0 )); then
        printf 'Entering %s now...\n' "$target"
        exec env SHELL="$resolved" "$resolved"
    fi
}

case "${1:-}" in
    '')
        if [[ -t 0 && -t 1 ]]; then
            run_terminal_mode
        else
            if ! haku_backend_is "classic" && haku_qs_alive; then
                haku_qs_ipc actionMenu openDefault shell
            else
                exec "$SHELL_ROFI"
            fi
        fi
        ;;
    --global|-g|--gui|--layer)
        shift
        if ! haku_backend_is "classic" && haku_qs_alive; then
            haku_qs_ipc actionMenu openDefault shell
        else
            exec "$SHELL_ROFI" "$@"
        fi
        ;;
    --terminal|-t)
        shift
        run_terminal_mode "$@"
        ;;
    --toggle|-2)
        shift
        run_terminal_mode "" "$@"
        ;;
    --no-exec)
        run_terminal_mode "$@"
        ;;
    --print)
        shift
        [[ $# -eq 0 ]] || { printf 'shell_switcher.sh: --print accepts no arguments.\n' >&2; exit 2; }
        exec "$SHELL_ROFI" --print
        ;;
    --list)
        shift
        exec "$SHELL_CTL" list "$@"
        ;;
    --current)
        shift
        exec "$SHELL_CTL" current "$@"
        ;;
    --set)
        shift
        if [[ -t 0 && -t 1 ]]; then
            resolved=$("$SHELL_CTL" set "$@") || exit $?
            [[ -n $resolved ]] || { printf 'shell_switcher.sh: backend returned no shell path.\n' >&2; exit 1; }
            exec env SHELL="$resolved" "$resolved"
        fi
        exec "$SHELL_CTL" set "$@"
        ;;
    fish|zsh|/*)
        # Direct shell name or path passed
        if [[ -t 0 && -t 1 ]]; then
            run_terminal_mode "$@"
        else
            exec "$SHELL_CTL" set "$@"
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'shell_switcher.sh: unknown option or argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
