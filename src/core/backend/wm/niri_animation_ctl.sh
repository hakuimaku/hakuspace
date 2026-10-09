#!/usr/bin/env bash

# Headless Niri animation controller.
# Owns KDL discovery/state/mutation only; picker UI belongs in frontend/classic.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source_core_lib() {
    local name="$1"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/../../lib/$name" \
        "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            # shellcheck source=/dev/null
            source "$candidate"
            return 0
        fi
    done
    printf 'niri_animation_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_theme.sh || exit 1

ANIM_FILE="${HAKUSPACE_NIRI_ANIMATION_FILE:-$THEME_ROOT/niri-animation.kdl}"
MARKER_RE='^[[:space:]]*//[[:space:]]*[A-Z][A-Za-z0-9]*-[A-Za-z0-9_]+[[:space:]]*$'

fail() {
    printf 'niri_animation_ctl.sh: %s\n' "$*" >&2
    return 1
}

require_niri() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *"niri"* && "${NIRI_BYPASS:-}" != "1" ]]; then
        fail "Niri is currently not in use."
        return 1
    fi
}

require_file() {
    [[ -f "$ANIM_FILE" ]] || { fail "niri-animation.kdl not found: $ANIM_FILE"; return 1; }
}

# Output: <ModeKey>\t<Option>\t<active 0|1>, preserving KDL marker order.
parse_entries() {
    awk -v re="$MARKER_RE" '
        $0 ~ re {
            tag = $0
            sub(/^[[:space:]]*\/\/[[:space:]]*/, "", tag)
            sub(/[[:space:]]*$/, "", tag)
            pending = 1
            next
        }
        pending {
            pending = 0
            i = index(tag, "-")
            active = ($0 ~ /^[[:space:]]*\/-/) ? 0 : 1
            print substr(tag, 1, i - 1) "\t" substr(tag, i + 1) "\t" active
        }
    ' "$ANIM_FILE"
}

validate_entries() {
    local count
    count="$(parse_entries | awk 'END { print NR + 0 }')"
    (( count > 0 )) || { fail "no '// <Mode>-<Option>' markers in $ANIM_FILE"; return 1; }
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

list_entries_json() {
    local mode option active comma=""
    printf '['
    while IFS=$'\t' read -r mode option active; do
        printf '%s{"mode":"%s","option":"%s","active":%s}' \
            "$comma" "$(json_escape "$mode")" "$(json_escape "$option")" \
            "$([[ "$active" == 1 ]] && printf true || printf false)"
        comma=','
    done < <(parse_entries)
    printf ']\n'
}

list_entries() {
    case "${1:-}" in
        '') parse_entries ;;
        --json) list_entries_json ;;
        *) fail "list accepts only --json"; return 2 ;;
    esac
}

get_active() {
    local requested_mode="${1:-}"
    local mode option active found_mode=0 active_count=0 active_option=""
    [[ -n "$requested_mode" ]] || { fail "get requires a mode"; return 2; }

    while IFS=$'\t' read -r mode option active; do
        [[ "$mode" == "$requested_mode" ]] || continue
        found_mode=1
        if [[ "$active" == 1 ]]; then
            active_count=$((active_count + 1))
            active_option="$option"
        fi
    done < <(parse_entries)

    (( found_mode )) || { fail "unknown mode: $requested_mode"; return 2; }
    (( active_count == 1 )) || {
        fail "mode $requested_mode has $active_count active options; expected exactly 1"
        return 1
    }
    printf '%s\n' "$active_option"
}

set_active() {
    local requested_mode="${1:-}" requested_option="${2:-}"
    local mode option active found_mode=0 found_option=0 target tmp
    [[ -n "$requested_mode" && -n "$requested_option" ]] || {
        fail "set requires <mode> <option-id>"
        return 2
    }

    while IFS=$'\t' read -r mode option active; do
        [[ "$mode" == "$requested_mode" ]] || continue
        found_mode=1
        [[ "$option" == "$requested_option" ]] && found_option=1
    done < <(parse_entries)

    (( found_mode )) || { fail "unknown mode: $requested_mode"; return 2; }
    (( found_option )) || { fail "unknown option: $requested_mode-$requested_option"; return 2; }

    target="$(readlink -f -- "$ANIM_FILE")"
    tmp="$(mktemp "${target}.XXXXXX")"

    if ! awk -v re="$MARKER_RE" -v wanted_mode="$requested_mode" -v wanted_option="$requested_option" '
        $0 ~ re {
            tag = $0
            sub(/^[[:space:]]*\/\/[[:space:]]*/, "", tag)
            sub(/[[:space:]]*$/, "", tag)
            i = index(tag, "-")
            mode = substr(tag, 1, i - 1)
            option = substr(tag, i + 1)
            pending = 1
            print
            next
        }
        pending {
            pending = 0
            if (mode == wanted_mode) {
                if (option == wanted_option) {
                    if (match($0, /^[[:space:]]*\/-/))
                        $0 = substr($0, 1, RLENGTH - 2) substr($0, RLENGTH + 1)
                } else if ($0 !~ /^[[:space:]]*\/-/) {
                    match($0, /^[[:space:]]*/)
                    $0 = substr($0, 1, RLENGTH) "/-" substr($0, RLENGTH + 1)
                }
            }
        }
        { print }
    ' "$target" > "$tmp"; then
        rm -f -- "$tmp"
        fail "failed to update $target"
        return 1
    fi

    chmod --reference="$target" -- "$tmp"
    mv -- "$tmp" "$target"
}

print_help() {
    cat <<'EOF_HELP'
Usage: niri_animation_ctl.sh COMMAND [ARG...]
Headless Niri animation control API.

Commands:
    list [--json]       List mode/option/active state
    get MODE            Print the active option id for MODE
    set MODE OPTION     Select OPTION for MODE
    -h, --help          Show this help message
EOF_HELP
}

main() {
    case "${1:-}" in
        -h|--help)
            print_help
            return 0
            ;;
    esac

    require_niri || return $?
    require_file || return $?
    validate_entries || return $?

    case "${1:-}" in
        list|--list)
            shift
            list_entries "${1:-}"
            ;;
        get|--get)
            get_active "${2:-}"
            ;;
        set|--set)
            set_active "${2:-}" "${3:-}"
            ;;
        '')
            print_help >&2
            return 2
            ;;
        *)
            fail "invalid command: $1"
            return 2
            ;;
    esac
}

main "$@"
