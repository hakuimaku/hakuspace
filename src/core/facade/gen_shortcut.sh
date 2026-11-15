#!/usr/bin/env bash

# Public compatibility facade for desktop shortcut operations.
# Classic picker UI is isolated in shortcut_rofi.sh; discovery/mutations live
# in the headless shortcut_ctl.sh backend.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
SHORTCUT_CTL="$HAKU_BIN_DIR/shortcut_ctl.sh"

usage() {
    cat <<'EOF_HELP'
Shortcut Generator Script
Generate if matching shortcuts exist in system directories.
Usage: gen_shortcut.sh [options]

Compatibility:
    <AppName> <ExecPath> [IconPath]   Create a custom shortcut
    -a, -add, --add <KeywordOrPath>   Find and copy matching shortcuts to Desktop
    -m, --menu                        Select and add a shortcut with the active backend
    -q, --query [Keyword]             List available shortcuts with legacy summary

Headless API:
    --list [Keyword]                  Print matching .desktop paths only
    --list-json [Keyword]             Print native picker metadata
    --create <AppName> <Exec> [Icon]  Create a custom shortcut explicitly

Options:
    -h, --help                        Show this help message
EOF_HELP
}

legacy_query() {
    local keyword="${1:-}" pattern
    local -a matches=()
    if [[ $keyword == *.desktop ]]; then
        pattern="$keyword"
    else
        pattern="*${keyword}*.desktop"
    fi

    mapfile -t matches < <("$SHORTCUT_CTL" list "$keyword")
    printf "Searching for '%s' in system directories...\n" "$pattern"
    printf '%s\n' '---------------------------------------------------'
    if [[ ${#matches[@]} -gt 0 ]]; then
        printf '%s\n' "${matches[@]}"
    fi
    printf '%s\n' '---------------------------------------------------'
    printf 'Total matching applications found: %d\n' "${#matches[@]}"
}

case "${1:-}" in
    -h|--help)
        usage
        ;;
    -m|--menu)
        shift
        [[ $# -eq 0 ]] || { printf 'gen_shortcut.sh: --menu accepts no arguments.\n' >&2; exit 2; }
        # shellcheck source=/dev/null
        source "$HAKU_BIN_DIR/haku_backend_lib.sh" || exit 1
        if haku_qs_mode; then
            haku_qs_ipc actionMenu openDefault shortcut
        else
            exec "$HAKU_BIN_DIR/shortcut_rofi.sh"
        fi
        ;;
    -q|--query)
        shift
        [[ $# -le 1 ]] || { printf 'gen_shortcut.sh: --query accepts at most one keyword.\n' >&2; exit 2; }
        legacy_query "${1:-}"
        ;;
    --list)
        shift
        exec "$SHORTCUT_CTL" list "$@"
        ;;
    --list-json)
        shift
        exec "$SHORTCUT_CTL" list-json "$@"
        ;;
    -a|-add|--add)
        shift
        if [[ $# -eq 0 ]]; then
            printf 'Error: Missing target for adding.\n' >&2
            printf 'Usage: gen_shortcut.sh -a <KeywordOrPath>\n' >&2
            exit 1
        fi
        exec "$SHORTCUT_CTL" add "$@"
        ;;
    --create)
        shift
        exec "$SHORTCUT_CTL" create "$@"
        ;;
    '')
        printf 'Error: Missing arguments.\n' >&2
        printf 'Usage: -h|--help for more options.\n' >&2
        exit 1
        ;;
    *)
        if [[ $# -lt 2 ]]; then
            printf 'Error: Missing arguments.\n' >&2
            printf 'Usage: -h|--help for more options.\n' >&2
            exit 1
        fi
        exec "$SHORTCUT_CTL" create "$@"
        ;;
esac
