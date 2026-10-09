#!/usr/bin/env bash

# Public compatibility facade for login-shell switching.
# Classic picker/authentication UX is separate from the headless controller.

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

usage() {
    cat <<'EOF_HELP'
Usage: shell_switcher.sh [OPTION]

Compatibility:
    shell_switcher.sh                Open the Classic shell picker
    --print                          Pick/change shell and print its path

Headless API:
    --list [--json]                  List installed supported shells
    --current                        Print current login-shell path
    --set <SHELL_ID|PATH>            Set shell explicitly

Options:
    -h, --help                       Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$SHELL_ROFI"
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
            # Match the pre-split terminal UX: change the login shell, then
            # immediately enter the selected shell in this terminal.  A child
            # script cannot replace its parent shell, so this replaces the
            # facade process (the same nested-shell behavior as before).
            resolved=$("$SHELL_CTL" set "$@") || exit $?
            [[ -n $resolved ]] || { printf 'shell_switcher.sh: backend returned no shell path.\n' >&2; exit 1; }
            exec env SHELL="$resolved" "$resolved"
        fi
        exec "$SHELL_CTL" set "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'shell_switcher.sh: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac
