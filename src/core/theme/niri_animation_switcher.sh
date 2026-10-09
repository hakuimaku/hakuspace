#!/usr/bin/env bash

# This script is part of the Niri theme system for HakuSpace
# Changing animation for Niri

# One rofi window with a mode switcher (Open | Close), options parsed from the KDL.
#   // WindowOpen-LeftTopCorner      <- marker: <Mode>-<Option>
#   window-open {                    <- line right below = the toggle target
#   /-window-open {                  <- "/-" (slashdash) = disabled
# Niri allows only ONE active window-open and ONE active window-close, so picking
# an option disables every block of that mode, then enables the picked one.
#
# Usage:
#   niri-animation-menu.sh                       launch rofi (modes built from the file)
#   niri-animation-menu.sh <ModeKey> [<Option>]  rofi script-mode handler (internal)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

set -euo pipefail

SELF="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"
ANIM_FILE="${THEME_ROOT}/niri-animation.kdl"
MARKER_RE='^[[:space:]]*//[[:space:]]*[A-Z][A-Za-z0-9]*-[A-Za-z0-9_]+[[:space:]]*$'

die() {
    printf 'niri-animation-menu: %s\n' "$*" >&2
    notify-send "Niri animation" "$*" || true
    exit 1
}

# Check if niri-animation.kdl exists
if [[ ! -f "$ANIM_FILE" ]]; then
    die "niri-animation.kdl not found in $THEME_ROOT"
fi

# Check if Niri is in use, the BYPASS check is for testing the script outside of Niri.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *"niri"* && "${NIRI_BYPASS:-}" != "1" ]]; then
    die "Niri is currently not in use. This script is intended to be used within the Niri environment."
fi

# Output: <ModeKey>\t<Option>\t<active 0|1> for each marker, in file order.
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

declare -a MODE_KEYS OPT_MODES OPT_NAMES OPT_ACTIVE

load_entries() {
    MODE_KEYS=(); OPT_MODES=(); OPT_NAMES=(); OPT_ACTIVE=()
    local m o a
    while IFS=$'\t' read -r m o a; do
        OPT_MODES+=("$m"); OPT_NAMES+=("$o"); OPT_ACTIVE+=("$a")
        [[ " ${MODE_KEYS[*]-} " == *" $m "* ]] || MODE_KEYS+=("$m")
    done < <(parse_entries)
    (( ${#MODE_KEYS[@]} )) || die "no '// <Mode>-<Option>' markers in $ANIM_FILE"
}

# apply <ModeKey> <Option>: comment all blocks of ModeKey, uncomment the chosen one.
apply() {
    local mode=$1 option=$2
    local target tmp
    target="$(readlink -f -- "$ANIM_FILE")"
    tmp="$(mktemp "${target}.XXXXXX")"

    awk -v re="$MARKER_RE" -v mode="$mode" -v option="$option" '
        $0 ~ re {
            tag = $0
            sub(/^[[:space:]]*\/\/[[:space:]]*/, "", tag)
            sub(/[[:space:]]*$/, "", tag)
            i = index(tag, "-")
            m = substr(tag, 1, i - 1)
            o = substr(tag, i + 1)
            pending = 1
            print
            next
        }
        pending {
            pending = 0
            if (m == mode) {
                if (o == option) {
                    # enable: drop "/-" after the indent
                    if (match($0, /^[[:space:]]*\/-/))
                        $0 = substr($0, 1, RLENGTH - 2) substr($0, RLENGTH + 1)
                } else if ($0 !~ /^[[:space:]]*\/-/) {
                    # disable: insert "/-" after the indent
                    match($0, /^[[:space:]]*/)
                    $0 = substr($0, 1, RLENGTH) "/-" substr($0, RLENGTH + 1)
                }
            }
        }
        { print }
    ' "$target" > "$tmp" || { rm -f -- "$tmp"; die "awk failed"; }

    chmod --reference="$target" -- "$tmp"
    mv -- "$tmp" "$target"
}

# Launcher: one rofi, one script-mode per ModeKey -> mode switcher tabs.
launch() {
    load_entries
    local modi="" k label self_q
    self_q="$(printf '%q' "$SELF")"
    for k in "${MODE_KEYS[@]}"; do
        label="${k#Window}"
        modi+="${modi:+,}${label}:${self_q} ${k}"
    done
    exec rofi -show "${MODE_KEYS[0]#Window}" -modi "$modi" -sidebar-mode -i
}

# Script-mode handler. No entry -> print the list; entry -> apply and close.
handle() {
    local mode=$1 entry=${2-}
    load_entries

    local i found=0 active=() n=0 names=()
    for i in "${!OPT_MODES[@]}"; do
        [[ ${OPT_MODES[i]} == "$mode" ]] || continue
        [[ ${OPT_ACTIVE[i]} == 1 ]] && active+=("$n")
        names+=("${OPT_NAMES[i]}")
        [[ ${OPT_NAMES[i]} == "$entry" ]] && found=1
        n=$((n + 1))
    done
    (( n )) || die "unknown mode: $mode"

    if [[ -z $entry ]]; then
        local act_csv
        act_csv="$(IFS=,; printf '%s' "${active[*]-}")"
        printf '\0prompt\x1f%s\n' "${mode#Window}"
        printf '\0no-custom\x1ftrue\n'
        [[ -n $act_csv ]] && printf '\0active\x1f%s\n' "$act_csv"
        printf '%s\n' "${names[@]}"
        return
    fi

    (( found )) || die "unknown option: $mode-$entry"
    apply "$mode" "$entry"
    command -v notify-send >/dev/null && notify-send "Niri animation" "${mode#Window}: $entry" || true
    # print nothing -> rofi closes
}

main() {
    [[ -f $ANIM_FILE ]] || die "not found: $ANIM_FILE"
    if (( $# == 0 )); then launch; else handle "$@"; fi
}

main "$@"