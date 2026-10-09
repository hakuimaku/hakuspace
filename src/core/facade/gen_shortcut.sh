#!/usr/bin/env bash

# Public compatibility facade for desktop shortcut operations.
# Classic picker UI is isolated in shortcut_rofi.sh; discovery/mutations live
# in the headless shortcut_ctl.sh backend.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2" candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x $candidate || -f $candidate ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'gen_shortcut.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SHORTCUT_CTL="$(resolve_script shortcut_ctl.sh ../backend/desktop/shortcut_ctl.sh)" || exit 1
SHORTCUT_ROFI="$(resolve_script shortcut_rofi.sh ../frontend/classic/shortcut_rofi.sh)" || exit 1

usage() {
    cat <<'EOF_HELP'
Shortcut Generator Script
Generate if matching shortcuts exist in system directories.
Usage: gen_shortcut.sh [options]

Compatibility:
    <AppName> <ExecPath> [IconPath]   Create a custom shortcut
    -a, -add, --add <KeywordOrPath>   Find and copy matching shortcuts to Desktop
    -m, --menu                        Select and add a shortcut using Rofi
    -q, --query [Keyword]             List available shortcuts with legacy summary

Headless API:
    --list [Keyword]                  Print matching .desktop paths only
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
        exec "$SHORTCUT_ROFI"
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
