#!/usr/bin/env bash

# Classic Niri animation frontend. Owns Rofi mode/script-mode UX only and
# delegates all KDL state and mutation to niri_animation_ctl.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"

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
    printf 'niri_animation_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

NIRI_ANIMATION_CTL="$(resolve_script niri_animation_ctl.sh ../../backend/wm/niri_animation_ctl.sh)" || exit 1

notify_error() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Niri animation" "$message"
    fi
}

load_entries() {
    mapfile -t ENTRIES < <("$NIRI_ANIMATION_CTL" list)
    (( ${#ENTRIES[@]} > 0 )) || {
        printf 'niri_animation_rofi.sh: no animation entries found\n' >&2
        return 1
    }
}

mode_icon() {
    case "$1" in
        WindowOpen)  printf '󰐕\n' ;;
        WindowClose) printf '󰅖\n' ;;
        *)           printf '%s\n' "${1#Window}" ;;
    esac
}

launch() {
    load_entries
    local entry mode option active
    local -a modes=()
    local seen=" " modi="" self_q mode_id first_mode_id=""

    for entry in "${ENTRIES[@]}"; do
        IFS=$'\t' read -r mode option active <<< "$entry"
        if [[ "$seen" != *" $mode "* ]]; then
            modes+=("$mode")
            seen+="$mode "
        fi
    done

    self_q="$(printf '%q' "$SELF")"
    for mode in "${modes[@]}"; do
        case "$mode" in
            WindowOpen)  mode_id="open" ;;
            WindowClose) mode_id="close" ;;
            *)           mode_id="${mode#Window}" ;;
        esac
        [[ -n "$first_mode_id" ]] || first_mode_id="$mode_id"
        modi+="${modi:+,}${mode_id}:${self_q} handler ${mode}"
    done

    # Keep stable ASCII mode ids for Rofi itself, and override only their
    # visible sidebar labels. Using the Nerd glyph as the mode id is not
    # reliable across Rofi versions/themes and can fall back to Open/Close.
    exec rofi \
        -show "$first_mode_id" \
        -modi "$modi" \
        -display-open "$(mode_icon WindowOpen)" \
        -display-close "$(mode_icon WindowClose)" \
        -sidebar-mode -i
}

handle() {
    local mode="${1:-}" entry="${2:-}"
    local line row_mode option active found_mode=0 found_entry=0
    local -a names=() active_indices=()
    local index=0

    [[ -n "$mode" ]] || { printf 'niri_animation_rofi.sh: handler requires a mode\n' >&2; return 2; }
    load_entries

    for line in "${ENTRIES[@]}"; do
        IFS=$'\t' read -r row_mode option active <<< "$line"
        [[ "$row_mode" == "$mode" ]] || continue
        found_mode=1
        names+=("$option")
        [[ "$active" == 1 ]] && active_indices+=("$index")
        [[ -n "$entry" && "$option" == "$entry" ]] && found_entry=1
        index=$((index + 1))
    done

    (( found_mode )) || { printf 'niri_animation_rofi.sh: unknown mode: %s\n' "$mode" >&2; return 2; }

    if [[ -z "$entry" ]]; then
        local active_csv
        active_csv="$(IFS=,; printf '%s' "${active_indices[*]-}")"
        printf '\0prompt\x1f%s\n' "${mode#Window}"
        printf '\0no-custom\x1ftrue\n'
        [[ -n "$active_csv" ]] && printf '\0active\x1f%s\n' "$active_csv"
        printf '%s\n' "${names[@]}"
        return 0
    fi

    (( found_entry )) || { printf 'niri_animation_rofi.sh: unknown option: %s-%s\n' "$mode" "$entry" >&2; return 2; }
    if ! "$NIRI_ANIMATION_CTL" set "$mode" "$entry"; then
        notify_error "Failed to set ${mode#Window}: $entry"
        return 1
    fi
    command -v notify-send >/dev/null 2>&1 && notify-send "Niri animation" "${mode#Window}: $entry" || true
}

print_help() {
    cat <<'EOF_HELP'
Usage: niri_animation_rofi.sh [menu | handler MODE [OPTION]]
Classic Rofi frontend for Niri animation selection.
EOF_HELP
}

case "${1:-menu}" in
    menu|--menu)
        launch
        ;;
    handler|--handler)
        handle "${2:-}" "${3:-}"
        ;;
    -h|--help)
        print_help
        ;;
    *)
        # Compatibility with the old switcher script-mode handler shape.
        handle "$1" "${2:-}"
        ;;
esac
