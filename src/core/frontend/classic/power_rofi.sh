#!/usr/bin/env bash

# Classic power-menu frontend. Owns icons/menu geometry only; explicit power
# actions are delegated by stable ID to the headless controller.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME="shutdown.rasi"
EXTEND=()

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
    printf 'power_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

POWER_CTL="$(resolve_script power_ctl.sh ../../backend/system/power_ctl.sh)" || exit 1

usage() {
    cat <<EOF_HELP
Usage: $(basename "$0") [OPTIONS]

Options:
    -e, --extend <ARG...>    Pass placement arguments to the Classic menu
    -v, --vertical          Use the vertical shutdown theme
    -h, --help              Show this help message
EOF_HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--extend)
            shift
            EXTEND=("$@")
            break
            ;;
        -v|--vertical)
            THEME="shutdown-vert.rasi"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

OPTIONS=(
    '󰒲'
    ''
    '󰤆'
    '󰤁'
    '󱅞'
    '󰩈'
)
ACTIONS=(
    suspend
    reboot
    poweroff
    hibernate
    lock
    logout
)

chosen_index="$(printf '%s\n' "${OPTIONS[@]}" | rofi \
    -dmenu \
    -p "Shutdown" \
    -i \
    -format i \
    -theme "$THEME" \
    "${EXTEND[@]}")"
rofi_status=$?

# Escape/cancel is a frontend-only no-op.
if [[ $rofi_status -ne 0 || -z "$chosen_index" ]]; then
    exit 0
fi

if [[ ! "$chosen_index" =~ ^[0-9]+$ ]] || (( chosen_index < 0 || chosen_index >= ${#ACTIONS[@]} )); then
    printf 'power_rofi.sh: invalid selection index: %s\n' "$chosen_index" >&2
    exit 1
fi

exec "$POWER_CTL" "${ACTIONS[$chosen_index]}"
