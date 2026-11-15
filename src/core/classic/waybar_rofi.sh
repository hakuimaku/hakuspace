#!/usr/bin/env bash

# Classic Waybar selector frontend. It owns only presentation/selection and
# delegates all state/process mutation to the headless waybar controller.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
WAYBAR_CTL="$HAKU_BIN_DIR/waybar_ctl.sh"

select_mode() {
    local current choice
    [[ "$("$WAYBAR_CTL" status)" == "enabled" ]] || return 0
    current="$("$WAYBAR_CTL" current)" || return 1
    choice="$("$WAYBAR_CTL" list | rofi -dmenu -p "Waybar" -i -theme option-menu.rasi)"
    [[ -z "$choice" ]] && return 0
    [[ "$choice" == "$current" ]] && return 0
    "$WAYBAR_CTL" set "$choice"
}

print_help() {
    cat <<'EOF_HELP'
Usage: waybar_rofi.sh COMMAND
Classic Waybar selector frontend.

Commands:
    select              Pick and apply a Waybar mode
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    select|--select)
        select_mode
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
